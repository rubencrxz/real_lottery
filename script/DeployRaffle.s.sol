//SPDX-License-Identifier: MIT  
pragma solidity 0.8.19; 

import {Script} from "forge-std/Script.s.sol";
import {Raffle} from "src/Raffle.s.sol";
import {HelperConfig} from "src/HelperConfig.s.sol";
import {CreateSubscription, FundSuscription, AddConsumer} from "script/Interactions.s.sol";    

contract DeployRaffle is Script {
    function run() public  {
        deployContract();
    }

    function deployContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        //local => deploy mocks, get local config
        //sepolia => get sepolia config 
        HelperConfig.NetworkConfig memory config = helperConfig.getNetworkConfig();

        if (config.subscriptionId == 0) {
            createSubscription createSubscription = new CreateSubscription();   
            (config.subscriptionId, config.vrfCoordinator) = createSubscription.createSubscription(config.vrfCoordinator, config.account);  

            FundSubscription fundSubscription = new FundSubscription(); 
            fundSubscription.fundSubscription(config.vrfCoordinator, config.subscriptionId, config.link, config.account);
        }
        
        vm.startBroadcast(config.account);
        Raffle raffle = new Raffle(
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.gasLane,
            config.subscriptionId,
            config.callbackGasLimit
        );
        vm.stopBroadcast(); 

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(address(raffle), config.vrfCoordinator, config.subscriptionId, config.account);  

        return (raffle, helperConfig);
    }; 

}  