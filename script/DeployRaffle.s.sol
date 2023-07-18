// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();

        (
            uint256 entryFees,
            address vrfCoordinator,
            bytes32 gasLane,
            uint64 subId,
            uint256 minTimeInterval,
            uint32 vrfGasLimit,
            address link
        ) = helperConfig.activeConfig();

        if (subId == 0) {
            //create new subscription

            CreateSubscription createSub = new CreateSubscription();
            subId = createSub.createSubscription(vrfCoordinator);

            //fund the subscription

            FundSubscription fundSub = new FundSubscription();
            fundSub.fundSubscription(vrfCoordinator, subId, link);
        }

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            entryFees,
            vrfCoordinator,
            gasLane,
            subId,
            minTimeInterval,
            vrfGasLimit
        );
        vm.stopBroadcast();

        //add as consumer
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(vrfCoordinator, subId, address(raffle));

        return (raffle, helperConfig);
    }
}
