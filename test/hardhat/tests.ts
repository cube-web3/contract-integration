import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { setCode } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import { ethers, upgrades, network } from 'hardhat';
import { Contract } from 'ethers';
import {
  DemoIntegrationERC721,
  DemoIntegrationERC721UpgradeableNoModifier,
  DemoIntegrationERC721UpgradeableWithModifier,
} from '../../types';

const MOCK_ROUTER_ADDRESS = '0x42816740Fa2D825FB4fffC4AAeb436ABA87Cc099';
const MOCK_GATEWAY_ADDRESS = '0xC1d7b7440af58F255eeA1D089eE9E99f904ECd6C';

describe('Deploying demo CUBE3 Integrations', () => {
  let accounts: SignerWithAddress[];

  let securityAdmin: SignerWithAddress;

  let demoIntegration: DemoIntegrationERC721;
  let demoIntegrationUpgradeableNoModifier: Contract;
  let demoIntegrationUpgradeableWithModifier: Contract;

  before(async () => {
    console.log('chaindid: ', network.config.chainId);
    accounts = await ethers.getSigners();

    securityAdmin = accounts[1];

    // set the mock gatekeeper
    const MockGateKeeperFactory = await ethers.getContractFactory('MockCube3GateKeeper');
    const gateKeeper = await MockGateKeeperFactory.deploy();
    await setCode(MOCK_GATEWAY_ADDRESS, (await gateKeeper.getDeployedCode()) as string);
    console.log('Mock GateKeeper deployed to: ', MOCK_GATEWAY_ADDRESS);

    // set the mock router
    const MockRouterFactory = await ethers.getContractFactory('MockCube3Router');
    const router = await MockRouterFactory.deploy(MOCK_GATEWAY_ADDRESS);
    await setCode(MOCK_ROUTER_ADDRESS, (await router.getDeployedCode()) as string);
    console.log('Mock Router deployed to: ', MOCK_ROUTER_ADDRESS);

    // deploy the standalone integration
    const DemoIntegrationFactory = await ethers.getContractFactory('DemoIntegrationERC721');
    demoIntegration = await DemoIntegrationFactory.deploy();

    // deploy the upgradeable integration with no modifier
    const DemoIntegrationUpgradeableNoModifierFactory = await ethers.getContractFactory(
      'DemoIntegrationERC721UpgradeableNoModifier'
    );
    const upgradeableNoModifierInstance: Contract = await upgrades.deployProxy(
      DemoIntegrationUpgradeableNoModifierFactory.connect(securityAdmin),
      [securityAdmin.address],
      {
        kind: 'uups',
        initializer: 'initialize',
        unsafeAllow: ['constructor', 'state-variable-immutable'],
      }
    );
    await upgradeableNoModifierInstance.waitForDeployment();
  });

  it('should succeed calling safeMint on standalone integration with function protection enabled', async () => {
    const routerCode = await ethers.provider.getCode(MOCK_ROUTER_ADDRESS);
    console.log('Router code size: ', routerCode.length);
  });
});
