import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { ethers, upgrades, network } from 'hardhat';

describe('Deploying demo CUBE3 Integrations', () => {
  let accounts: SignerWithAddress[];

  before(async () => {
    console.log('chaindid: ', network.config.chainId);
    accounts = await ethers.getSigners();
    console.log({ accounts });
  });
});
