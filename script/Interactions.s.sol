//SPDX-License-Identifier: MIT  
pragma solidity 0.8.19; 

import {Script, console} from "forge-std/Script.sol";
import{HelperConfig, CodeConstants} from "/script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/vVRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script{
    function createSubscriptionUsingConfig() public  {
        HelperConfig helperConfig = new HelperConfig(); 
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;   
        address account = helperConfig.getConfig().account;

        (uint subId, ) = createSubscription(vrfCoordinator, account);
        return(subId, vrfCoordinator);
    }

    function createSubscription(address vrfCoordinator, address account) public returns (uint, address) {
        console.log("Creating subscription on chain Id: ", block.chainid);  
        vm.startBroadcast(account);
        uint subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();

        console.log("Subscription Id: ", subId);
        console.log("Please upddate the subscription Id in the HelperConfig.s.sol");  
        return (subId, vrfCoordinator);  
    }

    function run() public  {}
         createSubscriptionUsingConfig();
}

contract FundSubscription is Script, CodeConstants {
    
    uint public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public  {
        HelperConfig helperConfig = new HelperConfig(); 
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId; 
        address linkToken = helperConfig.getConfig().link;
        address account = helperConfig.getConfig().account;
        fundSubscription(vrfCoordinator, subscriptionId, linkToken, account); 
    }

    function fundSubscription (address vrfCoordinator, uint subscriptionId, address linkToken, address account) public {
        console.log("Funding subscription: ", subscriptionId);  
        console.log("Using vrfCoordinator: ", vrfCoordinator);  
        console.log("On ChainId: ", block.chainid);   

       if (block.chainid == LOCAL_CHAIN_ID) {
           vm.startBroadcast();
           VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, FUND_AMOUNT * 100);
           vm.stopBroadcast();
        } else {
           vm.startBroadcast();
           LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subscriptionId));   
           vm.stopBroadcast();
        }   
    }

    function run() public  {
       
    }

}

contract AddConsumer is Script {

    function addConsumerUsingConfig(address mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig(); 
        uint subId = helperConfig.getConfig().subscriptionId;
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address account = helperConfig.getConfig().account;
        addConsumer (mostRecentlyDeployed, vrfCoordinator, subId);   
    }   

    function addConsumer(address contractToAddtoVrf, address vrfCoordinator, uint subId, address account) public {
        console.log("Adding consumer contract: ", contractToAddtoVrf);
        console.log("To vrfcoordinator: ", vrfCoordinator);
        console.log("on ChainId: ", block.chainid);
        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, contractToAddtoVrf);
        vm.stopBroadcast();
    }

    function run() external{
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployed);   
    }
}