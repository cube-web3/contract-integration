// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol"; // inherited by SecurityAdmin2StepUpgradeable
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

import {Cube3IntegrationUpgradeable} from "../../../contracts/upgradeable/Cube3IntegrationUpgradeable.sol";

// The `Initializable` base contract is inherited by SecurityAdmin2StepUpgradeable, which is inherited by Cube3IntegrationUpgradeable, which is inherited by
// Cube3IntegrationERC721Upgradeable. Therefore, we don't import `Initializable` here to avoid a linearization of the inheritance graph error.
contract DemoIntegrationERC721UpgradeableNoModifier is Cube3IntegrationUpgradeable, ERC721Upgradeable, ERC721EnumerableUpgradeable, OwnableUpgradeable, UUPSUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;

    CountersUpgradeable.Counter private _tokenIdCounter;

    mapping(address => uint256) public mintsPerAddress;

    uint256 constant public MAX_MINT = 3;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address securityAdmin) initializer public {
        // initialize the token contract
        __ERC721_init("MyToken", "MTK");
        __ERC721Enumerable_init();
        __Ownable_init();
        __UUPSUpgradeable_init();

        // initialize the CUBE3 integration
        __Cube3IntegrationUpgradeable_init(securityAdmin);
    }

    // the `safeMint` fn intentionally omits the `cube3Protected` modifier
    function safeMint(uint256 qty) public {
        require(mintsPerAddress[msg.sender] + qty <= MAX_MINT, "Max mint per address reached");
        mintsPerAddress[msg.sender] += qty;
        
        uint256 tokenId;
        for (uint i; i < qty; ) {
            tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();

            _safeMint(msg.sender, tokenId);
            unchecked {
                ++i;
            }
        }
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner // could also use `onlySecurityAdmin` if the security admin is the same account as the deployer
        override
    {
        // preAuthorize the new implementation with the CUBE3 protocol
        _preAuthorizeNewImplementation(newImplementation);
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    // We need to override `supportsInterface` for all the upgradeable contracts we inherit from that
    // support ERC165.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(Cube3IntegrationUpgradeable, ERC721Upgradeable, ERC721EnumerableUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

contract DemoIntegrationERC721UpgradeableWithModifier is Cube3IntegrationUpgradeable, ERC721Upgradeable, ERC721EnumerableUpgradeable, OwnableUpgradeable, UUPSUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;

    CountersUpgradeable.Counter private _tokenIdCounter;

    mapping(address => uint256) public mintsPerAddress;

    uint256 constant public MAX_MINT = 3;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address securityAdmin) initializer public {
        // initialize the token contract
        __ERC721_init("MyToken", "MTK");
        __ERC721Enumerable_init();
        __Ownable_init();
        __UUPSUpgradeable_init();

        // initialize the CUBE3 integration
        __Cube3IntegrationUpgradeable_init(securityAdmin);
    }

    function safeMint(uint256 qty, bytes calldata cube3SecurePayload) public cube3Protected(cube3SecurePayload) {
        require(mintsPerAddress[msg.sender] + qty <= MAX_MINT, "Max mint per address reached");
        mintsPerAddress[msg.sender] += qty;
        
        uint256 tokenId;
        for (uint i; i < qty; ) {
            tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();

            _safeMint(msg.sender, tokenId);
            unchecked {
                ++i;
            }
        }
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {
        // preAuthorize the new implementation with the CUBE3 protocol
        _preAuthorizeNewImplementation(newImplementation);
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    // We need to override `supportsInterface` for all the upgradeable contracts we inherit from that
    // support ERC165.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(Cube3IntegrationUpgradeable, ERC721Upgradeable, ERC721EnumerableUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}