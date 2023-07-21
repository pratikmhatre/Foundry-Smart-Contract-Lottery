// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mock/LinkToken.sol";

contract HelperConfig is Script {
    struct ActiveConfig {
        address vrfCoordinator;
        bytes32 gasLane;
        uint64 subscriptionId;
        uint256 minTimeInterval;
        uint32 vrfGasLimit;
        address link;
        uint256 deployerKey;
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

    function getSepoliaConfig() internal view returns (ActiveConfig memory) {
        bytes32 gasLane = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;

        address coordinatorAddress = 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625;

        return
            ActiveConfig({
                vrfCoordinator: coordinatorAddress,
                gasLane: gasLane,
                subscriptionId: 3671,
                minTimeInterval: 30,
                vrfGasLimit: 100000,
                link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
                deployerKey: uint256(vm.envUint("TESTNET_PRIVATE_KEY"))
            });
    }

    function getAnvilConfig() internal returns (ActiveConfig memory) {
        if (activeConfig.vrfCoordinator != address(0)) return activeConfig;

        bytes32 gasLane = 0x00;
        vm.startBroadcast();
        VRFCoordinatorV2Mock mock = new VRFCoordinatorV2Mock(1, 1);
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        address coordinatorAddress = address(mock);

        return
            ActiveConfig({
                vrfCoordinator: coordinatorAddress,
                gasLane: gasLane,
                subscriptionId: 0,
                minTimeInterval: 30,
                vrfGasLimit: 100000,
                link: address(linkToken),
                deployerKey: uint256(
                    0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
                )
            });
    }
}
