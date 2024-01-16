// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import {StabilityCoin} from "./StabilityCoin.sol";

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISTCEngine} from "./interfaces/ISTCEngine.sol";

contract STCEngine is ReentrancyGuard {
    // errors
    error STCEngine__InvalidAddress(address _address);
    error STCEngine__MustBeMoreThanZero();
    error STCEngine__CollateralTransferFailed();
    error STCEngine__LenghtsNotEqual();

    // state variables
    StabilityCoin private immutable stc;
    mapping(address token => address priceFeed) private s_tokenToPriceFeed;
    mapping(address user => mapping(address token => uint256))
        private s_userToTokenToCollateral;

    // events
    event STCEngine__DepositCollateral(
        address indexed _user,
        address indexed _token,
        uint256 indexed _amount
    );

    // modifiers
    modifier moreThanZero(uint256 _amount) {
        if (_amount <= 0) {
            revert STCEngine__MustBeMoreThanZero();
        }
        _;
    }

    modifier supportedToken(address _token) {
        if (s_tokenToPriceFeed[_token] == address(0)) {
            revert STCEngine__InvalidAddress(_token);
        }
        _;
    }

    /**
    * @notice constructor
    * @param _supportedTokens array of supported tokens
    * @param _priceFeeds array of price feeds for the supported tokens
    * @param _stc address of the STC token
    * @dev lenghts of _supportedTokens and _priceFeeds must be equal
    */
    constructor(address[] memory _supportedTokens, address[] memory _priceFeeds,address _stc) {
        if(_supportedTokens.length != _priceFeeds.length){
            revert STCEngine__LenghtsNotEqual();
        }
        for(uint256 i = 0; i < _supportedTokens.length; i++){
            s_tokenToPriceFeed[_supportedTokens[i]] = _priceFeeds[i];
        }
        stc = StabilityCoin(_stc);
    }

    function depositCollateralForSTC() external {}


    /**
    * @notice deposit collateral for a specific token
    * @dev it follows the CEI pattern (check, effects, interactions)
    * @dev it is not reentrant for precaution but could be superfluos
    * @param _amountDeposited amount of collateral to deposit
    * @param _tokenCollateral address of the collateral token
    */
    function depositCollateral(
        uint256 _amountDeposited,
        address _tokenCollateral
    ) external moreThanZero(_amountDeposited) supportedToken(_tokenCollateral) nonReentrant() {
        s_userToTokenToCollateral[msg.sender][_tokenCollateral] += _amountDeposited;
        bool success = IERC20(_tokenCollateral).transferFrom(msg.sender, address(this), _amountDeposited);
        if(!success){
            revert STCEngine__CollateralTransferFailed();
        }
        emit STCEngine__DepositCollateral(msg.sender, _tokenCollateral, _amountDeposited);
    }

    function withdrawCollateralForSTC() external {}

    function withdrawCollateral() external {}

    function burnSTC() external {}

    function liquidate() external {}

    function getHealthFactor() external view returns (uint256) {}
}
