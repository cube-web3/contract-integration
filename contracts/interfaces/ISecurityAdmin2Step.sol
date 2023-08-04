// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/// @title Security Administration 2 step.
/// @author CUBE3.ai
/// @notice Provides access control mechanism for administration of the functions protected by
///         the {onlySecurityAdmin} modifier. This modifier should be used to protect the privileged
///         functions that affect that protection status of functions decorated with the {Cube3Secured} modifier.
/// @dev Based on the OpenZeppelin {Ownable2Step} implementation.
/// @dev This module is used through inheritance.
/// @dev By default the contract deployer is the _securityAdmin.
/// @dev Overriding functions that deal with the security administration should be done so with caution.
///      Incorrectly overriding a virtual function can nullify the security mechanisms provided by this module.
/// @dev This module is used through inheritance.
/// @dev This module does not include a {renounceSecurityAdministration} function, as CUBE3's service cannot be
///      considered fully decentralized, and renouncing security administration could render the contract unusable
///      should CUBE3's service permanently go offline and function protection remains enabled.
interface ISecurityAdmin2Step {
    /*//////////////////////////////////////////////////////////////
            EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the {_securityAdmin} starts the admin transfer process.
    /// @dev Sets the {_pendingSecurityAdmin} account, but does not complete transfer until {acceptSecurityAdministration}
    ///      is called by the pending admin.
    /// @param oldAdmin The address of the previous admin, who invoked the {transferSecurityAdmin} function.
    /// @param pendingAdmin The address of the account waiting to accept the {_securityAdmin} role.
    event SecurityAdminTransferStarted(address indexed oldAdmin, address indexed pendingAdmin);

    /// @notice Emitted when the {_securityAdmin} account is updated.
    /// @param oldAdmin The address of the previous admin, who invoked the {transferSecurityAdmin} function.
    /// @param newAdmin The address of the contract's new {_securityAdmin}.
    event SecurityAdministrationTransferred(address indexed oldAdmin, address indexed newAdmin);

    /*//////////////////////////////////////////////////////////////
            FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Explain to an end user what this does
    /// @dev Starts the security admin transfer.
    /// @dev Can only be called by the current _securityAdmin.
    /// @dev Overridden functions MUST include {onlySecurityAdmin} modifier to maintain security functionalitys.
    /// @dev No need for Zero address validation as the Zero address cannot call {acceptSecurityAdministration}
    ///      and _pendingSecurityAdmin can be overwritten.
    /// @param newAdmin The address of the account waiting to accept the {_securityAdmin} role.
    function transferSecurityAdministration(address newAdmin) external;

    /// @notice Accepts the security admin role.
    /// @dev Can only be called by the _pendingSecurityAdmin.
    /// @dev Executes the security admin transfer and resets the {_pendingSecurityAdmin} to the Zero address.
    function acceptSecurityAdministration() external;

    /// @notice Returns the address of the current _securityAdmin.
    /// @dev Returns the address of the current security admin.
    /// @dev Derived contract can override this function to override which address
    ///      is used as the securityAdmin.
    /// @dev Only override this if you're aware of the side effects, any address returned by the overridden
    ///      version of this function will pass the require(securityAdmin() == msg.sender) check.
    /// @return The address of the current security admin.
    function securityAdmin() external view returns (address);

    /// @notice Returns the address of the _pendingSecurityAdmin.
    /// @return The address of the pending security admin.
    function pendingSecurityAdmin() external view returns (address);
}
