// Layout of Contract (A guide for an organized, well structured and more readable programming):
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts@1.1.1/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts@1.1.1/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {console} from "forge-std/console.sol";    

/**
 * @title Raffle
 * @author Rubén Cruz
 * @notice This contract is for creating a sample raffle
 * @dev Implements Chainlink VRF v2.5
 */

contract  Raffle is VRFConsumerBaseV2Plus { // Inherit from VRFConsumerBaseV2Plus

    /** Errors */
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();  
    error Raffle__UpkeekNotNeeded(uint balance, uint playersLength, uint raffleState);

    /** Type Declarations */
    enum RaffleState {
        OPEN,            //0
        CALCULATING      //1
    }

    /** State Variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint private inmutable i_entranceFee;
    uint private inmutable i_interval;
    bytes32 private inmutable i_keyHash;  
    uint private inmutable i_subscriptionId;
    uint32 private inmutable i_callbackGasLimit;
    address payable[] private s_players;
    uint private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    

    /** EVents */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestRaffleWinner(uint indexed requestId);  
    
    constructor(uint entranceFee, uint interval, address vrfCoordinator, bytes32 gasLane, uint subscriptionId, uint32 callbackGasLimit) 
    VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_keyHash = gasLane;       
        i_subscriptionId = subscriptionId;  
        i_callbackGasLimit = callbackGasLimit;  

        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;   
    }

    function enterRaffle() external payable{

        console.log("HELLOOOO!")
        console.log("msg.value: ", msg.value);

        // require(msg.value >= i_entranceFee, "Not Enough ETH sent!");
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle();
        }

        if(s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }




        s_players.push(payable(msg.sender));
        /*Events are good for:
        1. Makes migrations (they make it easier)
        2. Make front end "indexing" easier*/
        emit RaffleEntered(msg.sender);
    }

    //When should the winner be picked? 
    /**
     * @dev This is the function that Chainlink node will call to see if the lottery is ready to have a winner picked
     * The following should be true in order for upkeepNeeded to be true:
     * 1. The time interval has passed between raffle runs
     * 2: The raffle is in the OPEN state
     * 3. The contract has ETH
     * 4. Implicitly, your subscription is funded with LINK
     * @param - ignored
     * @return upkeepNeeded - true if the conditions are met, false otherwise
     * @return - ignored
     */

    function checkUpkeep(bytes memory /*checkData*/) public view returns (bool upkeepNeeded, bytes memory /*performData*/) {
        bool timeHasPassed = (block.timestamp - lastTimeStamp >= i_interval); 
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0; 
        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;

        return (upkeepNeeded, "");  

    }

    /** pickWinner needs a random rumber, use it to pick a player and be automatically called */
    // Get or random number 2.5 from Chainlink
       // 1. Request a RNG
       // 2. GET a RNG  (callback function)
    function performUpkeep(bytes calldata) external {
       //check to see if enough time has passed
       (bool upkeepNeeded, ) = checkUpkeep("");
       if (!= upkeepNeeded) {
           revert Raffle__UpkeekNotNeeded(address(this).balance, s_players.length, uint(s_raffleState));
       }    
    
       s_raffleState = RaffleState.CALCULATING;
        
           VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
         });
            uint requestId = s_vrfCoordinator.requestRandomWords(request);
            emit RequestRaffleWinner(requestId);
    }
    
    //CEI: Checks, Effects, Interactions Patten
    function fulfillRandomWords(uint, /*requestId*/, uint[] calldata randomWords) internal override {


        //Checks (Input Validation: conditionals, requires...)
        
        //Effects (Internal Contract State)
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;

        //Interactions (External Contract Interactions)
        (bool success,) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }

        emit WinnerPicked(s_recentWinner);    
    }

    /** Getter functions */
    function getEntranceFee() external view returns(uint){
        return i_entranceFee;
    }

    function getRaffleState() external view returns(RaffleState){
        return s_raffleState;
    }

    function getPlayers(uint indexOfPlayer) external view returns(address){
        return s_players[indexOfPlayer];
    }   

    function getLastTimeStamp() external view returns(uint){
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns(address){
        return s_recentWinner;
    }   
}