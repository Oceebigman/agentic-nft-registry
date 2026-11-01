// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {AgenticCollection} from "../src/AgenticCollection.sol";

contract DeployCollections is Script {
    struct Config {
        string name;
        string symbol;
        uint256 supply;
        uint256 freeAllocation;
        uint256 paidAllocation;
        uint256 freeLimit;
        uint256 paidLimit;
        uint256 mintPrice;
    }

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address treasury = vm.envAddress("TREASURY");
        uint256 batch = vm.envUint("BATCH");

        require(batch >= 1 && batch <= 4, "BATCH must be 1, 2, 3 or 4");

        Config[] memory configs = _configs();

        uint256 start = (batch - 1) * 5;
        uint256 end = start + 5;

        console2.log("================================");
        console2.log("AGENTIC NFT DEPLOYMENT");
        console2.log("Batch:", batch);
        console2.log("Collections:", start + 1, "to", end);
        console2.log("Treasury:", treasury);
        console2.log("================================");

        vm.startBroadcast(deployerKey);

        for (uint256 i = start; i < end; i++) {
            Config memory c = configs[i];

            AgenticCollection deployed = new AgenticCollection(
                c.name,
                c.symbol,
                c.supply,
                c.freeAllocation,
                c.paidAllocation,
                c.freeLimit,
                c.paidLimit,
                c.mintPrice,
                payable(treasury)
            );

            console2.log("Collection number:", i + 1);
            console2.log("Name:", c.name);
            console2.log("Symbol:", c.symbol);
            console2.log("Address:", address(deployed));
            console2.log("--------------------------------");
        }

        vm.stopBroadcast();

        console2.log("BATCH COMPLETE:", batch);
    }

    function _configs() internal pure returns (Config[] memory c) {
        c = new Config[](20);

        c[0] = Config("AI WIF", "AWIF", 10000, 500, 9500, 2, 50, 0.00005 ether);
        c[1] = Config("AI CATZZ", "CATZZ", 5555, 1111, 4444, 1, 5, 0.00013 ether);
        c[2] = Config("BINANCE GTV", "BGTV", 2222, 300, 1922, 2, 5, 0.0002 ether);
        c[3] = Config("AGENTIC PUNK", "PUNK", 6769, 1000, 5769, 1, 50, 0.00005 ether);
        c[4] = Config("MUMU", "MUMU", 4069, 69, 4000, 1, 15, 0.00012 ether);
        c[5] = Config("JERVENT 2.0", "JERVENT", 1000, 100, 900, 3, 10, 0.00012 ether);
        c[6] = Config("KRT", "KRT", 9999, 999, 9000, 1, 9, 0.000093 ether);
        c[7] = Config("ANTZ", "ANTZ", 7000, 1000, 6000, 2, 10, 0.0002 ether);
        c[8] = Config("KFC", "KFC", 6000, 2000, 4000, 2, 8, 0.00008 ether);
        c[9] = Config("AGENTIC PEPE", "APEPE", 8000, 3000, 5000, 2, 5, 0.00012 ether);
        c[10] = Config("HARTB", "HARTB", 1000, 200, 800, 1, 5, 0.00015 ether);
        c[11] = Config("BLUM", "BLUM", 2000, 300, 1700, 2, 8, 0.0001 ether);
        c[12] = Config("PLUTO", "PLUTO", 3333, 1111, 2222, 2, 10, 0.0003 ether);
        c[13] = Config("AUTONOMOUS APE", "AAPE", 5000, 1500, 3500, 2, 10, 0.00023 ether);
        c[14] = Config("DDG", "DDG", 10000, 500, 9500, 2, 10, 0.00009 ether);
        c[15] = Config("PLUGGINS", "PLUGGINS", 100000, 2000, 98000, 10, 100, 0.000015 ether);
        c[16] = Config("HATERZ", "HATERZ", 10000, 2000, 8000, 2, 10, 0.00012 ether);
        c[17] = Config("MAGA", "MAGA", 20000, 500, 19500, 2, 18, 0.00008 ether);
        c[18] = Config("JTSK", "JTSK", 4444, 1111, 3333, 2, 15, 0.00009 ether);
        c[19] = Config("YPPE", "YPPE", 100000, 10000, 90000, 10, 100, 0.000015 ether);
    }
}
