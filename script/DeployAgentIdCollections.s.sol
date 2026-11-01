// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {AgentIdCollection} from "../src/AgentIdCollection.sol";

/// @notice Deploys only the seven pending Agent ID collections.
/// Existing HARTB, BLUM, and PLUTO deployments are intentionally excluded.
contract DeployAgentIdCollections is Script {
    address internal constant BINANCE_AGENT_ID_REGISTRY =
        0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F;

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address treasury = vm.envAddress("TREASURY");

        vm.startBroadcast(deployerKey);

        _deploy("AUTONOMOUS APE", "AAPE", 5000, 1500, 3500, 10, 0.00023 ether, treasury);
        _deploy("DDG", "DDG", 10000, 500, 9500, 10, 0.00009 ether, treasury);
        _deploy("PLUGGINS", "PLUGGINS", 100000, 2000, 98000, 100, 0.000015 ether, treasury);
        _deploy("HATERZ", "HATERZ", 10000, 2000, 8000, 10, 0.00012 ether, treasury);
        _deploy("MAGA", "MAGA", 20000, 500, 19500, 18, 0.00008 ether, treasury);
        _deploy("JTSK", "JTSK", 4444, 1111, 3333, 15, 0.00009 ether, treasury);
        _deploy("YPPE", "YPPE", 100000, 10000, 90000, 100, 0.000015 ether, treasury);

        vm.stopBroadcast();
    }

    function _deploy(
        string memory name_,
        string memory symbol_,
        uint256 supply_,
        uint256 free_,
        uint256 paid_,
        uint256 paidLimit_,
        uint256 price_,
        address treasury_
    ) internal {
        AgentIdCollection deployed = new AgentIdCollection(
            name_, symbol_, supply_, free_, paid_, paidLimit_, price_,
            payable(treasury_), BINANCE_AGENT_ID_REGISTRY
        );

        console2.log("Collection:", name_);
        console2.log("Symbol:", symbol_);
        console2.log("Contract:", address(deployed));
        console2.log("Max supply:", supply_);
        console2.log("Free allocation:", free_);
        console2.log("Paid allocation:", paid_);
        console2.log("Free limit per Agent ID: 1");
        console2.log("Paid limit per Agent ID:", paidLimit_);
        console2.log("Mint price (wei):", price_);
        console2.log("--------------------------------");
    }
}
