//SPDX-License-Identifier: MIT  
pragma solidity 0.8.19; 

import {Script} from "forge-std/Script.s.sol"; 
import {vrfCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/vrfCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";     

abstract contract CodeConstants {

    /* VRF Mock values */
    uint96 public constant MOCK_BASE_FEE = 0.25 ether; // 1e17    
    uint96 public constant MOCK_GAS_PRICE_LINK = 1e9; // 1e9
    //LINK / ETH price
    int256 public MOCK_WEI_PER_UINT_LINK = 4e15; // 1e18   

    uint public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint public constant LOCAL_CHAIN_ID = 31337;    
}

contract HelperConfig is Script{
    HelperConfig__InvalidChainId();

    struct NetworkConfig {
        uint entranceFee;
        uint interval;  
        address vrfCoordinator;
        bytes32 gasLane;
        uint32 callbackGasLimit;        
        uint subscriptionId; 
        address link;          
        address account;
    }

    NetworkConfig public localNetworkConfig;
    mapping (uint chainId => NetworkConfig) public networkConfigs;  

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
    }

    function getConfingByChainId(uint chainId) public returns (NetworkConfig memory) {
        if(networkConfigs[chainId].vrfCoordinator != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
          return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainId();

        }
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfingByChainId(block.chainId);
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfigs({
            entranceFee: 0.01 ether, //1e16
            interval: 30, //30 seconds  
            vrfCoordinator:0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B, 
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            callbackGasLimit: 500000,   
            subscriptionId: 0,
            link: ,
            account: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        //check to see if we set an active network config   
        if(localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
    }

    //Deploy mocks and such
    vm.startBroadcast();    
    vrfCoordinatorV2_5Mock vrfCoordinatorMock = new vrfCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK, MOCK_WEI_PER_UINT_LINK); 
    LinkToken linkToken = new LinkToken();   
    vm.stopBroadcast(); 

    localNetworkConfig = NetworkConfig({
         entranceFee: 0.01 ether, //1e16
        interval: 30, //30 seconds  
        vrfCoordinator: address(vrfCoordinatorMock), 
        gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
        callbackGasLimit: 500000,   
        subscriptionId: 0, 
        link: address(linkToken) 
        account: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
    return localNetworkConfig;
})
}
}