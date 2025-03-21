// SPDX-License-Identifier: MIT
pragma solidity 0.8.19; 

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/tests/Mocks/VRFCoordinatorV2_5Mock.sol";
import {CodeConstants} from "script/HelperConfig.s.sol";    

contract RaffleTest is Test {
   Raffle public raffle;   
   HelperConfig public helperConfig;

   address public PLAYER = makeAddr("player");
   uint256 public constant STARTING_BALANCE = 10 ether;

   event RaffleEntered(address indexed player);
   event WinnerPicked(address indexed winner);

   function setUp()  external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract(); 
        HelperConfig NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator; 
        gasLane = config.gasLane;
        callbackGasLimit = config.callbackGasLimit;
        subscriptionId = config.subscriptionId;
        vm.deal(PLAYER, STARTING_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view{
        assert(raffle.getRaffleStatestate() == Raffle.RaffleState.OPEN);  
    }

    function testRaffleRevertsWhenYouDontPayEnough() Public{
        //Arrange
        vm.prank(PLAYER);
        //Act / Assert
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle().selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public{
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        address playerRecorded = raffle.getPlayers(0);
        assert(playerRecorded == PLAYER);
    }

    function testEnteringRaffleEmitsEvent() public{
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);     
        vm.roll(block.number + 1);  
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

    }

    /** CHECK UPKEEP */

    function testUpkeepReturnsFalseIfItHasNoBalance() public {
        //Arrange
        vm.warp(block.timestamp + interval + 1);    
        vm.roll(block.number + 1);

        //Act 
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        //Assert
        assert(!upkeepNeeded);  

    }

    function testCheckUpkeepReturnsFalseIfRaffleIsntOpen() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval - 1);    
        vm.roll(block.number + 1);
        raffle.performUpkeep("");  

        //Act    
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        //Assert
        assert(!upkeepNeeded);
    }

//Challenge 
    //testCheckUpkeepReturnsFalseIfenoughTimeHasPassed 
    //testCheckUpkeepReturnsTrueWhenParametersAreMet    

    function testCheckUpkeepReturnsFalseIfenoughTimeHasPassed() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();   
        vm.roll(block.number + 1);
        raffle.performUpkeep("");  

        //Act    
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        //Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenParametersAreMet() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();   
        vm.warp(block.timestamp + interval + 1);    
        vm.roll(block.number + 1);
        raffle.performUpkeep("");  

        //Act    
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        //Assert
        assert(upkeepNeeded);
    }

/** Perform Upkeep */

function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
    //Arrange
    vm.prank(PLAYER);
    raffle.enterRaffle{value: entranceFee}();   
    vm.warp(block.timestamp + interval + 1);    
    vm.roll(block.number + 1);
    
    //Act / Assert
    raffle.performUpkeep("");   
}

function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
    //Arrange
   uint currentBalance = 0;
   uint numPlayers = 0;
   Raffle.RaffleState rState = raffle.getRaffleStatestate();

   vm.prank(PLAYER);
   raffle.enterRaffle{value: entranceFee}();
   currentBalance = currentBalance + entranceFee;   
   numPlayers = numPlayers + 1;

   //Act / Assert
   vm.expectRevert(
    abi.encodeWithSelector(Raffle.Raffle__UpkeekNotNeeded.selector, currentBalance, numPlayers, rState));
   raffle.performUpkeep("");    
}

modifier  raffleEntered() {
    vm.prank(PLAYER);
    raffle.enterRaffle{value: entranceFee}();   
    vm.warp(block.timestamp + interval + 1);    
    vm.roll(block.number + 1);
    _;
    
}

// What if we need to get data from emitted events in our tests?

function testPerformUpkeepUpdatesRafflestateAndEmitsRequestId() public  raffleEntered{
    
    //Act
    vm.recordLogs();
    raffle.performUpkeep("");   
    Vm.Log[] memory entries = vm.getRecordedLogs();
    bytes32 requestId = entries[1].topics[1];

    //Assert
    Raffle.RaffleState raffleState = raffle.getRaffleState();
    assert(uint(requestId) > 0);
    assert(uint(raffleState) == 1); 
}

/** Fulfill randomwords */

modifier skipFork(){
    if(block.chainid != LOCAL_CHAIN_ID){
        return;
    }
    _;
}

function testFulfillrandomwordsCanOnlyBeCalledAfterPerformUpkeep(uint randomRequestId) public raffleEntered skipFork {
    
    //Arrange / Act /Assert
    vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
    VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));  

}

function testfulfillrandomwordPicksAWinnerResetsAndSendsMoney() public raffleEntered skipFork {  
    //Arrange
    uint additionalEntrants = 3;
    uint startingIndex = 1;
    address expectedWinner = address(1);

    for (uint 1 = startingIndex; i <startingIndex + additionalEntrants; i++) {
        address newPlayer = address(uint160(i));
        hoax(newPlayer, 1 ether);  
        raffle.enterRaffle{value: entranceFee}();
    }
    uint startingTimeStamp = raffle.getLastTimeStamp(); 
    uint winnerStartingbalance = expectedWinner.balance;

    //Act
    vm.recordLogs();
    raffle.performUpkeep("");   
    Vm.Log[] memory entries = vm.getRecordedLogs();
    bytes32 requestId = entries[1].topics[1];
    VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint(requestId), address(raffle));

    //Assert
    address winner = raffle.getRecentWinner();
    Raffle.RaffleState raffleState = raffle.getRaffleState();
    uint winnerbalance = recentWinner.balance;  
    uint endingTimeStamp = raffle.getLastTimeStamp();
    uint prize = entranceFee * (additionalEntrants + 1);

    assert(recentWinner == expectedWinner);
    assert(uint(raffleState) == 0);
    assert(winnerbalance == winnerStartingbalance + prize);
    assert(endingTimeStamp > startingTimeStamp);
}

}