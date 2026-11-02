// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

interface IFreeClaimAgentRegistry {
    function handleOf(address wallet) external view returns (string memory);
}

/// @notice Fixed-price ERC-721: ID-gated free Scout claims and public paid Founder mints.
/// @dev No lifetime paid-wallet quota, metadata setters, price setters, supply setters,
///      owner mint, proxy, or dependence on the Agent ID registry in the paid path.
contract PublicPaidCollection is ERC721, Ownable, ReentrancyGuard {
    using Strings for uint256;

    struct Config {
        string name;
        string symbol;
        string description;
        uint256 maxSupply;
        uint256 freeAllocation;
        uint256 mintPrice;
        bool bundleDiscountEnabled;
        string scoutImageURI;
        string founderImageURI;
        address payable treasury;
        address agentRegistry;
    }

    uint256 public constant maxMintPerTransaction = 20;
    uint256 public constant freeLimitPerAgentId = 1;
    uint256 public constant freeLimitPerWallet = 1;
    uint256 public constant bundleSize = 5;
    uint256 public constant bundlePayFor = 4;

    uint256 public immutable maxSupply;
    uint256 public immutable freeAllocation;
    uint256 public immutable paidAllocation;
    uint256 public immutable mintPrice;
    bool public immutable bundleDiscountEnabled;
    address payable public immutable treasury;
    IFreeClaimAgentRegistry public immutable agentRegistry;

    // Constructor-only values: there is no method to change these after deployment.
    string public description;
    string public scoutImageURI;
    string public founderImageURI;
    uint256 public totalFreeMinted;
    uint256 public totalPaidMinted;
    uint256 private nextTokenId = 1;
    mapping(bytes32 => uint256) public freeMintedByAgentId;
    mapping(address => uint256) public freeMintedByWallet;
    mapping(address => uint256) public paidMintedByWallet;
    mapping(uint256 => bool) private founderEdition;

    event Minted(address indexed recipient, uint256 quantity, bool isFree);
    event EditionMinted(
        address indexed recipient, uint256 indexed firstTokenId, uint256 quantity, bool founder, uint256 payment
    );
    event TreasuryPaymentForwarded(address indexed recipient, uint256 amount);
    event TreasuryWithdrawal(address indexed recipient, uint256 amount);

    error InvalidConfiguration();
    error InvalidQuantity();
    error FreeAllocationExceeded();
    error PaidAllocationExceeded();
    error NoAgentId();
    error AgentRegistryUnavailable();
    error FreeClaimAlreadyUsed();
    error IncorrectPayment(uint256 expected, uint256 received);
    error TreasuryPaymentFailed();
    error NoFunds();

    constructor(Config memory config) ERC721(config.name, config.symbol) Ownable(msg.sender) {
        if (
            bytes(config.name).length == 0 || bytes(config.symbol).length == 0 || bytes(config.description).length == 0
                || config.maxSupply == 0 || config.freeAllocation >= config.maxSupply || config.mintPrice == 0
                || config.mintPrice > type(uint256).max / maxMintPerTransaction || config.treasury == address(0)
                || (config.freeAllocation > 0 && config.agentRegistry.code.length == 0)
                || !_isContentAddressed(config.scoutImageURI) || !_isContentAddressed(config.founderImageURI)
                || keccak256(bytes(config.scoutImageURI)) == keccak256(bytes(config.founderImageURI))
        ) revert InvalidConfiguration();

        maxSupply = config.maxSupply;
        freeAllocation = config.freeAllocation;
        paidAllocation = config.maxSupply - config.freeAllocation;
        mintPrice = config.mintPrice;
        bundleDiscountEnabled = config.bundleDiscountEnabled;
        treasury = config.treasury;
        agentRegistry = IFreeClaimAgentRegistry(config.agentRegistry);
        description = config.description;
        scoutImageURI = config.scoutImageURI;
        founderImageURI = config.founderImageURI;
    }

    /// @notice Total BNB in wei for a paid batch. Independent of wallet and registry state.
    /// @dev On discounted collections, each complete group of five costs four base prices.
    function quoteMint(uint256 quantity) public view returns (uint256) {
        if (quantity == 0 || quantity > maxMintPerTransaction) revert InvalidQuantity();
        uint256 billable = bundleDiscountEnabled ? quantity - quantity / bundleSize : quantity;
        return billable * mintPrice;
    }

    /// @notice Any wallet may buy repeatedly, including after a free claim.
    function mint(uint256 quantity) external payable nonReentrant {
        uint256 payment = quoteMint(quantity);
        if (totalPaidMinted + quantity > paidAllocation) revert PaidAllocationExceeded();
        if (msg.value != payment) revert IncorrectPayment(payment, msg.value);
        totalPaidMinted += quantity;
        paidMintedByWallet[msg.sender] += quantity;
        uint256 firstTokenId = _mintEdition(msg.sender, quantity, true);
        (bool success,) = treasury.call{value: payment}("");
        if (!success) revert TreasuryPaymentFailed();
        emit TreasuryPaymentForwarded(treasury, payment);
        emit Minted(msg.sender, quantity, false);
        emit EditionMinted(msg.sender, firstTokenId, quantity, true, payment);
    }

    /// @notice One free Scout per registered handle AND per wallet, independently of paid minting.
    function mintFree(uint256 quantity) external nonReentrant {
        if (quantity != 1) revert InvalidQuantity();
        if (totalFreeMinted >= freeAllocation) revert FreeAllocationExceeded();
        bytes32 key = _agentKeyFor(msg.sender);
        if (freeMintedByAgentId[key] != 0 || freeMintedByWallet[msg.sender] != 0) revert FreeClaimAlreadyUsed();
        freeMintedByAgentId[key] = 1;
        freeMintedByWallet[msg.sender] = 1;
        ++totalFreeMinted;
        uint256 firstTokenId = _mintEdition(msg.sender, 1, false);
        emit Minted(msg.sender, 1, true);
        emit EditionMinted(msg.sender, firstTokenId, 1, false, 0);
    }

    function agentKeyOf(address wallet) external view returns (bytes32) {
        return _agentKeyFor(wallet);
    }

    function _agentKeyFor(address wallet) private view returns (bytes32) {
        string memory handle;
        try agentRegistry.handleOf(wallet) returns (string memory value) {
            handle = value;
        } catch {
            revert AgentRegistryUnavailable();
        }
        if (bytes(handle).length == 0) revert NoAgentId();
        return keccak256(bytes(handle));
    }

    function _mintEdition(address recipient, uint256 quantity, bool founder) private returns (uint256 first) {
        first = nextTokenId;
        nextTokenId += quantity;
        for (uint256 id = first; id < first + quantity; ++id) {
            founderEdition[id] = founder;
            _safeMint(recipient, id);
        }
    }

    function totalMinted() public view returns (uint256) {
        return totalFreeMinted + totalPaidMinted;
    }

    function remainingSupply() external view returns (uint256) {
        return maxSupply - totalMinted();
    }

    function remainingFreeSupply() external view returns (uint256) {
        return freeAllocation - totalFreeMinted;
    }

    function remainingPaidSupply() external view returns (uint256) {
        return paidAllocation - totalPaidMinted;
    }

    function isFounderEdition(uint256 tokenId) public view returns (bool) {
        _requireOwned(tokenId);
        return founderEdition[tokenId];
    }

    function editionOf(uint256 tokenId) external view returns (string memory) {
        return isFounderEdition(tokenId) ? "Founder" : "Scout";
    }

    /// @notice Fully on-chain JSON; edition image links are fixed content-addressed IPFS URIs.
    /// @dev An edition shares its artwork; each NFT has its own serial and permanent edition trait.
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        bool founder = isFounderEdition(tokenId);
        string memory edition = founder ? "Founder" : "Scout";
        bytes memory metadata = abi.encodePacked(
            '{"name":"',
            Strings.escapeJSON(name()),
            " ",
            edition,
            " #",
            tokenId.toString(),
            '","description":"',
            Strings.escapeJSON(description),
            '","image":"',
            Strings.escapeJSON(founder ? founderImageURI : scoutImageURI),
            '","attributes":[{"trait_type":"Edition","value":"',
            edition,
            '"},{"trait_type":"Mint route","value":"',
            founder ? "Paid" : "Free ID claim",
            '"},{"trait_type":"Serial","value":',
            tokenId.toString(),
            "}]}"
        );
        return string.concat("data:application/json;base64,", Base64.encode(metadata));
    }

    function contractURI() external view returns (string memory) {
        return string.concat(
            "data:application/json;base64,",
            Base64.encode(
                abi.encodePacked(
                    '{"name":"',
                    Strings.escapeJSON(name()),
                    '","description":"',
                    Strings.escapeJSON(description),
                    '","image":"',
                    Strings.escapeJSON(founderImageURI),
                    '"}'
                )
            )
        );
    }

    /// @notice Recovery for forced BNB only. Proceeds always go to the same immutable treasury.
    function withdraw() external nonReentrant onlyOwner {
        uint256 amount = address(this).balance;
        if (amount == 0) revert NoFunds();
        (bool success,) = treasury.call{value: amount}("");
        if (!success) revert TreasuryPaymentFailed();
        emit TreasuryWithdrawal(treasury, amount);
    }

    function _isContentAddressed(string memory uri) private pure returns (bool) {
        bytes memory value = bytes(uri);
        // Actual CID validity and content availability are verified by the asset pipeline.
        return value.length > 12 && value[0] == "i" && value[1] == "p" && value[2] == "f" && value[3] == "s"
            && value[4] == ":" && value[5] == "/" && value[6] == "/";
    }
}
