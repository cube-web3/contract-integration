// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/*
 NOTE: This file's only purpose is to generate typechain files for the dummy contracts.

*/

import {VaultV1, VaultV2} from "../../test/foundry/dummy/DummyBeaconVault.sol";
import {DummyIntegrationTransparent, DummyIntegrationTransparentV2, DummyIntegrationTransparentV3} from "../../test/foundry/dummy/DummyIntegrationTransparent.sol";
import {DummyIntegrationUUPS, DummyIntegrationUUPSV2, DummyIntegrationUUPSV3} from "../../test/foundry/dummy/DummyIntegrationUUPS.sol";
import {DummyWalletFactory, DummyWalletImplementation} from "../../test/foundry/dummy/DummyWalletProtected.sol";

contract MockImports {
    // BeaconVaultFactory public beaconVaultFactory;
    // VaultBeacon public vaultBeacon;
    VaultV2 public vaultv2;
    VaultV1 public vaultv1;
    DummyIntegrationTransparent public dummyIntegrationTransparent;
    DummyIntegrationTransparentV2 public dummyIntegrationTransparentV2;
    DummyIntegrationTransparentV3 public dummyIntegrationTransparentV3;
    DummyIntegrationUUPS public dummyIntegrationUUPS;
    DummyIntegrationUUPSV2 public dummyIntegrationUUPSV2;
    DummyIntegrationUUPSV3 public dummyIntegrationUUPSV3;
    DummyWalletFactory public dummyWalletFactory;
    DummyWalletImplementation public dummyWalletImplementation;
}
