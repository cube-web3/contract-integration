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

const MINT_QTY = 2;

describe('Deploying demo CUBE3 Integrations', () => {
  let accounts: SignerWithAddress[];

  let securityAdmin: SignerWithAddress;
  let user: SignerWithAddress;

  let demoIntegration: DemoIntegrationERC721;
  let demoIntegrationUpgradeableNoModifier: any; // TODO: fix type
  let demoIntegrationUpgradeableWithModifier: any;

  beforeEach(async () => {
    console.log('chaindid: ', network.config.chainId);
    accounts = await ethers.getSigners();

    securityAdmin = accounts[1];
    user = accounts[2];

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
    demoIntegration = await DemoIntegrationFactory.connect(securityAdmin).deploy();

    // deploy the upgradeable integration with no modifier
    const DemoIntegrationUpgradeableNoModifierFactory = await ethers.getContractFactory(
      'DemoIntegrationERC721UpgradeableNoModifier'
    );
    demoIntegrationUpgradeableNoModifier = await upgrades.deployProxy(
      DemoIntegrationUpgradeableNoModifierFactory.connect(securityAdmin),
      [securityAdmin.address],
      {
        kind: 'uups',
        initializer: 'initialize',
        unsafeAllow: ['constructor', 'state-variable-immutable'],
      }
    );
    await demoIntegrationUpgradeableNoModifier.waitForDeployment();
  });

  it('should succeed calling safeMint on standalone integration with function protection enabled', async () => {
    const enabledByDefaultFnSelectors: string[] = [];
    enabledByDefaultFnSelectors.push(demoIntegration.safeMint.fragment.selector);

    const dummyRegistrarSignature = new Uint8Array(65);
    await demoIntegration
      .connect(securityAdmin)
      .registerIntegrationWithCube3(dummyRegistrarSignature, enabledByDefaultFnSelectors);

    const dummyCube3SecurePayload = new Uint8Array(64);
    await demoIntegration.connect(user).safeMint(MINT_QTY, dummyCube3SecurePayload);
    await expect(await demoIntegration.balanceOf(user.address)).equals(MINT_QTY);
  });

  it('should succeed calling safeMint on an upgradeable integration without the modifier', async () => {
    const enabledByDefaultFnSelectors: string[] = [];
    enabledByDefaultFnSelectors.push(demoIntegrationUpgradeableNoModifier.safeMint.fragment.selector);

    const dummyRegistrarSignature = new Uint8Array(65);
    await demoIntegrationUpgradeableNoModifier
      .connect(securityAdmin)
      .registerIntegrationWithCube3(dummyRegistrarSignature, enabledByDefaultFnSelectors);

    await demoIntegrationUpgradeableNoModifier.connect(user).safeMint(MINT_QTY);
    await expect(await demoIntegrationUpgradeableNoModifier.balanceOf(user.address)).equals(MINT_QTY);
  });

  it('should succeed upgrading to the contract using the modifier and calling safeMint', async () => {
    // register the integration - remember only the proxy address is registered
    let enabledByDefaultFnSelectors: string[] = [];
    enabledByDefaultFnSelectors.push(demoIntegrationUpgradeableNoModifier.safeMint.fragment.selector);

    const dummyRegistrarSignature = new Uint8Array(65);
    await demoIntegrationUpgradeableNoModifier
      .connect(securityAdmin)
      .registerIntegrationWithCube3(dummyRegistrarSignature, enabledByDefaultFnSelectors);

    // deploy the new contract instance
    const demoIntegrationUpgradeableWithModifierFactory = await ethers.getContractFactory(
      'DemoIntegrationERC721UpgradeableWithModifier'
    );

    // upgrade to the contract version that includes the modifier
    demoIntegrationUpgradeableWithModifier = await upgrades.upgradeProxy(
      await demoIntegrationUpgradeableNoModifier.getAddress(),
      demoIntegrationUpgradeableWithModifierFactory.connect(securityAdmin),
      {
        kind: 'uups',
        unsafeAllow: ['constructor', 'state-variable-immutable'],
      }
    );

    // The proxy is already registered and the new implementation is pre-authorized, however we will need to enable function
    // protection for `safeMint` on the new implementation as the function selector has changed with the inclusion
    // of the `cube3SecurePayload`
    const enabledFnSelectors: string[] = [];
    enabledFnSelectors.push(demoIntegrationUpgradeableWithModifier.safeMint.fragment.selector);

    await demoIntegrationUpgradeableWithModifier.setFunctionProtectionStatus(enabledFnSelectors, [true]);
    await expect(await demoIntegrationUpgradeableWithModifier.isFunctionProtectionEnabled(enabledFnSelectors[0])).is
      .true;

    // mint tokens
    const dummyCube3SecurePayload = new Uint8Array(64);
    await demoIntegrationUpgradeableWithModifier.connect(user).safeMint(MINT_QTY, dummyCube3SecurePayload);
    const balance = await demoIntegrationUpgradeableWithModifier.balanceOf(user.address);
    await expect(balance).equals(MINT_QTY);
  });
});
