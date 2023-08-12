import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { setCode } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import { ethers, upgrades, network } from 'hardhat';

const MOCK_ROUTER_ADDRESS = '0x42816740Fa2D825FB4fffC4AAeb436ABA87Cc099';
const MOCK_GATEWAY_ADDRESS = '0xC1d7b7440af58F255eeA1D089eE9E99f904ECd6C';

describe('Deploying demo CUBE3 Integrations', () => {
  let accounts: SignerWithAddress[];

  before(async () => {
    console.log('chaindid: ', network.config.chainId);
    accounts = await ethers.getSigners();
    console.log({ accounts });

    // set the mock gatekeeper
    const MockGateKeeperFactory = await ethers.getContractFactory('MockCube3GateKeeper');
    const gatekeeperDeployTx = await MockGateKeeperFactory.getDeployTransaction();
    await setCode(MOCK_GATEWAY_ADDRESS, gatekeeperDeployTx.data);
    console.log('Mock GateKeeper deployed to: ', MOCK_GATEWAY_ADDRESS);

    // set the mock router
    const MockRouterFactory = await ethers.getContractFactory('MockCube3Router');
    const routerDeployTx = await MockRouterFactory.getDeployTransaction(MOCK_GATEWAY_ADDRESS);
    await setCode(MOCK_ROUTER_ADDRESS, routerDeployTx.data);
    console.log('Mock Router deployed to: ', MOCK_ROUTER_ADDRESS);
  });

  it('should have the correct mock router address', async () => {
    const routerCode = await ethers.provider.getCode(MOCK_ROUTER_ADDRESS);
    console.log('Router code size: ', routerCode.length);
  });
});
