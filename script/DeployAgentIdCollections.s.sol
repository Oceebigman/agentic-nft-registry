// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {AgentIdCollection} from "../src/AgentIdCollection.sol";

contract DeployAgentIdCollections is Script {
    address internal constant BINANCE_AGENT_ID_REGISTRY =
        0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F;

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address treasury = vm.envAddress("TREASURY");

        vm.startBroadcast(deployerKey);

        _deploy("HARTB", "HARTB", 1000, 200, 800, 5, 0.00015 ether, treasury);
        _deploy("BLUM", "BLUM", 2000, 300, 1700, 8, 0.0001 ether, treasury);
        _deploy("PLUTO", "PLUTO", 3333, 1111, 2222, 10, 0.0003 ether, treasury);

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
        console2.log("Free allocation:", free_);
        console2.log("Paid allocation:", paid_);
        console2.log("Free limit per Agent ID: 1");
        console2.log("Paid limit per Agent ID:", paidLimit_);
        console2.log("--------------------------------");
    }
}
