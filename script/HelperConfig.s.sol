// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract HelperConfig is Script {
    struct ActiveConfig {
        uint256 entryFees;
        address vrfCoordinator;
        bytes32 gasLane;
        uint64 subscriptionId;
        uint256 minTimeInterval;
        uint32 vrfGasLimit;
        address link;
    }

    ActiveConfig public activeConfig;

    constructor() {
        if (block.chainid == 11155111) {
            //Sepolia config
            activeConfig = getSepoliaConfig();
        } else {
            //anvil config
            activeConfig = getAnvilConfig();
        }
    }

    function getSepoliaConfig() internal pure returns (ActiveConfig memory) {
        bytes32 gasLane = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;

        address coordinatorAddress = 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625;

        return
            ActiveConfig({
                entryFees: 0.001 ether,
                vrfCoordinator: coordinatorAddress,
                gasLane: gasLane,
                subscriptionId: 1211,
                minTimeInterval: 30,
                vrfGasLimit: 100000,
                link: 0x779877A7B0D9E8603169DdbD7836e478b4624789
            });
    }

    function getAnvilConfig() internal returns (ActiveConfig memory) {
        bytes32 gasLane = 0x00;

        vm.startBroadcast();
        VRFCoordinatorV2Mock mock = new VRFCoordinatorV2Mock(1, 1);
        vm.stopBroadcast();

        address coordinatorAddress = address(mock);

        return
            ActiveConfig({
                entryFees: 0.001 ether,
                vrfCoordinator: coordinatorAddress,
                gasLane: gasLane,
                subscriptionId: 1211,
                minTimeInterval: 30,
                vrfGasLimit: 100000
            });
    }
}
