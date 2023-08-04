// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ICube3Integration} from "./ICube3Integration.sol";

/// @title CUBE3 Integration Upgradeable
/// @author CUBE3.ai
/// @notice Facilitates connection to the CUBE3 Protocol and CUBE3's RASP (Runtime Application Self Protection) functionality
///         for functions in the derived contract (integration).
/// @dev Upgradeable contract for use with a proxy. See {Cube3Integration} for non-upgradeable version.
/// @dev Function protection state storage takes place in {Cube3GateKeeper} to protect against malicious delegatecalls.
interface ICube3IntegrationUpgradeable is ICube3Integration {
    /// @notice Authorizes a new implementation to replace the existing one (this)
    /// @dev Informs the CUBE3 registry that a new implementation will be deployed, and registers it prior to
    ///      the upgrade, so existing protection status and function protection statuses are maintained.
    /// @dev MUST be called prior to upgrading to `newImplementation`.
    /// @param newImplementation The address of the new implementation.
    function preAuthorizeNewImplementation(address newImplementation) external;
}
