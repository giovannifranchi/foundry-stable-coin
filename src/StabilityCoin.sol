// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title StabilityCoin
 * @author Giovanni Franchi
 * @notice This contract is a stablecoin that is pegged to the US Dollar
 * Stabilitiy Method: Algorithmic
 * Collateral: Exogenous (wBTC, wEth)
 * This token is pegged relatively to the US Dollar (1 token = 1 USD) and uses Chainlink Oracles to determine price feeds
 * @dev This is contract is just the ERC20 implementation, all the balancing logic is delegated to StabilityCoinEngine
 */

contract StabilityCoin is ERC20Burnable, Ownable {

    error StabilityCoin__NotZeroAmount();
    error StabilityCoin__NotEnoughBalance();
    error StabilityCoin__NotZeroAddress();

    constructor() ERC20("StabilityCoin", "STC") Ownable(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266) {

    }

    function burn(uint256 _amount) public override onlyOwner {
        if (balanceOf(msg.sender) <= 0) {
            revert StabilityCoin__NotZeroAmount();
        }
        if (_amount > balanceOf(msg.sender)) {
            revert StabilityCoin__NotEnoughBalance();
        }
        super.burn(_amount);
    }

    function mint(
        address _to,
        uint256 _amount
    ) external onlyOwner returns (bool) {
        if (_amount <= 0) {
            revert StabilityCoin__NotZeroAmount();
        }
        if (_to == address(0)) {
            revert StabilityCoin__NotZeroAddress();
        }
        _mint(_to, _amount);
        return true;
    }
}
