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
    return interfaceId == type(ICube3Router).interfaceId || interfaceId == 0x01ffc9a7; // erc165; 
  }
}


contract MockCube3GateKeeper {

  mapping(address => mapping(bytes4 => bool)) private _integrationProxyFunctionProtectionStatus; // integrationProxy => (fnSelector => enabled)

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

  event ProxyIntegrationFunctionProtectionStatusUpdated(
      address indexed integration,
      bytes4[] protectedFnSelectors,
      bool[] statuses
  );

  event IntegrationImplementationUpgradeAuthorized(
      address indexed currentImplementation,
      address indexed newImplementation
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

  // proxy-integration specific functions
  function integrationUpdateProxyFunctionProtectionStatus(
        address integrationSelf,
        bytes4[] calldata integrationFnSelectors,
        bool[] calldata status
    ) external {
        (integrationSelf);
        require(integrationFnSelectors.length == status.length, "GK07: array length mismatch");
        uint256 len = integrationFnSelectors.length;
        for (uint i; i < len; ) {
            _integrationProxyFunctionProtectionStatus[msg.sender][integrationFnSelectors[i]] = status[i];
            unchecked {
                ++i;
            }
        }
        emit ProxyIntegrationFunctionProtectionStatusUpdated(msg.sender, integrationFnSelectors, status);
    }

    function integrationCheckProxyFunctionProtectionStatusEnabled(
        address integrationSelf,
        bytes4 fnSelector
    ) external view returns (bool) {
        return _integrationProxyFunctionProtectionStatus[msg.sender][fnSelector];
    }

    function preAuthorizeImplementationUpgrade(
        address integrationSelf,
        address newImplementation
    ) external {
        require(integrationSelf != msg.sender, "GK09: only proxy");
        emit IntegrationImplementationUpgradeAuthorized(integrationSelf, newImplementation);
    }
 
  function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
   return interfaceId == type(ICube3GateKeeper).interfaceId || interfaceId == 0x01ffc9a7; // erc165;
  }
}