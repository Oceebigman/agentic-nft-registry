// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract AgenticCollection is ERC721, Ownable, ReentrancyGuard {
    uint256 public immutable maxSupply;
    uint256 public immutable freeAllocation;
    uint256 public immutable paidAllocation;
    uint256 public immutable freeLimitPerWallet;
    uint256 public immutable paidLimitPerWallet;
    uint256 public immutable mintPrice;

    address payable public immutable treasury;

    uint256 public totalFreeMinted;
    uint256 public totalPaidMinted;
    uint256 private nextTokenId = 1;

    mapping(address => uint256) public freeMintedByWallet;
    mapping(address => uint256) public paidMintedByWallet;

    event Minted(address indexed recipient, uint256 quantity, bool isFree);
    event TreasuryPaymentForwarded(address indexed recipient, uint256 amount);
    event TreasuryWithdrawal(address indexed recipient, uint256 amount);

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 maxSupply_,
        uint256 freeAllocation_,
        uint256 paidAllocation_,
        uint256 freeLimitPerWallet_,
        uint256 paidLimitPerWallet_,
        uint256 mintPrice_,
        address payable treasury_
    ) ERC721(name_, symbol_) Ownable(msg.sender) {
        require(maxSupply_ > 0, "Supply must be positive");
        require(freeAllocation_ + paidAllocation_ == maxSupply_, "Allocations mismatch");
        require(treasury_ != address(0), "Invalid treasury");

        maxSupply = maxSupply_;
        freeAllocation = freeAllocation_;
        paidAllocation = paidAllocation_;
        freeLimitPerWallet = freeLimitPerWallet_;
        paidLimitPerWallet = paidLimitPerWallet_;
        mintPrice = mintPrice_;
        treasury = treasury_;
    }

    function mintFree(uint256 quantity) external nonReentrant {
        require(quantity > 0, "Quantity must be positive");
        require(totalFreeMinted + quantity <= freeAllocation, "Free allocation exceeded");
        require(freeMintedByWallet[msg.sender] + quantity <= freeLimitPerWallet, "Free wallet limit exceeded");

        totalFreeMinted += quantity;
        freeMintedByWallet[msg.sender] += quantity;

        _mintTokens(msg.sender, quantity);
        emit Minted(msg.sender, quantity, true);
    }

    function mint(uint256 quantity) external payable nonReentrant {
        require(quantity > 0, "Quantity must be positive");
        require(totalPaidMinted + quantity <= paidAllocation, "Paid allocation exceeded");
        require(paidMintedByWallet[msg.sender] + quantity <= paidLimitPerWallet, "Paid wallet limit exceeded");
        require(msg.value == mintPrice * quantity, "Incorrect payment");

        totalPaidMinted += quantity;
        paidMintedByWallet[msg.sender] += quantity;

        _mintTokens(msg.sender, quantity);

        // Forward the full mint payment directly to the treasury.
        if (msg.value > 0) {
            (bool success,) = treasury.call{value: msg.value}("");
            require(success, "Treasury payment failed");

            emit TreasuryPaymentForwarded(treasury, msg.value);
        }

        emit Minted(msg.sender, quantity, false);
    }

    function _mintTokens(address recipient, uint256 quantity) internal {
        for (uint256 i = 0; i < quantity; i++) {
            _safeMint(recipient, nextTokenId);
            nextTokenId++;
        }
    }

    function totalMinted() external view returns (uint256) {
        return nextTokenId - 1;
    }

    function remainingSupply() external view returns (uint256) {
        return maxSupply - totalFreeMinted - totalPaidMinted;
    }

    // Recovery function for any BNB sent directly to the contract.
    function withdraw() external nonReentrant onlyOwner {
        uint256 amount = address(this).balance;
        require(amount > 0, "No funds");

        (bool success,) = treasury.call{value: amount}("");
        require(success, "Transfer failed");

        emit TreasuryWithdrawal(treasury, amount);
    }
}
