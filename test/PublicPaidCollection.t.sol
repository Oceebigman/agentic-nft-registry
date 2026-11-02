// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {PublicPaidCollection, IFreeClaimAgentRegistry} from "../src/PublicPaidCollection.sol";

contract FreeClaimRegistryMock is IFreeClaimAgentRegistry {
    mapping(address => string) internal handles;
    bool public unavailable;

    function setHandle(address wallet, string calldata handle) external {
        handles[wallet] = handle;
    }

    function setUnavailable(bool value) external {
        unavailable = value;
    }

    function handleOf(address wallet) external view returns (string memory) {
        require(!unavailable, "Registry offline");
        return handles[wallet];
    }
}

contract RejectingRevenueReceiver {
    receive() external payable {
        revert("Rejected");
    }
}

contract MintCallbackProbe is IERC721Receiver {
    PublicPaidCollection public collection;
    bool public reentrySucceeded;
    bool public observedFounder;
    bool public rejectTokens;

    function buy(PublicPaidCollection target, uint256 quantity, bool reject) external payable {
        collection = target;
        rejectTokens = reject;
        target.mint{value: msg.value}(quantity);
    }

    function onERC721Received(address, address, uint256 tokenId, bytes calldata) external returns (bytes4) {
        observedFounder = collection.isFounderEdition(tokenId);
        (reentrySucceeded,) =
            address(collection).call{value: collection.quoteMint(1)}(abi.encodeCall(PublicPaidCollection.mint, (1)));
        require(!rejectTokens, "Reject token");
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract PublicPaidCollectionTest is Test {
    PublicPaidCollection internal collection;
    FreeClaimRegistryMock internal registry;
    address payable internal treasury = payable(address(0xBEEF));
    address internal alice = address(0xA11CE);
    address internal secondAliceWallet = address(0xA11CF);
    address internal bob = address(0xB0B);
    address internal noId = address(0xCAFE);
    uint256 internal constant PRICE = 0.00005 ether;

    function _config() internal view returns (PublicPaidCollection.Config memory c) {
        c = PublicPaidCollection.Config({
            name: "Byte Punks",
            symbol: "BPUNK",
            description: "Original AI-created edition artwork. Founder is the paid edition; Scout is a free ID claim.",
            maxSupply: 100,
            freeAllocation: 10,
            mintPrice: PRICE,
            bundleDiscountEnabled: true,
            scoutImageURI: "ipfs://bafkreiscouttestcontent",
            founderImageURI: "ipfs://bafkreifoundertestcontent",
            treasury: treasury,
            agentRegistry: address(registry)
        });
    }

    function setUp() public {
        registry = new FreeClaimRegistryMock();
        registry.setHandle(alice, "alice.ai");
        registry.setHandle(secondAliceWallet, "alice.ai");
        registry.setHandle(bob, "bob.ai");
        collection = new PublicPaidCollection(_config());
        vm.deal(alice, 100 ether);
        vm.deal(secondAliceWallet, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(noId, 100 ether);
    }

    function testPaidMintDoesNotRequireIdOrLifetimeQuota() public {
        vm.startPrank(noId);
        collection.mint{value: collection.quoteMint(20)}(20);
        collection.mint{value: collection.quoteMint(20)}(20);
        vm.stopPrank();
        assertEq(collection.balanceOf(noId), 40);
        assertEq(collection.paidMintedByWallet(noId), 40);
    }

    function testPaidMintWorksWhenRegistryIsUnavailable() public {
        registry.setUnavailable(true);
        vm.prank(noId);
        collection.mint{value: PRICE}(1);
        assertEq(collection.ownerOf(1), noId);
    }

    function testIdHolderCanBuyBeforeAndAfterFreeClaim() public {
        vm.startPrank(alice);
        collection.mint{value: PRICE}(1);
        collection.mintFree(1);
        collection.mint{value: collection.quoteMint(20)}(20);
        vm.stopPrank();
        assertEq(collection.totalPaidMinted(), 21);
        assertEq(collection.totalFreeMinted(), 1);
        assertEq(collection.balanceOf(alice), 22);
    }

    function testFreeClaimRequiresId() public {
        vm.prank(noId);
        vm.expectRevert(PublicPaidCollection.NoAgentId.selector);
        collection.mintFree(1);
    }

    function testFreeClaimFailsClearlyWhenRegistryIsUnavailable() public {
        registry.setUnavailable(true);
        vm.prank(alice);
        vm.expectRevert(PublicPaidCollection.AgentRegistryUnavailable.selector);
        collection.mintFree(1);
    }

    function testFreeClaimSharedByIdAcrossWalletsButPaidRemainsOpen() public {
        vm.prank(alice);
        collection.mintFree(1);
        vm.startPrank(secondAliceWallet);
        vm.expectRevert(PublicPaidCollection.FreeClaimAlreadyUsed.selector);
        collection.mintFree(1);
        collection.mint{value: PRICE}(1);
        vm.stopPrank();
        assertEq(collection.balanceOf(secondAliceWallet), 1);
    }

    function testChangingHandleDoesNotResetWalletFreeClaim() public {
        vm.prank(alice);
        collection.mintFree(1);
        registry.setHandle(alice, "different.ai");
        vm.prank(alice);
        vm.expectRevert(PublicPaidCollection.FreeClaimAlreadyUsed.selector);
        collection.mintFree(1);
    }

    function testOnlyOneFreeNftMayBeRequested() public {
        vm.prank(alice);
        vm.expectRevert(PublicPaidCollection.InvalidQuantity.selector);
        collection.mintFree(2);
    }

    function testBundleQuotesForOneThreeFiveSixAndTwenty() public view {
        assertEq(collection.quoteMint(1), PRICE);
        assertEq(collection.quoteMint(3), 3 * PRICE);
        assertEq(collection.quoteMint(5), 4 * PRICE);
        assertEq(collection.quoteMint(6), 5 * PRICE);
        assertEq(collection.quoteMint(20), 16 * PRICE);
    }

    function testFlatPriceCollectionDoesNotApplyBundleDiscount() public {
        PublicPaidCollection.Config memory c = _config();
        c.bundleDiscountEnabled = false;
        PublicPaidCollection flat = new PublicPaidCollection(c);
        assertEq(flat.quoteMint(5), 5 * PRICE);
    }

    function testZeroQuantityAndOverlargeBatchRevert() public {
        vm.expectRevert(PublicPaidCollection.InvalidQuantity.selector);
        collection.quoteMint(0);
        vm.expectRevert(PublicPaidCollection.InvalidQuantity.selector);
        collection.quoteMint(21);
    }

    function testWrongPaymentDoesNotMintOrKeepFunds() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(PublicPaidCollection.IncorrectPayment.selector, PRICE, PRICE + 1));
        collection.mint{value: PRICE + 1}(1);
        assertEq(collection.totalMinted(), 0);
        assertEq(address(collection).balance, 0);
    }

    function testBundlePaymentForwardedCompletelyToTreasury() public {
        uint256 beforeBalance = treasury.balance;
        vm.prank(alice);
        collection.mint{value: 4 * PRICE}(5);
        assertEq(treasury.balance - beforeBalance, 4 * PRICE);
        assertEq(address(collection).balance, 0);
        assertEq(collection.totalPaidMinted(), 5);
        assertTrue(collection.isFounderEdition(5));
    }

    function testTreasuryRejectionRollsBackEntireBatch() public {
        PublicPaidCollection.Config memory c = _config();
        c.treasury = payable(address(new RejectingRevenueReceiver()));
        PublicPaidCollection target = new PublicPaidCollection(c);
        vm.prank(alice);
        vm.expectRevert(PublicPaidCollection.TreasuryPaymentFailed.selector);
        target.mint{value: 4 * PRICE}(5);
        assertEq(target.totalMinted(), 0);
        assertEq(target.paidMintedByWallet(alice), 0);
        assertEq(target.balanceOf(alice), 0);
        assertEq(address(target).balance, 0);
    }

    function testPaidSupplyCannotConsumeReservedFreeAllocation() public {
        vm.startPrank(alice);
        for (uint256 i; i < 4; ++i) {
            collection.mint{value: collection.quoteMint(20)}(20);
        }
        collection.mint{value: collection.quoteMint(10)}(10);
        vm.expectRevert(PublicPaidCollection.PaidAllocationExceeded.selector);
        collection.mint{value: PRICE}(1);
        collection.mintFree(1);
        vm.stopPrank();
        assertEq(collection.totalPaidMinted(), 90);
        assertEq(collection.remainingPaidSupply(), 0);
        assertEq(collection.remainingFreeSupply(), 9);
    }

    function testFreeSupplyCannotConsumePaidAllocation() public {
        PublicPaidCollection.Config memory c = _config();
        c.freeAllocation = 1;
        PublicPaidCollection target = new PublicPaidCollection(c);
        vm.prank(alice);
        target.mintFree(1);
        vm.prank(bob);
        vm.expectRevert(PublicPaidCollection.FreeAllocationExceeded.selector);
        target.mintFree(1);
        assertEq(target.remainingPaidSupply(), 99);
    }

    function testEditionPersistsAfterTransferAndFreeTokensStayScouts() public {
        vm.startPrank(alice);
        collection.mintFree(1);
        collection.mint{value: PRICE}(1);
        collection.transferFrom(alice, bob, 2);
        vm.stopPrank();
        assertEq(collection.editionOf(1), "Scout");
        assertEq(collection.editionOf(2), "Founder");
        assertTrue(collection.isFounderEdition(2));
        assertEq(collection.ownerOf(2), bob);
    }

    function testUnmintedTokenCannotClaimAnEditionOrMetadata() public {
        vm.expectRevert();
        collection.tokenURI(1);
        vm.expectRevert();
        collection.editionOf(1);
    }

    function _metadata(PublicPaidCollection target, uint256 tokenId) internal view returns (string memory) {
        bytes memory uri = bytes(target.tokenURI(tokenId));
        bytes memory alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        uint256 offset = bytes("data:application/json;base64,").length;
        uint256 length = ((uri.length - offset) / 4) * 3;
        if (uri[uri.length - 1] == "=") --length;
        if (uri[uri.length - 2] == "=") --length;
        bytes memory decoded = new bytes(length);
        uint256 buffer;
        uint256 bits;
        uint256 written;
        for (uint256 i = offset; i < uri.length && uri[i] != "="; ++i) {
            uint256 value;
            while (value < 64 && alphabet[value] != uri[i]) ++value;
            require(value < 64, "Invalid base64 metadata");
            buffer = (buffer << 6) | value;
            bits += 6;
            if (bits >= 8) {
                bits -= 8;
                decoded[written++] = bytes1(uint8(buffer >> bits));
            }
        }
        return string(decoded);
    }

    function testMetadataIsValidJsonWithEditionImageAndSerial() public {
        vm.startPrank(alice);
        collection.mintFree(1);
        collection.mint{value: PRICE}(1);
        vm.stopPrank();
        string memory scout = _metadata(collection, 1);
        string memory founder = _metadata(collection, 2);
        assertEq(vm.parseJsonString(scout, ".name"), "Byte Punks Scout #1");
        assertEq(vm.parseJsonString(scout, ".image"), collection.scoutImageURI());
        assertEq(vm.parseJsonString(founder, ".image"), collection.founderImageURI());
        assertEq(vm.parseJsonString(founder, ".attributes[0].value"), "Founder");
        assertEq(vm.parseJsonString(scout, ".attributes[0].value"), "Scout");
        assertEq(vm.parseJsonUint(founder, ".attributes[2].value"), 2);
    }

    function testMetadataEscapesQuotesBackslashesAndNewlines() public {
        PublicPaidCollection.Config memory c = _config();
        c.name = 'Byte "Punks"';
        c.description = string.concat(
            "A line",
            string(abi.encodePacked(bytes1(0x0a))),
            'A quote " and slash ',
            string(abi.encodePacked(bytes1(0x5c)))
        );
        PublicPaidCollection target = new PublicPaidCollection(c);
        vm.prank(alice);
        target.mint{value: PRICE}(1);
        string memory metadata = _metadata(target, 1);
        assertEq(vm.parseJsonString(metadata, ".description"), c.description);
        assertEq(vm.parseJsonString(metadata, ".name"), string.concat(c.name, " Founder #1"));
    }

    function testCallbackSeesEditionButCannotReenterMint() public {
        MintCallbackProbe probe = new MintCallbackProbe();
        vm.deal(address(probe), 10 ether);
        probe.buy{value: PRICE}(collection, 1, false);
        assertTrue(probe.observedFounder());
        assertFalse(probe.reentrySucceeded());
        assertEq(collection.totalMinted(), 1);
    }

    function testRejectedNftRollsBackCountersAndTreasuryPayment() public {
        MintCallbackProbe probe = new MintCallbackProbe();
        uint256 beforeBalance = treasury.balance;
        vm.expectRevert(bytes("Reject token"));
        probe.buy{value: PRICE}(collection, 1, true);
        assertEq(collection.totalMinted(), 0);
        assertEq(treasury.balance, beforeBalance);
    }

    function testOwnerCanRecoverForcedBnbOnlyToFixedTreasury() public {
        vm.deal(address(collection), 1 ether);
        uint256 beforeBalance = treasury.balance;
        collection.withdraw();
        assertEq(treasury.balance - beforeBalance, 1 ether);
        assertEq(address(collection).balance, 0);
    }

    function testNonOwnerCannotWithdraw() public {
        vm.deal(address(collection), 1 ether);
        vm.prank(alice);
        vm.expectRevert();
        collection.withdraw();
    }

    function testInvalidSupplyPriceTreasuryAndImagesAreRejected() public {
        PublicPaidCollection.Config memory c = _config();
        c.freeAllocation = c.maxSupply;
        vm.expectRevert(PublicPaidCollection.InvalidConfiguration.selector);
        new PublicPaidCollection(c);
        c = _config();
        c.mintPrice = 0;
        vm.expectRevert(PublicPaidCollection.InvalidConfiguration.selector);
        new PublicPaidCollection(c);
        c = _config();
        c.treasury = payable(address(0));
        vm.expectRevert(PublicPaidCollection.InvalidConfiguration.selector);
        new PublicPaidCollection(c);
        c = _config();
        c.founderImageURI = c.scoutImageURI;
        vm.expectRevert(PublicPaidCollection.InvalidConfiguration.selector);
        new PublicPaidCollection(c);
        c = _config();
        c.founderImageURI = "https://mutable.example/image.png";
        vm.expectRevert(PublicPaidCollection.InvalidConfiguration.selector);
        new PublicPaidCollection(c);
    }

    function testFuzzRepeatedPurchasesKeepSupplyAndRevenueConsistent(uint256 seed) public {
        uint256 totalPayment;
        uint256 totalQuantity;
        uint256 beforeBalance = treasury.balance;
        vm.startPrank(noId);
        for (uint256 i; i < 12; ++i) {
            uint256 remaining = collection.remainingPaidSupply();
            if (remaining == 0) break;
            uint256 quantity = bound(uint256(keccak256(abi.encode(seed, i))), 1, remaining < 20 ? remaining : 20);
            uint256 payment = collection.quoteMint(quantity);
            collection.mint{value: payment}(quantity);
            totalPayment += payment;
            totalQuantity += quantity;
            assertEq(collection.totalPaidMinted(), totalQuantity);
            assertEq(collection.balanceOf(noId), totalQuantity);
            assertEq(collection.remainingFreeSupply(), 10);
            assertLe(collection.totalMinted(), collection.maxSupply());
            assertEq(address(collection).balance, 0);
        }
        vm.stopPrank();
        assertEq(treasury.balance - beforeBalance, totalPayment);
    }
}
