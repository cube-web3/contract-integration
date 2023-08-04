// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ISecurityAdmin2Step} from "./ISecurityAdmin2Step.sol";

/// @title Security Administration 2 step.
/// @author CUBE3.ai
/// @notice Upgradeable version of {SecurityAdmin2Step}.
/// @dev For use with a proxy.
/// @dev Based on the OpenZeppelin {Ownable2StepUpgradeable} implementation.
/// @dev Overriding functions that deal with the security administration should be done so with caution.
///      Incorrectly overriding a virtual function can nullify the security mechanisms provided by this module.
/// @dev This module is used through inheritance.
/// @dev This module does not include a {renounceSecurityAdministration} function, as CUBE3's service cannot be
///      considered fully decentralized, and renouncing security administration could render the contract unusable
///      should CUBE3's service permanently go offline and function protection remains enabled.
interface ISecurityAdmin2StepUpgradeable is ISecurityAdmin2Step {

}
