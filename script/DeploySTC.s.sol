// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {StabilityCoin} from "../src/StabilityCoin.sol";
import {STCEngine} from "../src/STCEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeploySTC is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run() external returns (StabilityCoin, STCEngine, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();

        (
            address wETH,
            address wBTC,
            address wethUsdPriceFeed,
            address wbtcUsdPriceFeed,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        tokenAddresses = [wETH, wBTC];
        priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];

        vm.startBroadcast(deployerKey);
        StabilityCoin stc = new StabilityCoin();

        STCEngine stcEngine = new STCEngine(
            tokenAddresses,
            priceFeedAddresses,
            address(stc)
        );

        stc.transferOwnership(address(stcEngine));
        vm.stopBroadcast();
        return (stc, stcEngine, helperConfig);
    }
}
