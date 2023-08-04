// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

library ProtocolContractsByChain {
    function _getProtocolAddressesByChainId() internal view returns (address routerProxy, address gateKeeper) {
        if (block.chainid == 69) {
            // local node
            routerProxy = 0xDf923b5dB42D88f4e0D1784D87Bc3b3b2f555417;
            gateKeeper = 0x58704B29330325af2F2C5c3a4fD5Ea16eD5CC52B;
        } else if (block.chainid == 1337) {
            // hardhat
            routerProxy = 0x42816740Fa2D825FB4fffC4AAeb436ABA87Cc099;
            gateKeeper = 0xC1d7b7440af58F255eeA1D089eE9E99f904ECd6C;
        } else if (block.chainid == 31337) {
            // anvil
            routerProxy = 0x269D11C666450B896b3e1f867FB6D86805c57D8F;
            gateKeeper = 0xF66e74DC65d9a54c0867213ec0885576656e2D28;
        } else if (block.chainid == 1) {
            // mainnet - TODO: verify these after mainnet fork tests
            routerProxy = 0xF4b3626BbDbAeF3c8075E662DBb5c5dD1a0E3516;
            gateKeeper = 0x81Ee23998618846D8Bd3d8ECDF51C71aa2E95D79;
        } else if (block.chainid == 5) {
            // goerli
            routerProxy = 0x5ec02641b145A7FdE91261B983fd1743Cb37b914;
            gateKeeper = 0x5946959A7247F96EC4657ca0272C558f0aC11CC3;
        } else if (block.chainid == 137) {
            // polygon
            routerProxy = 0xF4b3626BbDbAeF3c8075E662DBb5c5dD1a0E3516;
            gateKeeper = 0x81Ee23998618846D8Bd3d8ECDF51C71aa2E95D79;
        } else {
            revert("Unrecognized chain id");
        }
    }
}
