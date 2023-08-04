// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ISecurityAdmin2StepUpgradeable} from "../interfaces/ISecurityAdmin2StepUpgradeable.sol";

/// @dev See {ISecurityAdmin2StepUpgradeable}
abstract contract SecurityAdmin2StepUpgradeable is ISecurityAdmin2StepUpgradeable {
    // the current security admin for the derived contract
    address private _securityAdmin;

    // the pending security admin for the derived contract, once accepting the role will be transferred to the _securityAdmin
    address private _pendingSecurityAdmin;

    /// @dev decorates the functions that control the function protection status of the inheriting contract
    modifier onlySecurityAdmin() {
        require(securityAdmin() == msg.sender, "SA01: security admin only");
        _;
    }

    /// @dev Initializes the contract setting the deployer as the initial security admin.
    /// @dev MUST be called by the derived contract's initializer.
    function __SecurityAdmin2StepUpgradeable_init(address securityAdmin_) internal {
        __SecurityAdmin2StepUpgradeable_init_unchained(securityAdmin_);
    }

    function __SecurityAdmin2StepUpgradeable_init_unchained(address securityAdmin_) internal {
        _transferSecurityAdministration(securityAdmin_);
    }

    /// @dev Starts the security admin transfer.
    /// @dev Can only be called by the current Security Admin.
    /// @dev Overridden functions MUST include {onlySecurityAdmin} modifier to maintain functionlity.
    /// @dev No need for Zero address validation as the Zero address cannot call {acceptSecurityAdministration}.
    function transferSecurityAdministration(address newAdmin) public virtual onlySecurityAdmin {
        _pendingSecurityAdmin = newAdmin;
        emit SecurityAdminTransferStarted(securityAdmin(), newAdmin);
    }

    /// @dev The new admin accepts the admin transfer.
    function acceptSecurityAdministration() external {
        require(pendingSecurityAdmin() == msg.sender, "SA02: not pending admin");
        _transferSecurityAdministration(msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
            EXTERNAL CONVENIENCE/VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns the address of the current security admin.
    /// @dev Derived contract can override this function to override which address
    ///      is used as the securityAdmin.
    /// @dev Only override this if you're aware of the side effects, any address returned by the overridden
    ///      version of this function will pass the require(securityAdmin() == msg.sender) check.
    function securityAdmin() public view virtual returns (address) {
        return _securityAdmin;
    }

    /// @dev Returns the address of the pending admin
    function pendingSecurityAdmin() public view virtual returns (address) {
        return _pendingSecurityAdmin;
    }

    /*//////////////////////////////////////////////////////////////
            INTERNAL UTILITIES
    //////////////////////////////////////////////////////////////*/

    /// @dev Transfers security administration of the contract to a new account (`newAdmin`) and
    ///      deletes the pending admin.
    /// @dev Encapsulates the transfer and event emission for easy reuse.
    function _transferSecurityAdministration(address newAdmin) private {
        address previousAdmin = securityAdmin();
        delete _pendingSecurityAdmin;
        _securityAdmin = newAdmin;
        emit SecurityAdministrationTransferred(previousAdmin, newAdmin);
    }

    /*//////////////////////////////////////////////////////////////
            IMPLEMENTATION SAFEGUARDS
    //////////////////////////////////////////////////////////////*/
    /// @dev    reserved storage space to allow for layout changes in future implementations
    uint256[50] private __storageGap;
}
