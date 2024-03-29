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
    error STCEngine__BrokenHealthFactor(uint256 _healthFactor);
    error STCEngine__STCMintingFailed();
    error STCEngine__STCTransferFailed();
    error STCEngine__HealtyUser();

    // state variables
    uint256 private constant DECIMALS_FOR_PRICE_FEED = 10e10;
    uint256 private constant DECIMALS_PRECISION = 10e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // 200% OVERCOLLATERALIZED, it says that only 50% of the collateral is considered
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_BONUS = 10; // 10% bonus for liquidators

    StabilityCoin private immutable i_stc;
    mapping(address token => address priceFeed) private s_tokenToPriceFeed;
    mapping(address user => mapping(address token => uint256))
        private s_userToTokenToCollateral;
    mapping(address user => uint256 sbcMinted) private s_userToSBCMinted;
    address[] private s_supportedTokens;

    // events
    event STCEngine__DepositCollateral(
        address indexed _user,
        address indexed _token,
        uint256 indexed _amount
    );

    event STCEngine__STCMinted(address indexed _user, uint256 indexed _amount);

    event STCEngine__CollateralRedeemed(
        address indexed _user,
        address indexed _token,
        uint256 indexed _amount
    );

    event STCEngine__CollateralRedeemedFrom(
        address indexed _from,
        address indexed _to,
        address indexed _token,
        uint256 _amount
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
        i_stc = StabilityCoin(_stc);
    }

    /**
     * @notice deposit collateral for a specific token and mint STC
     * @param _tokenCollateral address of the collateral token
     * @param _collateralAmount amount of collateral to deposit
     * @param _STCAmount amount of STC to mint
     */
    function depositCollateralForSTC(
        address _tokenCollateral,
        uint256 _collateralAmount,
        uint256 _STCAmount
    ) external {
        depositCollateral(_collateralAmount, _tokenCollateral);
        mintSTC(_STCAmount);
    }

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
        public
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

    /**
     * @notice redeem collateral for a specific token and burn STC
     * @param _tokenCollateral address of the collateral token
     * @param _amountCollateral amount of collateral to withdraw
     * @param _amountSTC amount of STC to burn
     * @notice it already checks the health factor of the user
     */
    function redeemCollateralForSTC(
        address _tokenCollateral,
        uint256 _amountCollateral,
        uint256 _amountSTC
    ) external {
        burnSTC(_amountSTC);
        redeemCollateral(_amountCollateral, _tokenCollateral);
    }

    /**
     * @notice withdraw collateral for a specific token
     * @dev it follows the CEI pattern (check, effects, interactions)
     * @dev it is not reentrant for precaution but could be superfluos
     * @param _amount amount of collateral to withdraw
     * @param _tokenCollateral address of the collateral token
     * @dev it has to check the health factor of the user and it has to be more than 1
     */
    function redeemCollateral(
        uint256 _amount,
        address _tokenCollateral
    ) public moreThanZero(_amount) nonReentrant {
        _redeemCollateral(_tokenCollateral, _amount, msg.sender, msg.sender);
        _revertIfHelthFactorIsBroken(msg.sender);
    }

    /**
     * @notice mint STC tokens
     * @dev it follows the CEI pattern (check, effects, interactions)
     * @dev it has to check the health factor of the user
     * @dev it has to check the amount of collateral deposited
     * @param _amount amount of STC to mint
     */
    function mintSTC(uint256 _amount) public moreThanZero(_amount) {
        s_userToSBCMinted[msg.sender] += _amount;
        _revertIfHelthFactorIsBroken(msg.sender);

        bool minted = i_stc.mint(msg.sender, _amount);
        if (!minted) {
            revert STCEngine__STCMintingFailed();
        }
        emit STCEngine__STCMinted(msg.sender, _amount);
    }

    /**
     * @notice burn STC tokens
     * @dev it follows the CEI pattern (check, effects, interactions)
     * @dev it has to check the health factor of the user
     * @dev it has to check the amount of collateral deposited
     * @param _amount amount of STC to burn
     */
    function burnSTC(uint256 _amount) public moreThanZero(_amount) {
        _burnSTC(_amount, msg.sender, msg.sender);
        _revertIfHelthFactorIsBroken(msg.sender); // it shouldn't be necessary
    }

    /**
     * @notice liquidate a user
     * @param _tokenCollateral address of the collateral token
     * @param _user address of the user to liquidate
     * @param _debtToCover amount of debt to cover
     * @notice it incetives other users to liquidate the user with liquidation bonuses
     * @notice this is why overcollateralization is important 10% bonus
     */
    function liquidate(
        address _tokenCollateral,
        address _user,
        uint256 _debtToCover
    ) external moreThanZero(_debtToCover) nonReentrant {
        uint256 healthFactor = _getHealthFactor(_user);
        if (healthFactor >= MIN_HEALTH_FACTOR) {
            revert STCEngine__HealtyUser();
        }
        uint256 tokenAmountFromCoveredDebt = getTokenAmountFromUsd(
            _tokenCollateral,
            _debtToCover
        );
        uint256 bonusAmount = (tokenAmountFromCoveredDebt * LIQUIDATION_BONUS) /
            LIQUIDATION_PRECISION;
        uint256 totalAmountToLiquidate = tokenAmountFromCoveredDebt +
            bonusAmount;
        _redeemCollateral(
            _tokenCollateral,
            totalAmountToLiquidate,
            _user,
            msg.sender
        );
        _burnSTC(_debtToCover, _user, msg.sender);

        uint256 finalUserHealthFactor = _getHealthFactor(_user);

        if (finalUserHealthFactor <= healthFactor) {
            revert STCEngine__BrokenHealthFactor(finalUserHealthFactor);
        }

        _revertIfHelthFactorIsBroken(msg.sender);
    }

    // internal & private functions

    /**
     * @notice get the health factor of a user
     * @param _user address of the user
     * @return health factor of the user
     * @dev if health factor is less than 1, the user is insolvent threrefore he can be liquidated
     */
    function _getHealthFactor(address _user) private view returns (uint256) {
        (
            uint256 totalSBCMinted,
            uint256 totalCollateralDeposited
        ) = _getAccountInformation(_user);
        uint256 totalCollateralAdjustedForThreshold = (totalCollateralDeposited *
                LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        if(totalSBCMinted == 0) {
            totalSBCMinted = type(uint256).max;
        }
        uint256 healthFactor = (totalCollateralAdjustedForThreshold *
            DECIMALS_PRECISION) / totalSBCMinted;
        return healthFactor;
        // $150 eth / 100 stc = 1.5
        // 150 * 50 = 7500 / 100 = (75/100) < 1
    }

    function _revertIfHelthFactorIsBroken(address _user) private view {
        uint256 healthFactor = _getHealthFactor(_user);
        if (healthFactor < MIN_HEALTH_FACTOR) {
            revert STCEngine__BrokenHealthFactor(healthFactor);
        }
    }

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
    function _getTotalCollateralDeposited(
        address _user
    ) private view returns (uint256) {
        uint256 totalCollateralDepositedInUsd;
        for (uint256 i = 0; i < s_supportedTokens.length; i++) {
            address token = s_supportedTokens[i];
            uint256 collateralDeposited = s_userToTokenToCollateral[_user][
                token
            ];
            uint256 collateralValue = getUsdlValue(token, collateralDeposited);
            totalCollateralDepositedInUsd += collateralValue;
        }

        return totalCollateralDepositedInUsd;
    }

    function _redeemCollateral(
        address _tokenCollateralAddress,
        uint256 _amount,
        address _from,
        address _to
    ) private {
        s_userToTokenToCollateral[_from][_tokenCollateralAddress] -= _amount;
        emit STCEngine__CollateralRedeemedFrom(
            _from,
            _to,
            _tokenCollateralAddress,
            _amount
        );
        bool success = IERC20(_tokenCollateralAddress).transfer(_to, _amount);
        if (!success) {
            revert STCEngine__CollateralTransferFailed();
        }
        _revertIfHelthFactorIsBroken(msg.sender);
    }

    /**
     * @dev low-level burn function
     */
    function _burnSTC(
        uint256 _amount,
        address _onBehalfOf,
        address _stcFrom
    ) private {
        s_userToSBCMinted[_onBehalfOf] -= _amount;
        bool success = i_stc.transferFrom(_stcFrom, address(this), _amount);
        if (!success) {
            revert STCEngine__STCTransferFailed();
        }
        i_stc.burn(_amount);
        _revertIfHelthFactorIsBroken(msg.sender); // it shouldn't be necessary
    }

    // public and external view functions

    /**
     * @dev it gets price feeds from chainlink aggregator
     * @notice get the price of a token in terms of USD
     * @param _token address of the token
     * @return price of the token
     */
    function getUsdlValue(
        address _token,
        uint256 _amount
    ) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            s_tokenToPriceFeed[_token]
        );
        (, int256 price, , , ) = priceFeed.latestRoundData();

        return
            ((uint256(price) * DECIMALS_FOR_PRICE_FEED) * _amount) /
            DECIMALS_PRECISION;
    }

    function getUserToSTCMinted(address _user) external view returns (uint256) {
        return s_userToSBCMinted[_user];
    }

    function getTokenAmountFromUsd(
        address _token,
        uint256 _usdAmountInWei
    ) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            s_tokenToPriceFeed[_token]
        );
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return
            (_usdAmountInWei * DECIMALS_PRECISION) /
            (uint256(price) * DECIMALS_FOR_PRICE_FEED);
    }
}
