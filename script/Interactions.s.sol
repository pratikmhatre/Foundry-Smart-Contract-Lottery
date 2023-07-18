// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {HelperConfig} from "./HelperConfig.s.sol";
import {DeployRaffle} from "../script/DeployRaffle.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {Raffle} from "../src/Raffle.sol";
import {Script} from "forge-std/Script.sol";
import {LinkToken} from "../test/mock/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

/// @title Create Subscription
/// @author Pratik
/// @dev This function is called while testing the contract on localhost to create a test subscription only
contract CreateSubscription is Script {
    function run() external returns (uint64) {
        return createSubscriptionWithConfig();
    }

    function createSubscriptionWithConfig() internal returns (uint64) {
        HelperConfig config = new HelperConfig();
        (, address vrfCoordinator, , , , , ) = config.activeConfig();
        return createSubscription(vrfCoordinator);
    }

    function createSubscription(
        address vrfCoordinator
    ) public returns (uint64) {
        VRFCoordinatorV2Mock mockCoordinator = VRFCoordinatorV2Mock(
            vrfCoordinator
        );
        vm.startBroadcast();
        uint64 subId = mockCoordinator.createSubscription();
        vm.stopBroadcast();
        return subId;
    }
}

/// @title Fund a subscription
/// @author Pratik
/// @dev The contract is called for adding funds to an already created subscription wheather on local host or on testnet.
contract FundSubscription is Script {
    uint96 constant FUNDING_AMOUNT = 3 ether;

    function run() external {
        fundSubscriptionUsingConfig();
    }

    function fundSubscriptionUsingConfig() internal {
        HelperConfig config = new HelperConfig();
        (, address vrfAddress, , uint64 subId, , , address link) = config
            .activeConfig();
        fundSubscription(vrfAddress, subId, link);
    }

    function fundSubscription(
        address vrfAddress,
        uint64 subId,
        address link
    ) public {
        if (block.chainid == 31337) {
            //anvil
            vm.startBroadcast();
            VRFCoordinatorV2Mock mockCoordinator = VRFCoordinatorV2Mock(
                vrfAddress
            );
            vm.stopBroadcast();
            mockCoordinator.fundSubscription(subId, FUNDING_AMOUNT);
        } else {
            vm.startBroadcast();
            LinkToken(link).transferAndCall(
                vrfAddress,
                FUNDING_AMOUNT,
                abi.encode(subId)
            );
            vm.stopBroadcast();
        }
    }
}

contract AddConsumer is Script {
    function run() external {
        addConsumerUsingConfig();
    }

    function addConsumerUsingConfig() internal {
        address raffle = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        HelperConfig config = new HelperConfig();
        (, address vrfAddress, , uint64 subId, , , ) = config.activeConfig();
        addConsumer(vrfAddress, subId, raffle);
    }

    function addConsumer(
        address vrfAddress,
        uint64 subId,
        address raffle
    ) public {
        if (block.chainid == 31337) {
            vm.startBroadcast();
            VRFCoordinatorV2Mock mockCoordinator = VRFCoordinatorV2Mock(
                vrfAddress
            );
            mockCoordinator.addConsumer(subId, raffle);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            VRFCoordinatorV2Interface vrfCoordinator = VRFCoordinatorV2Interface(
                    vrfAddress
                );
            vrfCoordinator.addConsumer(subId, raffle);
            vm.stopBroadcast();
        }
    }
}
