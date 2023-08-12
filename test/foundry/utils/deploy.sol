// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";

import {ProtocolContractsByChain} from "../../../contracts/utils/ProtocolContractsByChain.sol";
import {MockCube3GateKeeper, MockCube3Router} from "../../mocks/MockProtocol.sol";


abstract contract Cube3ProtocolTestUtils is Test {

  MockCube3GateKeeper internal mockCube3GateKeeper;
  MockCube3Router internal mockCube3Router;

  function _deployMockCube3Protocol() internal {
    mockCube3GateKeeper = new MockCube3GateKeeper();
    mockCube3Router = new MockCube3Router(address(mockCube3GateKeeper));

    (address desiredRouterAddress, address desiredGateKeeperAddress) = ProtocolContractsByChain._getProtocolAddressesByChainId();
    vm.etch(desiredRouterAddress,address(mockCube3Router).code);
    vm.etch(desiredGateKeeperAddress,address(mockCube3GateKeeper).code);
  }

}