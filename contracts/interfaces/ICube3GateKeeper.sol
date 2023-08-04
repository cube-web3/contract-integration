// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ICube3Data} from "./ICube3Data.sol";

/// @title CUBE3 GateKeeper Contract
/// @author CUBE3.ai
/// @notice Decentralized storage contract that keeps track of the function-level protection status
///         of CUBE3 integrations' utilizing a proxy. Also keeps track of integrations' protocol permissions.
/// @dev Contract is immutable and permissionless and intentionally decoupled from the {Cube3RouterLogic} contract for any
///      integration-specific logic.  This is to ensure that the {Cube3RouterLogic} contract can be upgraded without risk of
///      losing the function protection status of any integrations or rendering the protocol inoperable.
/// @dev The immutability of this contract protects integrations from reliance on the Cube3Router's availability
///      should an integration wish to bypass protection functionality.
/// @dev Storing function protection status outside of the {Cube3IntegrationUpgradeable} context protects from
///      malicious delegatecalls that aim to bypass function protection checks in integrations.
/// @dev Some functions expect the caller to pass the _self address as an argument. Only integrations with signatures
///      issued by CUBE3 can register using the address represented by _self, meaning that malicious actors should not
///      be able to use a proxy with an implementation contract that was not deployed by them.
interface ICube3GateKeeper {
    /*//////////////////////////////////////////////////////////////
            EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the protection status of one or more functions is updated.
    /// @dev Indicates whether the protection status is enabled (True) or disabled (False).
    /// @dev Only emitted in functions that can be called by an integration's Security Admin.
    /// @param integration The integration contract (or it's proxy if it has one) to which the protected function belongs.
    /// @param protectedFnSelectors The function selectors of the protected function to update.
    /// @param statuses Boolean array indicating whether protection is enabled for the selector at the corresponding index
    ///                 in the `protectedFnSelectors` array.
    event ProxyIntegrationFunctionProtectionStatusUpdated(
        address indexed integration,
        bytes4[] protectedFnSelectors,
        bool[] statuses
    );

    /// @notice Emitted when the GateKeeper contract is deployed.
    event GateKeeperDeployed();

    /// @notice Emitted when the Protection Status of an integration is updated.
    /// @dev Can be one of 5 statuses: See {ICube3GateKeeper-AuthorizationStatus} for reference.
    /// @param integrationOrProxy The address of the integration contract (the proxy if it's a proxy) that was registered.
    /// @param integrationOrImplementation The address of the integration contract (the implementation if it's a proxy) that was registered.
    /// @param status The new protection status of the integration.
    event IntegrationAuthorizationStatusUpdated(
        address indexed integrationOrProxy,
        address indexed integrationOrImplementation,
        ICube3Data.AuthorizationStatus status
    );

    /// @notice Emitted when the Registration Status of an integration is updated.
    /// @dev Can be one of 3 statuses: See {ICube3GateKeeper-RegistrationStatus} for reference.
    /// @param integrationOrProxy The address of the integration contract (the proxy if it's a proxy) that was registered.
    /// @param integrationOrImplementation The address of the integration contract (the implementation if it's a proxy) that was registered.
    /// @param status The new registration status of the integration.
    event IntegrationRegistrationStatusUpdated(
        address indexed integrationOrProxy,
        address indexed integrationOrImplementation,
        ICube3Data.RegistrationStatus status
    );

    /// @notice Emitted when an integration authorizes the new implementation of its proxy.
    /// @dev Emitted prior to the upgrade taking place.
    /// @param currentImplementation The address of the current integration proxy's implementation (_self).
    /// @param newImplementation The address of the integration proxy's new implementation.
    event IntegrationImplementationUpgradeAuthorized(
        address indexed currentImplementation,
        address indexed newImplementation
    );

    /*//////////////////////////////////////////////////////////////
            FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Called by an integration, on behalf of its Security Admin, to update the protection status of one or more functions.
    /// @dev See {Cube3Integration-setFunctionProtectionStatus} for implementation details.
    /// @dev Emits a single event containing all function selectors and their statuses to save gas.
    /// @dev Can only be called by a registered integration.
    /// @dev The integration passes its own address, that it references as an immutable variable `_self`, to prevent
    ///       malicious delegatecalls attempting to bypass the protection status in contract storage.
    /// @param integrationSelf Address of the integration contract to update the protection status for.
    /// @param integrationFnSelectors Array of function selectors to update status for.
    /// @param status Array of boolean values, where True is enabled, for the corresponding indices of `integrationFnSelectors`.
    function integrationUpdateProxyFunctionProtectionStatus(
        address integrationSelf,
        bytes4[] calldata integrationFnSelectors,
        bool[] calldata status
    ) external;

    /// @notice Gets the protection status of the function selector provided for the integration that calls it.
    /// @dev Can only be called by an integration to check its own status, primarily from the {Cube3Integration-cube3Protected} modifier.
    /// @dev Will revert if called by anyone other than `integrationSelf` implementation, or if RegistrationStatus is UNREGISTERED.
    /// @dev Integration passes its own address as a param to prevent malicious delegatecalls.
    /// @param integrationSelf The address of the integration contract's implementation.
    /// @param fnSelector The function selector to check the protection status for.
    /// @return Whether the function protection status is enabled (True) or disabled (False).
    function integrationCheckProxyFunctionProtectionStatusEnabled(
        address integrationSelf,
        bytes4 fnSelector
    ) external view returns (bool);

    /// @notice Pre-registers an integration with the Cube3Router.
    /// @dev Called from the {Cube3Integration} constructor, or {Cube3IntegrationUpgradeable-initialize} to pre-register the integration.
    /// @dev Will not prevent transaction's reverting for integrations usign a proxy that have not completed the registration process.
    /// @dev Can technically be called by any account, but registration can only be completed by an integration that signs up for the
    ///      service and receives a registration token - see {Cube3Router-initiate2StepIntegrationRegistration}.
    /// @dev Emits the IntegrationRegistrationStatusUpdated event with the status set to PENDING, used by CUBE3 to detect new integration deployments.
    /// @param integrationSelf The address of the integration contract (or the implementation if it's a proxy) that is being pre-registered.
    function preRegisterAsIntegration(address integrationSelf) external;

    /// @notice Completes the 2-step registration process for an integration.
    /// @dev Sets the integration authorization status to ACTIVE.
    /// @dev Can only be called by the Cube3Router.
    /// @dev Cannot re-register an ACTIVE integration.
    /// @dev Integration registering MUST have pre-registered.
    /// @param integrationOrProxy The address of the integration contract (the proxy if uses a proxy) that is being registered.
    /// @param integrationOrImplementation The address of the integration contract (the implementation if uses a proxy) that is being registered.
    function complete2StepIntegrationRegistration(
        address integrationOrProxy,
        address integrationOrImplementation
    ) external;

    /// @notice Pre-authorizes an implementation before an integration is upgraded.
    /// @dev Initiated by the integration's security admin prior to upgrading the integration's proxy implementation.
    /// @dev Can only be called by an integration that uses a proxy.
    /// @dev Can be called in a {_authorizeUpgrade} hook for UUPS proxy.
    /// @dev If the integration deployer neglects to preauthorize the implementation, it can be re-registered after initialization.
    /// @param integrationSelf The address of the proxy's current implementation.
    /// @param newImplementation The address of the proxy's new implementation.
    function preAuthorizeImplementationUpgrade(address integrationSelf, address newImplementation) external;

    /// @notice Allows a CUBE3 Admin to update the protection status of an integration contract Cube3Router.
    /// @dev Can only be called by the Cube3Router.
    /// @dev Manually sets the protection status of an integration contract.
    /// @dev Primarily used to BYPASS (delinquent) or REVOKE (malicious) protection status.
    /// @param integrationOrProxy The address of the integration contract (the proxy if it's a proxy) to update the protection status for.
    /// @param integrationOrImplementation The address of the integration contract (the implementation if it's a proxy) to update the protection status for.
    /// @param status The new AuthorizationStatus of the integration.
    function updateIntegrationAuthorizationStatus(
        address integrationOrProxy,
        address integrationOrImplementation,
        ICube3Data.AuthorizationStatus status
    ) external;

    /// @notice Sets the protection status of multiple integrations.
    /// @dev Batch version of {updateIntegrationAuthorizationStatus}.
    /// @dev Can only be called by the Cube3Router.
    /// @dev Emits an event per integration, so gas consumption will rise proportionally to the number of integrations.
    /// @param integrationProtectionStates Array of {ICube3Data-IntegrationProtection} structs.
    function batchUpdateIntegrationAuthorizationStatuses(
        ICube3Data.IntegrationProtection[] calldata integrationProtectionStates
    ) external;

    /// @notice Allows a CUBE3 Admin to update the protection status of an integration contract via the Cube3Router.
    /// @dev Can only be called by the Cube3Router.
    /// @dev Manually sets the registration status of an integration contract.
    /// @dev Primarily used to update proxy integration's registration status that failed to call {preAuthorizeImplementationUpgrade}
    /// @param integrationOrProxy The address of the integration contract (the proxy if it's a proxy) to update the protection status for.
    /// @param integrationOrImplementation The address of the integration contract (the implementation if it's a proxy) to update the protection status for.
    /// @param status The new RegistrationStatus of the integration.
    function updateIntegrationRegistrationStatus(
        address integrationOrProxy,
        address integrationOrImplementation,
        ICube3Data.RegistrationStatus status
    ) external;

    /// @notice Sets the registration status of multiple integrations.
    /// @dev Batch version of {updateIntegrationRegistrationStatus}.
    /// @dev Can only be called by the Cube3Router.
    /// @dev Emits an event per integration, so gas consumption will rise proportionally to the number of integrations.
    /// @param integrationRegistrationStates Array of {ICube3Data-IntegrationRegistration} structs.
    function batchUpdateIntegrationRegistrationStatuses(
        ICube3Data.IntegrationRegistration[] calldata integrationRegistrationStates
    ) external;

    /// @notice Returns whether the integration is protected or not.
    /// @dev Can be called by anyone.
    /// @dev If the integration is not a proxy, both inputs will be the same (the integration's address).
    /// @param integrationOrProxy The address of the integration contract (the proxy if it's a proxy) to check the protection status for.
    /// @param integrationOrImplementation The address of the integration contract (the implementation if it's a proxy) to check the protection status for.
    /// @return Whether the integration is protected or not, ie whether the protection status is ACTIVE.
    function isProtectionActiveForIntegration(
        address integrationOrProxy,
        address integrationOrImplementation
    ) external view returns (bool);

    /// @notice Retrieves the integration's current state
    /// @dev Returns `registrationStatus` and `authorizationStatus`, see {ICube3Data-IntegrationState}
    /// @param integrationOrProxy The address of the integration contract (the proxy if it's a proxy) to check the protection status for.
    /// @param integrationOrImplementation The address of the integration contract (the implementation if it's a proxy) to check the protection status for.
    /// @return The integration state (authorizationStatus & registrationStatus).
    function integrationState(
        address integrationOrProxy,
        address integrationOrImplementation
    ) external view returns (ICube3Data.IntegrationState memory);

    /// @notice Returns the protection status of the function for the integration provided.
    /// @dev Can be called by anyone.
    /// @param integrationProxy The address of the integration's proxy contract to check the function protection status for.
    /// @param fnSelector The bytes4 function selector of the function being checked.
    /// @return The protection status of the function, where True is protected, meaning the TX will be
    ///         forwarded to the Cube3Router and on to the designated security module.
    function isIntegrationProxyFunctionProtectionEnabled(
        address integrationProxy,
        bytes4 fnSelector
    ) external view returns (bool);

    /// @notice Explain to an end user what this does
    /// @dev Batch version of {isIntegrationProxyFunctionProtectionEnabled}
    /// @param integrationProxy The address of the integration's proxy contract to check the function protection status for.
    /// @param integrationFnSelectors The bytes4 function selectors of the functions being checked.
    /// @return fnAuthorizationStatus The status of the functions, where True is protected, for corresponding indices in the `integrationFnSelectors` array.
    function batchIsIntegrationProxyFunctionProtectionEnabled(
        address integrationProxy,
        bytes4[] calldata integrationFnSelectors
    ) external view returns (bool[] memory fnAuthorizationStatus);
}
