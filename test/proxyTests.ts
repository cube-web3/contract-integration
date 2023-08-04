import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { ethers, upgrades, network } from 'hardhat';
import {
  DummyIntegrationTransparent,
  Cube3RouterLogic,
  Cube3GateKeeper,
  DummyIntegrationUUPS,
  DummyWalletFactory,
  DummyWalletImplementation,
  VaultV1,
  VaultV2,
} from '../typechain-types';

describe('Deploying a Transparent Upgradeable Proxy with Cube3IntegrationUpgradeable', () => {
  let accounts: SignerWithAddress[];
  let cube3Router: Cube3RouterLogic;
  let cube3GateKeeper: Cube3GateKeeper;
  let transparentProxy: DummyIntegrationTransparent;
  let uupsProxy: DummyIntegrationUUPS;
  let minimalFactory: DummyWalletFactory;
  let minimalImplementation: DummyWalletImplementation;

  // users
  let cubeDeployer: SignerWithAddress;
  let integrationDeployer: SignerWithAddress;
  let user: SignerWithAddress;

  before(async () => {
    console.log('chaindid: ', network.config.chainId);
    accounts = await ethers.getSigners();
    cubeDeployer = accounts[1];
    integrationDeployer = accounts[2];
    user = accounts[3];

    const Cube3RouterLogic = await ethers.getContractFactory('Cube3RouterLogic');
    const Cube3GateKeeper = await ethers.getContractFactory('Cube3GateKeeper');

    // deploy router
    cube3Router = (await upgrades.deployProxy(Cube3RouterLogic.connect(cubeDeployer), [], {
      initializer: 'initialize',
    })) as Cube3RouterLogic;

    // deployer the gatekeeper
    cube3GateKeeper = (await Cube3GateKeeper.connect(cubeDeployer).deploy(cube3Router.address)) as Cube3GateKeeper;

    console.log('router: ', cube3Router.address);
    console.log('gatekeeper', cube3GateKeeper.address);
  });

  it('should deploy the transparent proxy', async () => {
    const DummyIntegrationTransparent = await ethers.getContractFactory('DummyIntegrationTransparent');

    transparentProxy = (await upgrades.deployProxy(
      DummyIntegrationTransparent.connect(integrationDeployer),
      [integrationDeployer.address],
      {
        kind: 'transparent',
        initializer: 'initialize',
        unsafeAllow: ['constructor', 'state-variable-immutable'],
      }
    )) as DummyIntegrationTransparent;

    console.log('transparentProxy', transparentProxy.address);
    console.log('securityAdmin', await transparentProxy.securityAdmin());

    const [proxy, impl] = await transparentProxy.self();
    console.log({ proxy, impl });
  });

  it('should deploy the UUPS proxy', async () => {
    const DummyIntegrationUUPS = await ethers.getContractFactory('DummyIntegrationUUPS');

    uupsProxy = (await upgrades.deployProxy(
      DummyIntegrationUUPS.connect(integrationDeployer),
      [integrationDeployer.address],
      {
        kind: 'uups',
        initializer: 'initialize',
        unsafeAllow: ['constructor', 'state-variable-immutable'],
      }
    )) as DummyIntegrationUUPS;
  });

  it('should deploy the minimal proxy forwarder', async () => {
    const DummyWalletFactory = await ethers.getContractFactory('DummyWalletFactory');
    const DummyWalletImplementation = await ethers.getContractFactory('DummyWalletImplementation');

    minimalImplementation = (await DummyWalletImplementation.connect(
      integrationDeployer
    ).deploy()) as DummyWalletImplementation;
    minimalFactory = (await DummyWalletFactory.connect(integrationDeployer).deploy(
      minimalImplementation.address
    )) as DummyWalletFactory;

    // create a wallet for a user
    const tx = await minimalFactory
      .connect(user)
      .createWallet(ethers.utils.keccak256(ethers.utils.toUtf8Bytes(user.address + '-user')), user.address);

    await tx.wait();
  });

  it('should deploy the beacon proxy', async () => {
    const VaultV1 = await ethers.getContractFactory('VaultV1');
    const VaultV2 = await ethers.getContractFactory('VaultV2');
    const initialValue = 69;

    const beacon = await upgrades.deployBeacon(VaultV1, {
      unsafeAllow: ['constructor', 'state-variable-immutable'],
    });
    const instance = await upgrades.deployBeaconProxy(
      beacon,
      VaultV1,
      [user.address, 'VaultV1', ethers.BigNumber.from(initialValue)],
      {
        initializer: 'initialize',
      }
    );

    await upgrades.upgradeBeacon(beacon, VaultV2, {
      unsafeAllow: ['constructor', 'state-variable-immutable'],
    });
    const upgraded = VaultV2.attach(instance.address);

    let value = await upgraded.value();
    console.log('value: ', value);
    expect(value).to.equal(initialValue);
  });
});
