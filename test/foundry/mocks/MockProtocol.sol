// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ICube3Data} from "../../../contracts/interfaces/ICube3Data.sol";
import {ICube3Router} from "../../../contracts/interfaces/ICube3Router.sol";
import {ICube3GateKeeper} from "../../../contracts/interfaces/ICube3GateKeeper.sol";

contract MockCube3Router {

  address internal immutable _gateKeeper;
  constructor(address gateKeeper) {
    _gateKeeper = gateKeeper;
  }

  function routeToModule(
      address integrationMsgSender,
      address integrationSelf,
      uint256 integrationMsgValue,
      uint256 cube3PayloadLength,
      bytes calldata integrationMsgData
  ) external virtual returns (bool) {
    (integrationMsgSender, integrationSelf, integrationMsgValue, cube3PayloadLength, integrationMsgData);
    return true;
  }

  function initiate2StepIntegrationRegistration(
    address integrationSelf,
    bytes calldata registrarSignature
  ) external returns (bool) {
    (registrarSignature);
    ICube3GateKeeper(_gateKeeper).complete2StepIntegrationRegistration(msg.sender, integrationSelf);
    return true;
  }

  function supportsInterface(bytes4 interfaceId) public pure returns (bool) {

    return interfaceId == type(ICube3Router).interfaceId; // type(ICube3Router).interfaceId
  }
}


contract MockCube3GateKeeper {

  event IntegrationRegistrationStatusUpdated(
    address indexed integrationOrProxy,
    address indexed integrationOrImplementation,
    ICube3Data.RegistrationStatus status
  );

  event IntegrationAuthorizationStatusUpdated(
    address indexed integrationOrProxy,
    address indexed integrationOrImplementation,
    ICube3Data.AuthorizationStatus status
  );

  function complete2StepIntegrationRegistration(
      address integrationOrProxy,
      address integrationOrImplementation
  ) external {
    emit IntegrationAuthorizationStatusUpdated(
        integrationOrProxy,
        integrationOrImplementation,
        ICube3Data.AuthorizationStatus.ACTIVE
    );
    emit IntegrationRegistrationStatusUpdated(
        integrationOrProxy,
        integrationOrImplementation,
        ICube3Data.RegistrationStatus.REGISTERED
    );
  }

  function preRegisterAsIntegration(address integrationSelf) public {
    emit IntegrationRegistrationStatusUpdated(msg.sender, integrationSelf, ICube3Data.RegistrationStatus.PENDING);
  }
 
  function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
   return interfaceId == type(ICube3GateKeeper).interfaceId;
  }
}