// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import {Script} from "forge-std/Script.sol";

import {StabilityCoin} from "../src/StabilityCoin.sol";

import {STCEngine} from "../src/STCEngine.sol";

import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "../test/mocks/ERC20Mock.sol";

contract HelperConfig is Script {
    
    struct NetworkConfig {
        address wETH;
        address wBTC;
        address wethUsdPriceFeed;
        address wbtcUsdPriceFeed;
        uint256 deployerKey;
    }

    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 50000e8;
    uint256 public constant DEFAULT_ANVIL_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    NetworkConfig public activeNetworkConfig;

    constructor(){
        if(block.chainid == 11155111){
            activeNetworkConfig = getSepoliaConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilConfig();
        }
    }


    function getSepoliaConfig() public view returns(NetworkConfig memory) {
        return NetworkConfig({
            wETH: 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9,
            wBTC: 0x92f3B59a79bFf5dc60c0d59eA13a44D082B2bdFC,
            wethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            wbtcUsdPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilConfig() public returns(NetworkConfig memory) {

        if(activeNetworkConfig.wBTC != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();

        MockV3Aggregator wethUsdPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);

        ERC20Mock wETH = new ERC20Mock("Wrapped Ether", "WETH", msg.sender, 1000e8);

        MockV3Aggregator wbtcUsdPriceFeed = new MockV3Aggregator(DECIMALS, BTC_USD_PRICE);

        ERC20Mock wBTC = new ERC20Mock("Wrapped Bitcoin", "WBTC", msg.sender, 1000e8);

        vm.stopBroadcast();


        return NetworkConfig({
            wETH: address(wETH),
            wBTC: address(wBTC),
            wethUsdPriceFeed: address(wethUsdPriceFeed),
            wbtcUsdPriceFeed: address(wbtcUsdPriceFeed),
            deployerKey: DEFAULT_ANVIL_KEY
        });
    }


}