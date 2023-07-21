// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    event UserEnteredRaffle(address indexed userAddress, uint256 time);
    event WinnerPicked(address indexed winnerAddress, uint256 time);
    event WinnerPaid(
        address indexed winnerAddress,
        uint256 winningAmmount,
        uint256 time
    );
    event PickWinnerStarted(uint256 requestId, uint256 time);

    HelperConfig helperConfig;
    Raffle raffle;
    address USER = makeAddr("user");
    uint USER_BALANCE = 10 ether;
    uint constant TICKET_PRICE = 0.001 ether;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint256 minTimeInterval;
    uint32 vrfGasLimit;
    address link;
    uint256 deployerId;

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.run();
        (
            vrfCoordinator,
            gasLane,
            subscriptionId,
            minTimeInterval,
            vrfGasLimit,
            link,
            deployerId
        ) = helperConfig.activeConfig();
        vm.deal(USER, USER_BALANCE);
    }

    function testParticipantCountReturnsNumberOfParticipants() external {
        for (uint i = 1; i <= 5; i++) {
            address user = address(uint160(i));
            hoax(user, 1 ether);
            raffle.enterRaffle{value: TICKET_PRICE}();
        }
        assert(raffle.getParticipantCount() == 5);
    }

    function testRaffleIsOpen() external view {
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
        vm.roll(10);
        //start winner picking to put raffle into calculating
        raffle.performUpkeep("0x0");

        vm.expectRevert(Raffle.Raffle__RaffleIsCalculating.selector);

        //try to enter raffle while its calculating
        raffle.enterRaffle{value: TICKET_PRICE}();
    }

    //check upkeep
    function testCheckUpkeepRevertsIfNotEnoughTimePassed() external {
        raffle.enterRaffle{value: TICKET_PRICE}();
        (bool checkUpKeep, ) = raffle.checkUpkeep("");
        assert(checkUpKeep == false);
    }

    function testCheckUpkeepRevertsIfNoParticipantAvailable() external {
        vm.warp(block.timestamp + raffle.getMinInterval());
        (bool checkUpKeep, ) = raffle.checkUpkeep("");
        assert(checkUpKeep == false);
    }

    function testCheckUpkeepRevertsIfRaffleIsCalculating()
        external
        enterAndPassTime
    {
        raffle.performUpkeep("");
        (bool checkUpKeep, ) = raffle.checkUpkeep("");
        assert(checkUpKeep == false);
    }

    //PerformUpKeep
    function testPerformUpkeepFailsIfNoParticipantFound() external {
        vm.warp(block.timestamp + raffle.getMinInterval());
        raffle.performUpkeep("");
    }

    function testPerformUpkeepFailsIfNotEnoughTimePassed() external {
        raffle.enterRaffle{value: TICKET_PRICE}();
        raffle.performUpkeep("");
    }

    function testPerformUpkeepChangesStateToCalculating()
        external
        enterAndPassTime
    {
        raffle.performUpkeep("");
        assert(raffle.getRaffleState() == Raffle.RaffleState.CALCULATING);
    }

    function testPickWinnerEmitsPickWinnerEvent() external enterAndPassTime {
        vm.expectEmit(false, false, false, false);
        emit PickWinnerStarted(0, 0);
        raffle.performUpkeep("");
    }

    function testPickWinnerEmitsPickWinnerEventWithRequestId()
        external
        enterAndPassTime
    {
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[0];
        assert(uint(requestId) > 0);
    }

    //Fulfill Random Words
    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) external enterAndPassTime skipFork {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testFulfillRandomWordsChangesRaffleStateToOpen()
        external
        enterAndPassTime
        skipFork
    {
        uint256 currentUserBalance = USER.balance;

        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[0].topics[2];

        VRFCoordinatorV2Mock coord = VRFCoordinatorV2Mock(vrfCoordinator);
        coord.fulfillRandomWords(uint256(requestId), address(raffle));

        uint256 finalUserBalance = USER.balance;

        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
        assert(raffle.getLastWinner() == USER);
        assert(finalUserBalance == (currentUserBalance + TICKET_PRICE));
    }

    modifier enterAndPassTime() {
        vm.prank(USER);
        raffle.enterRaffle{value: TICKET_PRICE}();
        vm.warp(block.timestamp + raffle.getMinInterval());
        vm.roll(block.number + 100);
        _;
    }

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }
}
