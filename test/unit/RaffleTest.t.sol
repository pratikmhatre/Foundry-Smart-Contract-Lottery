// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";

contract RaffleTest is Test {
    HelperConfig helperConfig;
    Raffle raffle;
    address USER = makeAddr("user");
    uint USER_BALANCE = 10 ether;
    uint constant TICKET_PRICE = 0.001 ether;

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.run();
        vm.deal(USER, USER_BALANCE);
    }

    function testRaffleIsOpen() external {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testLessTicketPricePaidRevertsTransaction() external {
        vm.expectRevert();
        raffle.enterRaffle{value: 0.0001 ether}();
    }

    function testEnterRaffleStoresUserAddress() external {
        vm.prank(USER);
        raffle.enterRaffle{value: TICKET_PRICE}();
        assert(raffle.getParticipant(0) == USER);
    }

    function testCannotEnterWhileRaffleIsCalculating() external {
        //enter raffle first time
        raffle.enterRaffle{value: TICKET_PRICE}();
        vm.warp(block.timestamp + raffle.getMinInterval());

        //start winner picking to put raffle into calculating
        raffle.performUpkeep("0x0");

        vm.expectRevert();

        //try to enter raffle while its calculating
        raffle.enterRaffle{value: TICKET_PRICE}();
    }
}
