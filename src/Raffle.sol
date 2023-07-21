// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";

/**
 * @title Raffle Contract
 * @author Pratik Mhatre
 * @notice This contract holds the functionality of a Raffle to let users participate in a lottery system by paying for a ticket; at a perticular interval a random user is picked using Chainlink VRF and all the balance is transferred to the winner.
 */

contract Raffle is VRFConsumerBaseV2, AutomationCompatibleInterface {
    event UserEnteredRaffle(address indexed userAddress, uint256 time);
    event WinnerPicked(address indexed winnerAddress, uint256 time);
    event WinnerPaid(
        address indexed winnerAddress,
        uint256 winningAmmount,
        uint256 time
    );
    event PickWinnerStarted(uint256 requestId, uint256 time);

    enum RaffleState {
        OPEN,
        CALCULATING,
        CLOSED
    }

    RaffleState s_currentRaffleState;
    uint256 private constant TICKET_PRICE = 0.001 ether;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint256 private immutable i_minTimeInterval;
    uint32 private immutable i_vrfGasLimit;

    address private s_lastWinnerDrawn;
    uint256 private s_lastWinnerDrawnTime;

    error Raffle__NotEnoughEntryFeesPaid();
    error Raffle__NoEnoughTimePassed();
    error Raffle__RewardingWinnerFailed();
    error Raffle__RaffleIsCalculating();
    error Raffle__NotEnoughPlayers();

    address payable[] private s_participants;

    constructor(
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint256 minTimeInterval,
        uint32 vrfGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_vrfGasLimit = vrfGasLimit;
        s_lastWinnerDrawnTime = block.timestamp;
        i_minTimeInterval = minTimeInterval;
        s_currentRaffleState = RaffleState.OPEN;
    }

    function enterRaffle() public payable {
        if (msg.value < TICKET_PRICE) {
            revert Raffle__NotEnoughEntryFeesPaid();
        }
        if (s_currentRaffleState != RaffleState.OPEN)
            revert Raffle__RaffleIsCalculating();

        s_participants.push(payable(msg.sender));
        emit UserEnteredRaffle(msg.sender, block.timestamp);
    }

    function payWinner(address payable winner) internal {
        emit WinnerPicked(winner, block.timestamp);
        uint256 contractBalance = address(this).balance;
        (bool isSuccess, ) = winner.call{value: contractBalance}("");
        if (!isSuccess) revert Raffle__RewardingWinnerFailed();
        emit WinnerPaid(winner, contractBalance, block.timestamp);
    }

    /**
     * @dev checkUpKeep functin returns true if :
        1. Enough interval has passed
        2. Contract has balance (participants exist)
        3. Raffle state is OPEN
        4. Subscription is funded with LINK
     * @return upkeepNeeded 
     * @return boolean
     */
    function checkUpkeep(
        bytes memory /* checkData */
    )
        public
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        bool enoughIntervalPassed = block.timestamp - s_lastWinnerDrawnTime >=
            i_minTimeInterval;
        bool hasBalance = address(this).balance > 0;
        bool isOpenState = s_currentRaffleState == RaffleState.OPEN;
        bool hasPlayers = s_participants.length > 0;

        upkeepNeeded =
            enoughIntervalPassed &&
            hasBalance &&
            hasPlayers &&
            isOpenState;
        return (upkeepNeeded, "0x0");
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        (bool upKeep, ) = checkUpkeep("");
        if (upKeep) {
            s_currentRaffleState = RaffleState.CALCULATING;

            uint256 requestId = i_vrfCoordinator.requestRandomWords(
                i_gasLane,
                i_subscriptionId,
                3,
                i_vrfGasLimit,
                1
            );
            emit PickWinnerStarted(requestId, block.timestamp);
        }
    }

    function fulfillRandomWords(
        uint256,
        uint256[] memory _randomWords
    ) internal override {
        s_currentRaffleState = RaffleState.OPEN;

        uint256 winnerIndex = _randomWords[0] % s_participants.length;
        address winnerAddress = s_participants[winnerIndex];
        s_lastWinnerDrawn = winnerAddress;
        s_lastWinnerDrawnTime = block.timestamp;
        payWinner(payable(winnerAddress));
    }

    function getLastWinner() public view returns (address) {
        return s_lastWinnerDrawn;
    }

    function getLastDrawnTime() public view returns (uint256) {
        return s_lastWinnerDrawnTime;
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_currentRaffleState;
    }

    function getParticipant(uint index) public view returns (address) {
        return s_participants[index];
    }

    function getMinInterval() public view returns (uint256) {
        return i_minTimeInterval;
    }

    function getParticipantCount() public view returns (uint256) {
        return s_participants.length;
    }
}
