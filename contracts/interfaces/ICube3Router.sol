// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ICube3Data} from "./ICube3Data.sol";

/// @title CUBE3 Router
/// @author CUBE3.ai
/// @notice The Cube3Router extracts routing data from the `cube3SecurePayload` header and
///         routes transactions to the designated security modules that plugin to the CUBE3 Protocol.
/// @dev Integration contracts need to register with the router to be eligible to have
///      transactions routed to modules.
/// @dev The CUBE3_PROTOCOL_ADMIN_ROLE can set the protection status of a deliquent integration to BYPASS, or to REVOKED for a malicious contract.
/// @dev The CUBE3_PROTOCOL_ADMIN_ROLE can install and deprecate modules to extend the functionality
///      of the router.
/// @dev Contract is upgradeable via the Universal Upgradeable Proxy Standard (UUPS).
/// @dev Includes a `__storageGap` to prevent storage collisions following upgrades.

interface ICube3Router is ICube3Data {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when an integration's revocation status is updated.
    /// @dev Recovation status will be {True} when the integration is revoked and {False} when the revocation is cleared
    /// @param integration The integration contract whose revocation status is updated.
    /// @param isRevoked Whether the `integration` contract is revoked.
    event IntegrationRegistrationRevocationStatusUpdated(address indexed integration, bool isRevoked);

    /// @notice Emitted when a Cube3 admin installs a new module.
    /// @param moduleId The module's computed ID.
    /// @param moduleAddress The contract address of the module.
    /// @param version A string representing the modules version in the form `<module_name>-<semantic_version>`.
    event RouterModuleInstalled(bytes32 indexed moduleId, address indexed moduleAddress, string indexed version);

    /// @notice Emitted when a Cube3 admin deprecates an installed module.
    /// @param moduleId The computed ID of the module that was deprecated.
    /// @param moduleAddress The contract address of the module that was deprecated.
    /// @param version The human-readable version of the deprecated module.
    event RouterModuleDeprecated(bytes32 indexed moduleId, address indexed moduleAddress, string indexed version);

    event Cube3ProtocolContractsUpdated(address indexed gateKeeper, address indexed registry);

    /*//////////////////////////////////////////////////////////////
                            FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Initializes the proxy's implementation contract.
    /// @dev Can only be called during the proxy's construction.
    /// @dev Omits any argument to avoid changing deployment bytecode across EVM chains.
    /// @dev See {Cube3RouterProxy-construcot} constructor for implementation details.
    function initialize() external;

    /// @notice Routes transactions from any Cube3Integration integration to a designated CUBE3 module.
    /// @dev Can only be called by integration contracts that have registered with the router.
    /// @dev A successful module function's execution should always return TRUE.
    /// @dev A failed module function's execution, or not meeting the conditions layed out in the module, should always revert.
    /// @dev Makes a low-level call to the module that includes all relevent data.
    /// @param integrationMsgSender The msgSender of the originating Cube3Integration function.
    /// @param integrationSelf The Cube3Integration integration contract address, passes by itself as the _self ref.
    /// @param integrationMsgValue The msg.value of the originating Cube3Integration function call.
    /// @param integrationMsgValue The msg.value of the originating Cube3Integration function call.
    /// @param cube3PayloadLength The length of the CUBE3 payload.
    /// @return Whether the module's function execution was successful.
    function routeToModule(
        address integrationMsgSender,
        address integrationSelf,
        uint256 integrationMsgValue,
        uint256 cube3PayloadLength,
        bytes calldata integrationMsgData
    ) external returns (bool);

    /// @notice Registers the calling contract's address as an integration.
    /// @dev Cannot be called by a contract's constructor as the `supportsInterface` callback would fail.
    /// @dev Can only be called by a contract, EOAS are prevented from calling via {supportsInterface} callback.
    /// @dev There is no guarantee the calling contract is a legitimate Cube3Integration contract.
    /// @dev The registrarSignature needs to be attained from the CUBE3 service.
    /// @dev msg.sender will be the proxy contract, not the implementation, if it is a proxy registering.
    /// @dev Unauthorized contracts can be revoked manually by an admin, see {setIntegrationAuthorizationStatus}.
    /// @param integrationSelf The contract address of the integration contract being registered.
    /// @param registrarSignature The registration signature provided by the integration's signing authority.
    function initiate2StepIntegrationRegistration(
        address integrationSelf,
        bytes calldata registrarSignature
    ) external returns (bool success);

    /// @notice Manually sets/updates the designated integration contract's authorization status.
    /// @dev Can only be called by a CUBE3 admin.
    /// @dev Can be used to disable/bypass a malicious/delinquent integration's authorization status.
    /// @dev If the integration is a standalone contract (not using a proxy), the `integrationOrProxy` and
    ///      `integrationOrImplementation` parameters will be the same address.
    /// @param integrationOrProxy The contract address of the integration contract (or its proxy).
    /// @param integrationOrImplementation The contract address of the integration's implementation contract (or itself if not a proxy).
    /// @param authorizationStatus The authorization status to set.
    function setIntegrationAuthorizationStatus(
        address integrationOrProxy,
        address integrationOrImplementation,
        ICube3Data.AuthorizationStatus authorizationStatus
    ) external;

    /// @notice Manually sets/updates the designated integration contract's registration status.
    /// @dev Can only be called by a CUBE3 admin.
    /// @dev Can be used to reset an upgradeable proxy implementation's registration status.
    /// @dev If the integration is a standalone contract (not using a proxy), the `integrationOrProxy` and
    ///      `integrationOrImplementation` parameters will be the same address.
    /// @param integrationOrProxy The contract address of the integration contract (or its proxy).
    /// @param integrationOrImplementation The contract address of the integration's implementation contract (or itself if not a proxy).
    /// @param registrationStatus The registration status status to set.
    function setIntegrationRegistrationStatus(
        address integrationOrProxy,
        address integrationOrImplementation,
        RegistrationStatus registrationStatus
    ) external;

    /// @notice Sets the ProtectionStatus and RegistrationStatus of multiple integrations.
    /// @dev Can only be called by a CUBE3 admin.
    /// @dev An event is emitted for each integration that is updated, so gas costs rise proportionally with the number of integrations.
    /// @param integrationProtectionStates An array of structs containing the integration addresses and their new ProtectionStatus.
    /// @param integrationRegistrationStates An array of structs containing the integration addresses and their new RegistrationStatus.
    function batchUpdateIntegrationState(
        IntegrationProtection[] calldata integrationProtectionStates,
        IntegrationRegistration[] calldata integrationRegistrationStates
    ) external;

    /// @notice Sets the CUBE3 protocol contract addresses.
    /// @dev Performs checks using {supportsInterface} to ensure the correct addresses are passed in.
    /// @dev We cannot pass in the addresses during intialization, as we need the deployed bytecode to be the same
    ///      on all EVM chains for use with the constant address deployer proxy.
    /// @dev MUST be called immediately after deployment, before any other functions are called.
    /// @param cube3GateKeeper The address of the Cube3GateKeeper contract.
    /// @param cube3RegistryProxy The address of the Cube3Registry proxy contract.
    function setProtocolContracts(address cube3GateKeeper, address cube3RegistryProxy) external;

    /// @notice Adds a new module to the Protocol.
    /// @dev Can only be called by CUBE3 admin.
    /// @dev Module IDs are included in the `cube3SecurePayload` and used to dynamically retrieve
    ///      the contract address for the destination module.
    /// @dev The Router can only make calls to modules registered via this function.
    /// @dev Can only install module contracts that have been deployed and support the {ICube3Module} interface.
    /// @dev Makes a call to the module that returns the string version to validate the module exists.
    /// @param moduleAddress The contract address where the module is located.
    /// @param moduleId The corresponding module ID generated from the hash of its version string.
    function installModule(address moduleAddress, bytes32 moduleId) external;

    /// @notice Deprecates a mondule installed via {installModule}.
    /// @dev Can only be called by a Cube3 admin.
    /// @dev Deletes the module Id from the `idToModules` map.
    /// @dev A deprecated module cannot be re-installed, either accidentally or intentionally, a newer
    ///      version must be deployed.
    /// @param moduleId The module ID to deprecate.
    function deprecateModule(bytes32 moduleId) external;

    /// @notice Gets the contract address of a module using its computed ID.
    /// @dev `moduleId` is computed from keccak256(abi.encode(versionString)).
    /// @param moduleId The module's ID derived from the hash of the module's version string.
    /// @return The module contract's address.
    function getModuleAddressById(bytes32 moduleId) external view returns (address);

    /// @notice Whether the supplied contract is both a registered integration and has a protection status of ACTIVE.
    /// @param integrationOrProxy The contract address of the integration (or its proxy) contract being queried.
    /// @param integrationOrImplementation The contract address of the integration's implementation contract.
    /// @return Whether the provided integration is actively protected.
    function isProtectedIntegration(
        address integrationOrProxy,
        address integrationOrImplementation
    ) external view returns (bool);

    /// @notice Get the current proxy implementation's address.
    /// @dev Will return the address of the Cube3RouterProxy's current implementation/logic contract.
    /// @dev Conforms to the UUPS spec.
    /// @return The contract address of this active implementation contract.
    function getImplementation() external view returns (address);
}
