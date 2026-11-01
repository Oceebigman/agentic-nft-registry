// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IBinanceAgentIdRegistry {
    function handleOf(address account) external view returns (string memory);
}

/// @notice ERC-721 collection restricted to wallets with a registered Binance .ai Agent ID.
/// Mint quotas are keyed by keccak256(handle), not wallet address, so changing wallets
/// does not reset an Agent ID's quotas.
contract AgentIdCollection is ERC721, Ownable, ReentrancyGuard {
    IBinanceAgentIdRegistry public immutable agentRegistry;

    uint256 public immutable maxSupply;
    uint256 public immutable freeAllocation;
    uint256 public immutable paidAllocation;
    uint256 public immutable freeLimitPerAgentId;
    uint256 public immutable paidLimitPerAgentId;
    uint256 public immutable mintPrice;
    address payable public immutable treasury;

    uint256 public totalFreeMinted;
    uint256 public totalPaidMinted;
    uint256 private nextTokenId = 1;

    mapping(bytes32 => uint256) public mintedByAgentId;
    mapping(bytes32 => uint256) public freeMintedByAgentId;
    mapping(bytes32 => uint256) public paidMintedByAgentId;

    event Minted(address indexed recipient, bytes32 indexed agentKey, uint256 quantity, bool isFree);
    event TreasuryPaymentForwarded(address indexed recipient, uint256 amount);
    event TreasuryWithdrawal(address indexed recipient, uint256 amount);

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 maxSupply_,
        uint256 freeAllocation_,
        uint256 paidAllocation_,
        uint256 paidLimitPerAgentId_,
        uint256 mintPrice_,
        address payable treasury_,
        address agentRegistry_
    ) ERC721(name_, symbol_) Ownable(msg.sender) {
        require(maxSupply_ > 0, "Supply must be positive");
        require(freeAllocation_ + paidAllocation_ == maxSupply_, "Allocations mismatch");
        require(treasury_ != address(0), "Invalid treasury");
        require(agentRegistry_ != address(0), "Invalid Agent ID registry");
        require(paidLimitPerAgentId_ > 0, "Invalid paid limit");

        maxSupply = maxSupply_;
        freeAllocation = freeAllocation_;
        paidAllocation = paidAllocation_;
        freeLimitPerAgentId = 1;
        paidLimitPerAgentId = paidLimitPerAgentId_;
        mintPrice = mintPrice_;
        treasury = treasury_;
        agentRegistry = IBinanceAgentIdRegistry(agentRegistry_);
    }

    function agentKeyOf(address wallet) external view returns (bytes32) {
        return _agentKeyFor(wallet);
    }

    function mintFree(uint256 quantity) external nonReentrant {
        require(quantity > 0, "Quantity must be positive");
        bytes32 agentKey = _agentKeyFor(msg.sender);
        require(freeMintedByAgentId[agentKey] + quantity <= freeLimitPerAgentId, "Agent ID free limit exceeded");
        require(totalFreeMinted + quantity <= freeAllocation, "Free allocation exceeded");
        require(totalMinted() + quantity <= maxSupply, "Max supply exceeded");

        freeMintedByAgentId[agentKey] += quantity;
        mintedByAgentId[agentKey] += quantity;
        totalFreeMinted += quantity;

        _mintTokens(msg.sender, quantity);
        emit Minted(msg.sender, agentKey, quantity, true);
    }

    function mint(uint256 quantity) external payable nonReentrant {
        require(quantity > 0, "Quantity must be positive");
        bytes32 agentKey = _agentKeyFor(msg.sender);
        require(paidMintedByAgentId[agentKey] + quantity <= paidLimitPerAgentId, "Agent ID paid limit exceeded");
        require(totalPaidMinted + quantity <= paidAllocation, "Paid allocation exceeded");
        require(totalMinted() + quantity <= maxSupply, "Max supply exceeded");
        require(msg.value == mintPrice * quantity, "Incorrect payment");

        paidMintedByAgentId[agentKey] += quantity;
        mintedByAgentId[agentKey] += quantity;
        totalPaidMinted += quantity;

        _mintTokens(msg.sender, quantity);

        if (msg.value > 0) {
            (bool success,) = treasury.call{value: msg.value}("");
            require(success, "Treasury payment failed");
            emit TreasuryPaymentForwarded(treasury, msg.value);
        }

        emit Minted(msg.sender, agentKey, quantity, false);
    }

    function _agentKeyFor(address wallet) internal view returns (bytes32) {
        try agentRegistry.handleOf(wallet) returns (string memory handle) {
            require(bytes(handle).length > 0, "No Binance Agent ID");
            return keccak256(bytes(handle));
        } catch {
            revert("Agent ID registry unavailable");
        }
    }

    function _mintTokens(address recipient, uint256 quantity) internal {
        for (uint256 i = 0; i < quantity; i++) {
            _safeMint(recipient, nextTokenId);
            nextTokenId++;
        }
    }

    function totalMinted() public view returns (uint256) {
        return nextTokenId - 1;
    }

    function remainingSupply() external view returns (uint256) {
        return maxSupply - totalFreeMinted - totalPaidMinted;
    }

    function withdraw() external nonReentrant onlyOwner {
        uint256 amount = address(this).balance;
        require(amount > 0, "No funds");
        (bool success,) = treasury.call{value: amount}("");
        require(success, "Transfer failed");
        emit TreasuryWithdrawal(treasury, amount);
    }
}
