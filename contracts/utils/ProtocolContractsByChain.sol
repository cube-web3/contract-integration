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
        } else if (block.chainid == 5) {
            // goerli
            routerProxy = 0x5ec02641b145A7FdE91261B983fd1743Cb37b914;
            gateKeeper = 0x5946959A7247F96EC4657ca0272C558f0aC11CC3;
        } else if (block.chainid == 11155111) {
            // sepolia
            routerProxy = 0xb2959138D27b63e2728e0960F9c7b0BdC4169870;
            gateKeeper = 0x86F3ed7D7F75e2675B83a8C6B01baD0A4b748eB3;
        } else {
            revert("Unrecognized chain id");
        }
    }
}
