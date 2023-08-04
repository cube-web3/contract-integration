// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/// @title CUBE3 Module base contract.
/// @author CUBE3.ai
/// @dev    All CUBE3 security modules will inherit this base contract.
/// @dev    This module is used through inheritance.
/// @dev    Any module that inherits this contract should never make use of `selfdestruct` or
///         delegatecall to a contract that might, as it could potentially render the router proxy
///         inoperable.
/// @notice Provides the module with connectivity to the Cube3Router and manages the module's versioning.
interface ICube3Module {
    /*//////////////////////////////////////////////////////////////
            EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new Cube Module is deployed.
    /// @param routerAddress The address of the Cube3RouterProxy.
    /// @param moduleId The computed ID of the module.
    /// @param version The human-readble module version.
    event ModuleDeployed(address indexed routerAddress, bytes32 indexed moduleId, string indexed version);

    /// @notice Emitted when the module is deprecated.
    /// @param moduleId The computed ID of the module.
    /// @param version  The human-readable module version.
    event ModuleDeprecated(bytes32 indexed moduleId, string indexed version);

    /*//////////////////////////////////////////////////////////////
            FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice The human-readable version of the module.
    /// @dev Module version scheme is as follows: `<module_name>-<semantic_version>`, eg. `signature-0.0.1`
    /// @dev Validation of the moduleVersion string must be done by the deployer
    /// @return The module version as a string
    function moduleVersion() external view returns (string memory);

    /// @notice Indicates whether the module has been deprecated.
    /// @return The deprecation status of the module
    function isDeprecated() external view returns (bool);

    /// @notice Deprecates the module.
    /// @dev Only callable by the Cube3Router.
    /// @dev Deprecation event emitted by the router, see {Cube3RouterLogic-deprecateModule}.
    /// @dev Once a module has been deprecated it cannot be reinstalled in the router.
    /// @return The deprecation status and human-readable module version
    function deprecate() external returns (bool, string memory);

    /// @notice Gets the ID of the module
    /// @dev computes the keccak256 hash of the abi.encoded moduleVersion
    /// @return The module's computed ID
    function moduleId() external view returns (bytes32);
}
