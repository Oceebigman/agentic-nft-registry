// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AgentIdCollection, IBinanceAgentIdRegistry} from "../src/AgentIdCollection.sol";

contract MockAgentIdRegistry is IBinanceAgentIdRegistry {
    mapping(address => string) internal handles;

    function setHandle(address wallet, string calldata handle) external {
        handles[wallet] = handle;
    }

    function handleOf(address wallet) external view returns (string memory) {
        return handles[wallet];
    }
}

contract AgentIdCollectionTest is Test {
    MockAgentIdRegistry registry;
    AgentIdCollection collection;
    address payable treasury = payable(address(0xBEEF));
    address alice = address(0xA11CE);
    address aliceSecondWallet = address(0xA11CF);
    address bob = address(0xB0B);

    function setUp() public {
        registry = new MockAgentIdRegistry();
        registry.setHandle(alice, "alice.ai");
        registry.setHandle(aliceSecondWallet, "alice.ai");
        registry.setHandle(bob, "bob.ai");

        collection = new AgentIdCollection(
            "HARTB", "HARTB", 1000, 200, 800, 5, 0.00015 ether,
            treasury, address(registry)
        );
        vm.deal(alice, 10 ether);
        vm.deal(aliceSecondWallet, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function testFreeMintRequiresAgentIdAndMintsOnePerId() public {
        vm.prank(alice);
        collection.mintFree(1);
        assertEq(collection.balanceOf(alice), 1);
        assertEq(collection.totalFreeMinted(), 1);

        vm.prank(aliceSecondWallet);
        vm.expectRevert(bytes("Agent ID free limit exceeded"));
        collection.mintFree(1);
    }

    function testPaidMintRequiresAgentId() public {
        address noId = address(0xBAD);
        vm.deal(noId, 1 ether);
        vm.prank(noId);
        vm.expectRevert(bytes("No Binance Agent ID"));
        collection.mint{value: 0.00015 ether}(1);
    }

    function testPaidQuotaSharedAcrossWalletsForSameAgentId() public {
        vm.prank(alice);
        collection.mint{value: 0.00015 ether}(1);

        vm.prank(aliceSecondWallet);
        collection.mint{value: 0.0006 ether}(4);

        vm.prank(alice);
        vm.expectRevert(bytes("Agent ID paid limit exceeded"));
        collection.mint{value: 0.00015 ether}(1);

        assertEq(collection.paidMintedByAgentId(keccak256(bytes("alice.ai"))), 5);
    }

    function testDifferentAgentIdsHaveIndependentQuotas() public {
        vm.prank(alice);
        collection.mintFree(1);

        vm.prank(bob);
        collection.mintFree(1);

        assertEq(collection.totalFreeMinted(), 2);
    }

    function testPaidPaymentForwardedToTreasury() public {
        uint256 beforeBalance = treasury.balance;
        vm.prank(alice);
        collection.mint{value: 0.0003 ether}(2);
        assertEq(treasury.balance, beforeBalance + 0.0003 ether);
        assertEq(address(collection).balance, 0);
    }

    function testAgentKeyIsHandleHash() public view {
        assertEq(collection.agentKeyOf(alice), keccak256(bytes("alice.ai")));
    }
}
