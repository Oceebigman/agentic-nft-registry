// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AgenticCollection} from "../src/AgenticCollection.sol";

contract AgenticCollectionTest is Test {
    AgenticCollection collection;

    address owner = address(0xA11CE);
    address payable treasury = payable(address(0xBEEF));
    address alice = address(0xCAFE);
    address bob = address(0xB0B);

    function setUp() public {
        vm.prank(owner);
        collection = new AgenticCollection("Test Collection", "TEST", 10, 4, 6, 2, 3, 0.01 ether, treasury);

        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function testFreeMint() public {
        vm.prank(alice);
        collection.mintFree(2);

        assertEq(collection.balanceOf(alice), 2);
        assertEq(collection.totalFreeMinted(), 2);
        assertEq(collection.freeMintedByWallet(alice), 2);
        assertEq(collection.remainingSupply(), 8);
    }

    function testPaidMint() public {
        uint256 treasuryBefore = treasury.balance;

        vm.prank(alice);
        collection.mint{value: 0.02 ether}(2);

        assertEq(collection.balanceOf(alice), 2);
        assertEq(collection.totalPaidMinted(), 2);
        assertEq(treasury.balance, treasuryBefore + 0.02 ether);
        assertEq(address(collection).balance, 0);
    }

    function testFreeMintLimitPerWallet() public {
        vm.prank(alice);
        vm.expectRevert("Free wallet limit exceeded");
        collection.mintFree(3);
    }

    function testFreeAllocationLimit() public {
        vm.prank(alice);
        collection.mintFree(2);

        vm.prank(bob);
        collection.mintFree(2);

        address charlie = address(0x1234);
        vm.prank(charlie);
        vm.expectRevert("Free allocation exceeded");
        collection.mintFree(1);
    }

    function testPaidMintLimitPerWallet() public {
        vm.prank(alice);
        vm.expectRevert("Paid wallet limit exceeded");
        collection.mint{value: 0.04 ether}(4);
    }

    function testPaidAllocationLimit() public {
        vm.prank(alice);
        collection.mint{value: 0.03 ether}(3);

        vm.prank(bob);
        collection.mint{value: 0.03 ether}(3);

        address charlie = address(0x1234);
        vm.deal(charlie, 1 ether);
        vm.prank(charlie);
        vm.expectRevert("Paid allocation exceeded");
        collection.mint{value: 0.01 ether}(1);
    }

    function testRejectIncorrectPayment() public {
        vm.prank(alice);
        vm.expectRevert("Incorrect payment");
        collection.mint{value: 0.001 ether}(1);
    }

    function testRejectZeroQuantity() public {
        vm.prank(alice);
        vm.expectRevert("Quantity must be positive");
        collection.mintFree(0);
    }

    function testWithdrawToTreasury() public {
        // Simulate BNB accidentally or forcibly sent to the contract.
        vm.deal(address(collection), 0.01 ether);

        uint256 beforeBalance = treasury.balance;

        vm.prank(owner);
        collection.withdraw();

        assertEq(treasury.balance, beforeBalance + 0.01 ether);
        assertEq(address(collection).balance, 0);
    }

    function testRejectUnauthorizedWithdrawal() public {
        vm.prank(alice);
        vm.expectRevert();
        collection.withdraw();
    }
}
