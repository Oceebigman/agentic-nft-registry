// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {PublicPaidCollection} from "../src/PublicPaidCollection.sol";

/// @notice Deploy a reviewed subset of the ten new collections. No existing NFT is changed.
/// @dev The asset builder must verify actual published image bytes before this script can run.
contract DeployPublicPaidCollections is Script {
    address public constant EXPECTED_DEPLOYER = 0xecc3B1Db6BAff284957D81f5afd5A3441dcAFAFF;
    address payable public constant EXPECTED_TREASURY = payable(0x9BdC0913fD08d459BE910492cc9e6525fbd783c5);
    address public constant EXPECTED_AGENT_REGISTRY = 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F;
    string public constant MANIFEST = "launches/public-paid-v1/collections.json";

    function run(uint256 first, uint256 count) external returns (PublicPaidCollection[] memory deployed) {
        require(block.chainid == 56, "BNB Smart Chain mainnet required");
        require(first < 10 && count > 0 && count <= 10 - first, "Invalid deployment range");
        require(EXPECTED_AGENT_REGISTRY.code.length > 0, "Agent registry has no code");
        string memory manifest = _readManifest();
        require(vm.parseJsonUint(manifest, ".chainId") == 56, "Manifest chain mismatch");
        require(vm.parseJsonBool(manifest, ".assetsVerified"), "Publish and verify all image content first");
        require(vm.parseJsonAddress(manifest, ".treasury") == EXPECTED_TREASURY, "Treasury mismatch");
        require(vm.parseJsonAddress(manifest, ".agentRegistry") == EXPECTED_AGENT_REGISTRY, "Registry mismatch");
        deployed = new PublicPaidCollection[](count);
        // Broadcast sender is explicit; dry runs do not access or expose a private key.
        vm.startBroadcast(EXPECTED_DEPLOYER);
        for (uint256 i; i < count; ++i) {
            string memory entry = string.concat(".collections[", vm.toString(first + i), "]");
            PublicPaidCollection.Config memory c = PublicPaidCollection.Config({
                name: vm.parseJsonString(manifest, string.concat(entry, ".name")),
                symbol: vm.parseJsonString(manifest, string.concat(entry, ".symbol")),
                description: vm.parseJsonString(manifest, string.concat(entry, ".description")),
                maxSupply: vm.parseJsonUint(manifest, string.concat(entry, ".maxSupply")),
                freeAllocation: vm.parseJsonUint(manifest, string.concat(entry, ".freeAllocation")),
                mintPrice: vm.parseUint(vm.parseJsonString(manifest, string.concat(entry, ".priceWei"))),
                bundleDiscountEnabled: vm.parseJsonBool(manifest, string.concat(entry, ".bundleDiscountEnabled")),
                scoutImageURI: vm.parseJsonString(manifest, string.concat(entry, ".images.scout.uri")),
                founderImageURI: vm.parseJsonString(manifest, string.concat(entry, ".images.founder.uri")),
                treasury: EXPECTED_TREASURY,
                agentRegistry: EXPECTED_AGENT_REGISTRY
            });
            PublicPaidCollection collection = new PublicPaidCollection(c);
            require(collection.owner() == EXPECTED_DEPLOYER, "Unexpected owner");
            deployed[i] = collection;
            console2.log(c.name, address(collection));
            console2.log("Base price (wei):", c.mintPrice);
            console2.log("Quote for five (wei):", collection.quoteMint(5));
        }
        vm.stopBroadcast();
    }

    function _readManifest() internal view virtual returns (string memory) {
        return vm.readFile(MANIFEST);
    }
}
