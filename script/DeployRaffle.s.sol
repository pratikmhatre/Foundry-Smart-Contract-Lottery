// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();

        (
            uint256 entryFees,
            address vrfCoordinator,
            bytes32 gasLane,
            uint64 subscriptionId,
            uint256 minTimeInterval,
            uint32 vrfGasLimit
        ) = helperConfig.activeConfig();

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            entryFees,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            minTimeInterval,
            vrfGasLimit
        );
        vm.stopBroadcast();
        return (raffle, helperConfig);
    }
}
