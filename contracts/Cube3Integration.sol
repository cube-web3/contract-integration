// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC165, IERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {SecurityAdmin2Step} from "./utils/SecurityAdmin2Step.sol";
import {ProtocolContractsByChain} from "./utils/ProtocolContractsByChain.sol";
import {ICube3Integration} from "./interfaces/ICube3Integration.sol";
import {ICube3Router} from "./interfaces/ICube3Router.sol";
import {ICube3GateKeeper} from "./interfaces/ICube3GateKeeper.sol";

/// @dev See {ICube3Integration}
abstract contract Cube3Integration is ICube3Integration, SecurityAdmin2Step, ERC165 {
    /*//////////////////////////////////////////////////////////////
            CUBE PROTECTION
    //////////////////////////////////////////////////////////////*/

    // store this contract's address in bytecode as a reference for the call context
    // to help protect against malicious delegatecalls
    address private immutable _self;

    // Address of the router proxy that connects the payload to the correct module
    address private immutable _cube3RouterProxy;

    // Address of the GateKeeper contract, which acts as a gatekeeper to the CUBE3 protocol
    address private immutable _cube3GateKeeper;

    // Stores the function protection status of each function using its function selector, where True will forward the call to the router
    mapping(bytes4 => bool) private _functionAuthorizationStatus; // fnSelector => isProtected

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initializes the  Cube3Protect functionality and sets the deployer as the Security Admin.
    /// @dev Initializes the ICube3Router infterface with the `cubeRouterAddress`, which cannot be changed.
    /// @dev Sets the deployer as the default `_securityAdmin`.
    /// @dev checks that router and gatekeeper addresses are valid by checking that they support the correct interfaces.
    /// @dev Pre-registers this contract with the GateKeeper.
    constructor() SecurityAdmin2Step() {
        (address cubeRouterAddress, address cubeGateKeeperAddress) = ProtocolContractsByChain
            ._getProtocolAddressesByChainId();
        require(cubeGateKeeperAddress != address(0), "CP10: invalid gatekeeper");
        require(cubeRouterAddress != address(0), "CP01: invalid router");
        require(IERC165(cubeRouterAddress).supportsInterface(type(ICube3Router).interfaceId), "CP11: invalid contract");
        require(
            IERC165(cubeGateKeeperAddress).supportsInterface(type(ICube3GateKeeper).interfaceId),
            "CP12: invalid contract"
        );

        _self = address(this);
        _cube3RouterProxy = cubeRouterAddress;
        _cube3GateKeeper = cubeGateKeeperAddress;

        ICube3GateKeeper(cubeGateKeeperAddress).preRegisterAsIntegration(_self);

        emit Cube3IntegrationDeployment(address(this), msg.sender, securityAdmin());
    }

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier noDelegatecall() {
        require(address(this) == _self, "CP06: no delegatecall");
        _;
    }

    /// @notice Added to any function that wishes to add CUBE3's RASP functionality.
    /// @dev Adding reentracy protection is at the discretion of the derived contract.
    /// @dev Any function that adds the {cube3Protected} modifier MUST add `cube3SecurePayload`, of
    ///      type `bytes calldata`, as the last function parameter.
    modifier cube3Protected(bytes calldata cube3SecurePayload) {
        require(address(this) == _self, "CP06: no delegatecall");

        // skip the call to the security module if function protection is disabled for this fn call
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
            // The security module has declared that it is safe to proceed with the function call.
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
    ) external noDelegatecall onlySecurityAdmin {
        require(registrarSignature.length == 65, "CP03: invalid signature length");

        // register with the Cube3Router as an integration, this will validate that the registrar signature is valid,
        // that it was generated using this integration's address + securityAdmin address, and will register
        // this integration with the Cube3GateKeeper
        bool success = ICube3Router(_cube3RouterProxy).initiate2StepIntegrationRegistration(_self, registrarSignature);
        require(success, "CP02: registration failed");

        uint256 numEnabled = enabledByDefaultFnSelectors.length;
        // small gas saving when no functions are enabled by default
        if (numEnabled != 0) {
            bool[] memory enabled = new bool[](numEnabled);
            for (uint i; i < numEnabled; ) {
                enabled[i] = true;
                unchecked {
                    ++i;
                }
            }
            _setFunctionProtectionStatus(enabledByDefaultFnSelectors, enabled);
        }
    }

    /// @inheritdoc ICube3Integration
    function setFunctionProtectionStatus(
        bytes4[] calldata fnSelectors,
        bool[] memory isEnabled
    ) external noDelegatecall onlySecurityAdmin {
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
        return _functionAuthorizationStatus[fnSelector];
    }

    /// @inheritdoc ICube3Integration
    function batchIsFunctionProtectionEnabled(bytes4[] calldata fnSelectors) external view returns (bool[] memory) {
        uint256 selectorsLength = fnSelectors.length;
        bool[] memory statuses = new bool[](selectorsLength);
        for (uint256 i; i < selectorsLength; ) {
            statuses[i] = _isProtectionForFunctionEnabled(fnSelectors[i]);
            unchecked {
                ++i;
            }
        }
        return statuses;
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

    function _isProtectionForFunctionEnabled(bytes4 fnSelector) internal view returns (bool) {
        return _functionAuthorizationStatus[fnSelector];
    }

    /// @dev helper function to set the protection status of a function
    function _setFunctionProtectionStatus(bytes4[] calldata fnSelectors, bool[] memory isEnabled) private {
        uint256 selectorsLength = fnSelectors.length;
        require(selectorsLength == isEnabled.length, "CP07: invalid input length");
        for (uint256 i; i < selectorsLength; ) {
            _functionAuthorizationStatus[fnSelectors[i]] = isEnabled[i];
            unchecked {
                ++i;
            }
        }
        emit StandaloneFunctionProtectionStatusUpdated(fnSelectors, isEnabled);
    }

    /// @dev Helper function as a non-payable function cannot read msg.value in the modifier.
    /// @dev Will not clash with `_msgValue` in the event that the derived contract inherits {Context}.
    function _getMsgValue() private view returns (uint256) {
        return msg.value;
    }
}
