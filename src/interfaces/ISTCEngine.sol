// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;


interface ISTCEngine {

    function depositCollateralForSTC() external;

    function depositCollateral() external;

    function withdrawCollateralForSTC() external;

    function withdrawCollateral() external;

    function burnSTC() external;

    function liquidate() external;

    function getHealthFactor() external view returns (uint256);

}