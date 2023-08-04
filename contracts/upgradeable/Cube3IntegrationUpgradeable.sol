// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC165CheckerUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165CheckerUpgradeable.sol";
import {ERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import {ProtocolContractsByChain} from "../utils/ProtocolContractsByChain.sol";
import {SecurityAdmin2StepUpgradeable} from "./SecurityAdmin2StepUpgradeable.sol";
import {ICube3Integration} from "../interfaces/ICube3Integration.sol";
import {ICube3IntegrationUpgradeable} from "../interfaces/ICube3IntegrationUpgradeable.sol";
import {ICube3Router} from "../interfaces/ICube3Router.sol";
import {ICube3GateKeeper} from "../interfaces/ICube3GateKeeper.sol";

/// @dev See {ICube3IntegrationUpgradeable}
abstract contract Cube3IntegrationUpgradeable is
    ICube3IntegrationUpgradeable,
    SecurityAdmin2StepUpgradeable,
    ERC165Upgradeable
{
    /*//////////////////////////////////////////////////////////////
            CUBE PROTECTION
    //////////////////////////////////////////////////////////////*/

    // store this contract's address in bytecode as a reference for the call context
    // to help protect against malicious delegatecalls
    address private immutable _self;

    // Address of the router proxy that connects the payload to the correct module
    address internal immutable _cube3RouterProxy;

    // Address of the GateKeeper contract, which acts as secure storage location for function protection state
    address internal immutable _cube3GateKeeper;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @dev Should be used when initialization is possible via the proxy's constructor such as UUPS
    ///      and TransparentUpgradeableProxy.
    modifier onlyConstructor() {
        require(address(this).code.length == 0, "CR02: not in constructor");
        _;
    }

    constructor() {
        (address cubeRouterAddress, address cubeGateKeeperAddress) = ProtocolContractsByChain
            ._getProtocolAddressesByChainId();
        require(cubeRouterAddress != address(0), "CP01: invalid router");
        require(
            ERC165CheckerUpgradeable.supportsInterface(cubeRouterAddress, type(ICube3Router).interfaceId),
            "CP11: invalid contract"
        );
        require(cubeGateKeeperAddress != address(0), "CP10: invalid gatekeeper");
        require(
            ERC165CheckerUpgradeable.supportsInterface(cubeGateKeeperAddress, type(ICube3GateKeeper).interfaceId),
            "CP12: invalid contract"
        );

        _cube3RouterProxy = cubeRouterAddress;
        _cube3GateKeeper = cubeGateKeeperAddress;
        _self = address(this);
    }

    /*//////////////////////////////////////////////////////////////
            UPGRADEABILITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Initializes the Cube3Protect functionality.
    /// @dev Can only be called during initialization.
    /// @param securityAdminAddress The address of the Security Admin.
    function __Cube3IntegrationUpgradeable_init(address securityAdminAddress) internal onlyInitializing {
        __Cube3IntegrationUpgradeable_init_unchained(securityAdminAddress);
    }

    /// @dev Explicitly sets the security Admin account to the supplied `securityAdmin` address.
    /// @dev Pre-registers this contract with the GateKeeper.
    /// @dev checks that router and gatekeeper addresses are valid by checking that the contracts support the correct interfaces.
    function __Cube3IntegrationUpgradeable_init_unchained(address securityAdminAddress) internal onlyInitializing {
        require(securityAdminAddress != address(0), "CP13: invalid admin");

        __ERC165_init();
        __SecurityAdmin2StepUpgradeable_init(securityAdminAddress);

        ICube3GateKeeper(_cube3GateKeeper).preRegisterAsIntegration(_self);

        emit Cube3IntegrationDeployment(address(this), msg.sender);
    }

    /// @inheritdoc ICube3IntegrationUpgradeable
    function preAuthorizeNewImplementation(address newImplementation) external onlySecurityAdmin {
        _preAuthorizeNewImplementation(newImplementation);
    }

    /*/////////////////////////////////////////////////////////////x/
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Added to any function that wishes to add CUBE3's RASP functionality.
    /// @dev Adding reentracy protection is at the discretion of the derived contract.
    /// @dev Any function that adds the {cube3Protected} modifier MUST add `cube3SecurePayload`, of
    ///      type `bytes calldata`, as the last function parameter.
    modifier cube3Protected(bytes calldata cube3SecurePayload) {
        // For security reasons, the function protection state is stored in a remote contract, the GateKeeper, that can only be accessed
        // by this integration when checking the function protection status.
        // This integration MUST register with the CUBE3 protocol, or calls to functions with this modifier will revert.
        // If the protection status for the function described by msg.sig is disabled, the GateKeeper will return false, and the function
        // execution will continue.
        // Disabling the function protection status will still result in a call to the GateKeeper.
        // The GateKeeper provides sufficient decentralization, allowing this integration to be decoupled from the protocol.
        if (!_isProtectionForFunctionEnabled(msg.sig)) {
            _;
        } else {
            // minimum length is 64 bytes: abi.encoded (bytes4 selector + bytes32 moduleId)
            require(cube3SecurePayload.length >= 64, "CP04: invalid payload length");

            // We need to pass along all the relevant calldata: msg.value, msg.sender, msg.data
            // If the caller of the derived contract is a multisig, the tx.origin (executor) may not match the intiator of
            // the transaction - it is left up to the security module to decide if this is a valid use case.
            // We pass along all relevant data to the router and leave it to the module to decide what's relevant.
            try
                ICube3Router(_cube3RouterProxy).routeToModule(
                    msg.sender,
                    _self,
                    _getMsgValue(),
                    cube3SecurePayload.length,
                    msg.data
                )
            returns (bool proceed) {
                if (!proceed) {
                    revert("CP05: module invalid return");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch (bytes memory) {
                revert("CP09: assert or panic");
            }
            // The security module has deemed it is safe to proceed with the function call.
            _;
        }
    }

    /*//////////////////////////////////////////////////////////////
            FUNCTION PROTECTION LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICube3Integration
    function registerIntegrationWithCube3(
        bytes calldata registrarSignature,
        bytes4[] calldata enabledByDefaultFnSelectors
    ) external onlySecurityAdmin {
        require(registrarSignature.length == 65, "CP03: invalid signature length");

        // register with the Cube3Router as an integration, this will validate that the registrar signature is valid,
        // that it was generated using this integration's address + securityAdmin address, and will register
        // this integration with the Cube3GateKeeper that stores the function protection state
        bool success = ICube3Router(_cube3RouterProxy).initiate2StepIntegrationRegistration(_self, registrarSignature);
        require(success, "CP02: registration failed");

        uint256 numEnabled = enabledByDefaultFnSelectors.length;
        // small gas saving when no functions are enabled by default
        if (numEnabled != 0) {
            bool[] memory defaultEnabled = new bool[](numEnabled);
            for (uint i; i < numEnabled; ) {
                defaultEnabled[i] = true;
                unchecked {
                    ++i;
                }
            }
            _setFunctionProtectionStatus(enabledByDefaultFnSelectors, defaultEnabled);
        }
    }

    /// @inheritdoc ICube3Integration
    function setFunctionProtectionStatus(
        bytes4[] calldata fnSelectors,
        bool[] memory isEnabled
    ) external onlySecurityAdmin {
        _setFunctionProtectionStatus(fnSelectors, isEnabled);
    }

    /*//////////////////////////////////////////////////////////////
            EXTERNAL CONVENIENCE/VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICube3Integration
    function self() external view returns (address, address) {
        // if this is a proxy, _self will be the implementation address and address(this) will be the proxy address
        return (address(this), _self);
    }

    /// @inheritdoc ICube3Integration
    function isFunctionProtectionEnabled(bytes4 fnSelector) public view returns (bool) {
        // Function protection status is stored in the remote GateKeeper contract.
        return
            ICube3GateKeeper(_cube3GateKeeper).isIntegrationProxyFunctionProtectionEnabled(address(this), fnSelector);
    }

    /// @inheritdoc ICube3Integration
    function batchIsFunctionProtectionEnabled(bytes4[] calldata fnSelectors) external view returns (bool[] memory) {
        // Function protection status is stored in the remote GateKeeper contract.
        return
            ICube3GateKeeper(_cube3GateKeeper).batchIsIntegrationProxyFunctionProtectionEnabled(
                address(this),
                fnSelectors
            );
    }

    /*//////////////////////////////////////////////////////////////
            ERC165 INTERFACE SUPPORT
    //////////////////////////////////////////////////////////////*/

    /// @dev MUST be overridden in the inheriting contract if there is a need to support additional interfaces
    ///      using super.supportsInterface(interfaceId)
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(ICube3Integration).interfaceId || super.supportsInterface(interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
            INTERNAL UTILITIES
    //////////////////////////////////////////////////////////////*/

    /// @dev SHOULD be called before upgrading to a new implementation contract.
    /// @dev For a UUPS implementation, can called inside the {_authorizeUpgrade} function.
    function _preAuthorizeNewImplementation(address newImplementation) internal {
        ICube3GateKeeper(_cube3GateKeeper).preAuthorizeImplementationUpgrade(_self, newImplementation);
    }

    /// @dev internal call is restricted to use by the integration contract, will revert if not registered.
    function _isProtectionForFunctionEnabled(bytes4 fnSelector) internal view returns (bool) {
        return
            ICube3GateKeeper(_cube3GateKeeper).integrationCheckProxyFunctionProtectionStatusEnabled(_self, fnSelector);
    }

    /// @dev helper function to set the protection status of a function via call to the Cube3GateKeeper
    function _setFunctionProtectionStatus(bytes4[] calldata fnSelectors, bool[] memory isEnabled) private {
        ICube3GateKeeper(_cube3GateKeeper).integrationUpdateProxyFunctionProtectionStatus(
            _self,
            fnSelectors,
            isEnabled
        );
    }

    /// @dev Helper function as a non-payable function cannot read msg.value in the modifier.
    /// @dev Will not clash with `_msgValue` in the event that the derived contract inherits {Context}.
    function _getMsgValue() private view returns (uint256) {
        return msg.value;
    }

    /*//////////////////////////////////////////////////////////////
            IMPLEMENTATION SAFEGUARDS
    //////////////////////////////////////////////////////////////*/
    /// @dev    reserved storage space to allow for layout changes in future implementations
    uint256[50] private __storageGap;
}
