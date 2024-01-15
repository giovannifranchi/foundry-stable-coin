// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import {Script} from "forge-std/Script.sol";
import {StabilityCoin} from "../src/StabilityCoin.sol";

contract DeployStabilityCoin is Script {
    function run() external returns (StabilityCoin) {
        vm.startBroadcast();
        StabilityCoin stabilityCoin = new StabilityCoin();
        vm.stopBroadcast();
        return stabilityCoin;
    }
}
