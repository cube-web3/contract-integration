// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {DemoIntegrationERC721} from "../../contracts/example/DemoIntegrationERC721.sol";
import {DemoIntegrationERC721UpgradeableNoModifier,DemoIntegrationERC721UpgradeableWithModifier} from "../../contracts/example/DemoIntegrationERC721Upgradeable.sol";
import {Cube3ProtocolTestUtils} from "./utils/deploy.sol";

// inheirt from the Cube3ProtocolTestUtils contract to gain access to the mock CUBE3 protocol contracts
// Cube3ProtocolTestUtils inherits from `forge-std/Test.sol`
contract DemoTest is Cube3ProtocolTestUtils {

    DemoIntegrationERC721 internal demo;

    ERC1967Proxy internal demoProxy;
    DemoIntegrationERC721UpgradeableNoModifier internal demoUpgradeableNoModifier;
    DemoIntegrationERC721UpgradeableNoModifier internal wrappedDemoProxy;

    address internal integrationSecurityAdmin = makeAddr("integrationSecurityAdmin");

    function setUp() public {
        // mock CUBE3 protocol contracts MUST be deployed before running the tests
        _deployMockCube3Protocol();

        vm.startPrank(integrationSecurityAdmin);

        // deploy the standalone demo integration, where the security admin is implictly the deployer
        demo = new DemoIntegrationERC721();

        // deploy the upgradeable integration implementation
        demoUpgradeableNoModifier = new DemoIntegrationERC721UpgradeableNoModifier();

        // deploy the proxy and set the security admin address explicityl
        demoProxy = new ERC1967Proxy(
            address(demoUpgradeableNoModifier),
            abi.encodeCall(DemoIntegrationERC721UpgradeableNoModifier.initialize, (integrationSecurityAdmin))
        );

        vm.stopPrank();

        // wrap the proxy in the implementation's interface for convenience
        wrappedDemoProxy = DemoIntegrationERC721UpgradeableNoModifier(address(demoProxy));
    }


    // test calling the `safeMint` function on a standalone integration that has function-level protecion enabled
    function testStandaloneMint() public {

        // Register the the integration with the CUBE3 protocol.
        bytes4[] memory enabledByDefaultFnSelectors = new bytes4[](1);
        enabledByDefaultFnSelectors[0] = demo.safeMint.selector;

        vm.startPrank(integrationSecurityAdmin);

        // Under normal circumstances, the registrar signature would be provided off-chain by the CUBE3 platform.
        // The mock protocol allows use an empty signature generated on-chain for testing purposes.
        bytes memory registrarSignature = new bytes(65);
        demo.registerIntegrationWithCube3(registrarSignature, enabledByDefaultFnSelectors);

        vm.stopPrank();

        // The `cube3SecurePayload` parameter is required for all functions that are protected by the `cube3Protected` modifier.
        // The payload is generated off-chain by the CUBE3 platform and provided to the EOA executing the TX.
        // For the purposes of testing, we can just pass an empty bytes array, with minimum length of 64 bytes, as the payload to mimic
        // the protocol's behaviour.
        bytes memory cube3SecurePayload = new bytes(64);
        
        // call the mint function as the end-user
        address user = makeAddr("user");
        vm.startPrank(user);
        demo.safeMint(1, cube3SecurePayload);


    }



    // test calling the `safeMint` function on an upgradeable integration that has not included the `cube3Protected` modifier
    // and successfully mints a token.
    function testUpgradeableMintNoModifier() public {

        _registerProxyWithCube3();

        // call the mint function as the end-user
        address user = makeAddr("user");
        vm.startPrank(user);
        wrappedDemoProxy.safeMint(1);
    }

    // test upgrading the upgradeable ERC721 proxy to a new implementation that includes the
    // `cube3protected` modifier on the `safeMint` function, enables function-level protection, and
    // successfully mints a token.
    function testUpgradeAndMintWithModifier() public {

        _registerProxyWithCube3();
        
        vm.startPrank(integrationSecurityAdmin);
        
        // deploy the new implementation
        DemoIntegrationERC721UpgradeableWithModifier demoUpgradeableWithModifier = new DemoIntegrationERC721UpgradeableWithModifier();

        // upgrade the proxy to the new implementation
        wrappedDemoProxy.upgradeTo(address(demoUpgradeableWithModifier));

        // wrap the proxy in the implementation's interface for convenience
        DemoIntegrationERC721UpgradeableWithModifier wrappedDemoProxyWithModifier = DemoIntegrationERC721UpgradeableWithModifier(address(demoProxy));

        // The proxy is already registered and the new implementation is pre-authorized, however we will need to enable function
        // protection for `safeMint` as the function selector has changed with the inclusion of the `cube3SecurePayload`
        bytes4[] memory enabledFnSelectors = new bytes4[](1);
        bool[] memory fnSelectorStatus = new bool[](1);
        enabledFnSelectors[0] = wrappedDemoProxyWithModifier.safeMint.selector;
        fnSelectorStatus[0] = true;
        wrappedDemoProxyWithModifier.setFunctionProtectionStatus(enabledFnSelectors, fnSelectorStatus);

        vm.stopPrank();

        // call the mint function as the end-user

        // The `cube3SecurePayload` parameter is required for all functions that are protected by the `cube3Protected` modifier.
        // The payload is generated off-chain by the CUBE3 platform and provided to the EOA executing the TX.
        // For the purposes of testing, we can just pass an empty bytes array, with minimum length of 64 bytes, as the payload to mimic
        // the protocol's behaviour.
        bytes memory cube3SecurePayload = new bytes(64);
        
        // call the mint function as the end-user
        address user = makeAddr("user");
        vm.startPrank(user);
        wrappedDemoProxyWithModifier.safeMint(1, cube3SecurePayload);

    }

    // Helper functions
    function _registerProxyWithCube3() internal {
    
        // Register the the integration with the CUBE3 protocol.
        bytes4[] memory enabledByDefaultFnSelectors = new bytes4[](1);
        enabledByDefaultFnSelectors[0] = wrappedDemoProxy.safeMint.selector;

        vm.startPrank(integrationSecurityAdmin);

        // Under normal circumstances, the registrar signature would be provided off-chain by the CUBE3 platform.
        // The mock protocol allows use an empty signature generated on-chain for testing purposes.
        // Unlike the standalone, the upgradeable integration stores its function-level protection in the GateKeeper contract.
        bytes memory registrarSignature = new bytes(65);
        wrappedDemoProxy.registerIntegrationWithCube3(registrarSignature, enabledByDefaultFnSelectors);

        vm.stopPrank();
    }
}