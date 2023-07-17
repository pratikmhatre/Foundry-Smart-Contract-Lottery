// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**
 * @title Raffle Contract
 * @author Pratik Mhatre
 * @notice This contract holds the functionality of a Raffle to let users participate in a lottery system by paying for a ticket; at a perticular interval a random user is picked using Chainlink VRF and all the balance is transferred to the winner.
 */

contract Raffle is VRFConsumerBaseV2 {
    event userEnteredRaffle(address userAddress, uint256 time);
    event winnerPicked(address winnerAddress, uint256 time);
    event winnerPaid(
        address winnerAddress,
        uint256 winningAmmount,
        uint256 time
    );
    event pickWinnerStarted(uint256 requestId, uint256 time);

    enum RaffleState {
        OPEN,
        CALCULATING,
        CLOSED
    }

    RaffleState s_currentRaffleState;
    uint256 private immutable i_entryFees;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint256 private immutable i_minTimeInterval;
    uint32 private immutable i_vrfGasLimit;

    uint16 private constant REQUIRED_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    address private s_lastWinnerDrawn;
    uint256 private s_lastWinnerDrawnTime;

    error Raffle__NotEnoughEntryFeesPaid();
    error Raffle__VRF_REQUEST_FAILED();
    error Raffle__NoEnoughTimePassed();
    error Raffle__RewardingWinnerFailed();

    address payable[] private s_participants;

    constructor(
        uint256 entryFees,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint256 minTimeInterval,
        uint32 vrfGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_entryFees = entryFees;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_vrfGasLimit = vrfGasLimit;
        s_lastWinnerDrawnTime = block.timestamp;
        i_minTimeInterval = minTimeInterval;
        s_currentRaffleState = RaffleState.OPEN;
    }

    function enterRaffle() public payable {
        if (msg.value < i_entryFees) {
            revert Raffle__NotEnoughEntryFeesPaid();
        }
        if (s_currentRaffleState != RaffleState.OPEN) revert();

        s_participants.push(payable(msg.sender));
        emit userEnteredRaffle(msg.sender, block.timestamp);
    }

    function pickWinner() internal {
        //check if enough time interval has passed since last pickWinner
        if (block.timestamp - s_lastWinnerDrawnTime < i_minTimeInterval)
            revert Raffle__NoEnoughTimePassed();
        s_currentRaffleState = RaffleState.CALCULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUIRED_CONFIRMATIONS,
            i_vrfGasLimit,
            NUM_WORDS
        );
        emit pickWinnerStarted(requestId, block.timestamp);
    }

    function payWinner(address payable winner) internal {
        emit winnerPicked(winner, block.timestamp);
        uint256 contractBalance = address(this).balance;
        (bool isSuccess, ) = winner.call{value: contractBalance}("");
        if (!isSuccess) revert Raffle__RewardingWinnerFailed();
        emit winnerPaid(winner, contractBalance, block.timestamp);
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        s_currentRaffleState = RaffleState.OPEN;
        if (_randomWords.length < NUM_WORDS)
            revert Raffle__VRF_REQUEST_FAILED();
        uint256 winnerIndex = _randomWords[0] % s_participants.length;
        address winnerAddress = s_participants[winnerIndex];
        s_lastWinnerDrawn = winnerAddress;
        s_lastWinnerDrawnTime = block.timestamp;
        payWinner(payable(winnerAddress));
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
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
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
        // We don't use the checkData in this example. The checkData is defined when the Upkeep was registered.
    }

    function performUpkeep(bytes calldata /* performData */) external {
        (bool upKeep, ) = checkUpkeep("");
        if (upKeep) {
            pickWinner();
        }
    }
}
