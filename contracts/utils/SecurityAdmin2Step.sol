// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ISecurityAdmin2Step} from "../interfaces/ISecurityAdmin2Step.sol";

/// @dev see {ISecurityAdmin2Step}
abstract contract SecurityAdmin2Step is ISecurityAdmin2Step {
    // the current security admin for the derived contract
    address private _securityAdmin;

    // the pending security admin for the derived contract, once accepting the role will be transferred to the _securityAdmin
    address private _pendingSecurityAdmin;

    /*//////////////////////////////////////////////////////////////
            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @dev decorates the functions that control the function protection status of the inheriting contract
    modifier onlySecurityAdmin() {
        require(securityAdmin() == msg.sender, "SA01: security admin only");
        _;
    }

    /*//////////////////////////////////////////////////////////////
            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    // initialize the contract, setting the deployer as the initial security admin
    constructor() {
        _transferSecurityAdministration(msg.sender);
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

    /// @inheritdoc ISecurityAdmin2Step
    function transferSecurityAdministration(address newAdmin) public virtual onlySecurityAdmin {
        _pendingSecurityAdmin = newAdmin;
        emit SecurityAdminTransferStarted(securityAdmin(), newAdmin);
    }

    /// @inheritdoc ISecurityAdmin2Step
    function acceptSecurityAdministration() external {
        require(pendingSecurityAdmin() == msg.sender, "SA02: not pending admin");
        _transferSecurityAdministration(msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
            EXTERNAL CONVENIENCE/VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISecurityAdmin2Step
    function securityAdmin() public view virtual returns (address) {
        return _securityAdmin;
    }

    /// @inheritdoc ISecurityAdmin2Step
    function pendingSecurityAdmin() public view virtual returns (address) {
        return _pendingSecurityAdmin;
    }
}
