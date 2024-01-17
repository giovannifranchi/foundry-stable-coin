// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import {Test} from "forge-std/Test.sol";
import {DeploySTC} from "../../script/DeploySTC.s.sol";
import {STCEngine} from "../../src/STCEngine.sol";
import {StabilityCoin} from "../../src/StabilityCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";


contract STCEngineTest is Test {

    DeploySTC deployer;
    HelperConfig helperConfig;
    StabilityCoin stc;
    STCEngine stcEngine;
    address ethUsdPriceFeed;
    address wbtcUsdPriceFeed;
    address wEth;
    address wBtc;
    address public user = makeAddr("USER");

    function setUp() external {
        deployer = new DeploySTC();
        (stc, stcEngine, helperConfig) = deployer.run();
        (wEth, wBtc,ethUsdPriceFeed, wbtcUsdPriceFeed, ) = helperConfig.activeNetworkConfig();
        ERC20Mock(wEth).mint(user, 10 ether);
    }

    // price test

    function testEthUsdPriceFeed() external {
        uint256 amount = 15e18;
        uint256 expectedUsdPrice = 30000e18;
        uint256 actualUsdPrice = stcEngine.getUsdlValue(wEth, amount);
        assertEq(actualUsdPrice, expectedUsdPrice);
    }

    function testBtcUsdPriceFeed() external {
        uint256 amount = 10e18;
        uint256 expectedUsdPrice = 500_000e18;
        uint256 actualUsdPrice = stcEngine.getUsdlValue(wBtc, amount);
        assertEq(actualUsdPrice, expectedUsdPrice);
    }

    // deposit collateral test

    function testDepositCollateral() external {

        vm.startPrank(user);
        ERC20Mock(wEth).approve(address(stcEngine), 10 ether);
        stcEngine.depositCollateral(3 ether, wEth);
        stcEngine.mintSTC(1 ether);
        assertEq(stcEngine.getUserToSTCMinted(user), 1 ether);

    }

}