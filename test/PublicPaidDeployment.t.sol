// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {DeployPublicPaidCollections} from "../script/DeployPublicPaidCollections.s.sol";
import {PublicPaidCollection} from "../src/PublicPaidCollection.sol";

contract UnpublishedAssetDeployment is DeployPublicPaidCollections {
    function _readManifest() internal pure override returns (string memory) {
        return '{"chainId":56,"assetsVerified":false}';
    }
}

contract PublicPaidDeploymentTest is Test {
    address internal constant REGISTRY = 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F;
    address payable internal constant TREASURY = payable(0x9BdC0913fD08d459BE910492cc9e6525fbd783c5);

    function testDeploymentRejectsWrongNetwork() public {
        vm.chainId(31337);
        UnpublishedAssetDeployment deployment = new UnpublishedAssetDeployment();
        vm.expectRevert(bytes("BNB Smart Chain mainnet required"));
        deployment.run(0, 2);
    }

    function testDeploymentRejectsInvalidRange() public {
        vm.chainId(56);
        UnpublishedAssetDeployment deployment = new UnpublishedAssetDeployment();
        vm.expectRevert(bytes("Invalid deployment range"));
        deployment.run(9, 2);
    }

    function testDeploymentRejectsUnavailableImagesBeforeBroadcast() public {
        vm.chainId(56);
        vm.etch(REGISTRY, hex"60006000f3");
        UnpublishedAssetDeployment deployment = new UnpublishedAssetDeployment();
        vm.expectRevert(bytes("Publish and verify all image content first"));
        deployment.run(0, 2);
    }

    function _config(string memory manifest, uint256 index)
        internal
        view
        returns (PublicPaidCollection.Config memory c)
    {
        string memory entry = string.concat(".collections[", vm.toString(index), "]");
        c = PublicPaidCollection.Config({
            name: vm.parseJsonString(manifest, string.concat(entry, ".name")),
            symbol: vm.parseJsonString(manifest, string.concat(entry, ".symbol")),
            description: vm.parseJsonString(manifest, string.concat(entry, ".description")),
            maxSupply: vm.parseJsonUint(manifest, string.concat(entry, ".maxSupply")),
            freeAllocation: vm.parseJsonUint(manifest, string.concat(entry, ".freeAllocation")),
            mintPrice: vm.parseUint(vm.parseJsonString(manifest, string.concat(entry, ".priceWei"))),
            bundleDiscountEnabled: vm.parseJsonBool(manifest, string.concat(entry, ".bundleDiscountEnabled")),
            scoutImageURI: vm.parseJsonString(manifest, string.concat(entry, ".images.scout.uri")),
            founderImageURI: vm.parseJsonString(manifest, string.concat(entry, ".images.founder.uri")),
            treasury: TREASURY,
            agentRegistry: REGISTRY
        });
    }

    function testAllTenManifestConfigurationsDeployAndMintInLocalEvm() public {
        string memory manifest = vm.readFile("launches/public-paid-v1/collections.json");
        vm.etch(REGISTRY, hex"60006000f3");
        address buyer = address(0xC0FFEE);
        vm.deal(buyer, 1 ether);
        uint256 totalSupply;
        uint256 beforeBalance = TREASURY.balance;
        uint256 paid;
        for (uint256 i; i < 10; ++i) {
            PublicPaidCollection.Config memory c = _config(manifest, i);
            PublicPaidCollection target = new PublicPaidCollection(c);
            assertEq(target.name(), c.name);
            assertEq(target.symbol(), c.symbol);
            assertEq(target.paidAllocation(), c.maxSupply - c.freeAllocation);
            uint256 value = target.quoteMint(5);
            assertEq(value, c.mintPrice * (c.bundleDiscountEnabled ? 4 : 5));
            vm.prank(buyer);
            target.mint{value: value}(5);
            assertEq(target.balanceOf(buyer), 5);
            assertTrue(target.isFounderEdition(1));
            assertEq(address(target).balance, 0);
            paid += value;
            totalSupply += c.maxSupply;
        }
        assertEq(totalSupply, 7550);
        assertEq(TREASURY.balance - beforeBalance, paid);
    }
}
