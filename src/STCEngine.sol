// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import {StabilityCoin} from "./StabilityCoin.sol";

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {ISTCEngine} from "./interfaces/ISTCEngine.sol";

contract STCEngine is ReentrancyGuard {
    // errors
    error STCEngine__InvalidAddress(address _address);
    error STCEngine__MustBeMoreThanZero();
    error STCEngine__CollateralTransferFailed();
    error STCEngine__LenghtsNotEqual();

    // state variables
    uint256 private constant DECIMALS_FOR_PRICE_FEED = 10e10;
    uint256 private constant DECIMALS_PRECISION = 10e18;
    StabilityCoin private immutable stc;
    mapping(address token => address priceFeed) private s_tokenToPriceFeed;
    mapping(address user => mapping(address token => uint256)) private s_userToTokenToCollateral;
    mapping(address user => uint256 sbcMinted) private s_userToSBCMinted;
    address[] private s_supportedTokens;

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
    constructor(
        address[] memory _supportedTokens,
        address[] memory _priceFeeds,
        address _stc
    ) {
        if (_supportedTokens.length != _priceFeeds.length) {
            revert STCEngine__LenghtsNotEqual();
        }
        for (uint256 i = 0; i < _supportedTokens.length; i++) {
            s_tokenToPriceFeed[_supportedTokens[i]] = _priceFeeds[i];
            s_supportedTokens.push(_supportedTokens[i]);
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
    )
        external
        moreThanZero(_amountDeposited)
        supportedToken(_tokenCollateral)
        nonReentrant
    {
        s_userToTokenToCollateral[msg.sender][
            _tokenCollateral
        ] += _amountDeposited;
        bool success = IERC20(_tokenCollateral).transferFrom(
            msg.sender,
            address(this),
            _amountDeposited
        );
        if (!success) {
            revert STCEngine__CollateralTransferFailed();
        }
        emit STCEngine__DepositCollateral(
            msg.sender,
            _tokenCollateral,
            _amountDeposited
        );
    }

    function withdrawCollateralForSTC() external {}

    function withdrawCollateral() external {}

    /**
     * @notice mint STC tokens
     * @dev it follows the CEI pattern (check, effects, interactions)
     * @dev it has to check the health factor of the user
     * @dev it has to check the amount of collateral deposited
     * @param _amount amount of STC to mint
     */
    function mintSTC(uint256 _amount) external moreThanZero(_amount) {}

    function burnSTC() external {}

    function liquidate() external {}

    function getHealthFactor() external view returns (uint256) {}

    // internal & private functions

    /**
     * @notice get the health factor of a user
     * @param _user address of the user
     * @return health factor of the user
     * @dev if health factor is less than 1, the user is insolvent threrefore he can be liquidated
     */
    function _getHealthFactor(address _user) private view returns (uint256) {}

    function _getAccountInformation(
        address _user
    )
        private
        view
        returns (uint256 totalSBCMinted, uint256 totalCollateralDeposited)
    {
        totalSBCMinted = s_userToSBCMinted[_user];
        totalCollateralDeposited = _getTotalCollateralDeposited(_user);
    }

    /**
    * @notice get the total collateral deposited by a user in terms of USD
    */
    function _getTotalCollateralDeposited(address _user)
        private
        view
        returns (uint256)
    {
        uint256 totalCollateralDeposited;
        for(uint256 i = 0; i < s_supportedTokens.length; i++){
            address token = s_supportedTokens[i];
            uint256 collateralDeposited = s_userToTokenToCollateral[_user][token];
            uint256 collateralValue = _getCollateralValue(token, collateralDeposited);
            totalCollateralDeposited += collateralValue;
        }

        return totalCollateralDeposited;
    }


    /**
     * @dev it gets price feeds from chainlink aggregator
     * @notice get the price of a token in terms of USD
     * @param _token address of the token
     * @return price of the token
     */
    function _getCollateralValue(address _token, uint256 _amount)
        private
        view
        returns (uint256)
    {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            s_tokenToPriceFeed[_token]
        );
        (, int256 price, , , ) = priceFeed.latestRoundData();

        return ((uint256(price) * DECIMALS_FOR_PRICE_FEED) * _amount) / DECIMALS_PRECISION;
    }
}
