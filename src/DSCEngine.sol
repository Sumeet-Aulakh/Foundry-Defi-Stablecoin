// SPDX-License-Identifier: MIT

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

pragma solidity ^0.8.20;

/**
 * @title DSCEngine
 * @author Sumeet Singh Aulakh
 *
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg at all times.
 *
 * This is stablecoin with properties:
 * - Exogenously Collateralized
 * - Dollar Pegged
 * - Algorithmically Stable
 *
 * It is similar to DAI if DAI had no governancen, no fees, and was backed by only wETH and wBTC.
 *
 * @notice This contract is the core of the Decentralized Stablecoin system. It handles all the logic for minting and redeeming DSC, as well as depositing and withdrawing collateral.
 *
 * @notice This contract is based on MakerDAO DSS System.
 */
contract DSCEngine {
    error DSCEngine__MustBeMoreThanZero();

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__MustBeMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        // if (tokenNotAllowed) {}
        _;
    }

    /*
     * @param tokenCollateralAddress: The address of the token to be deposited as collateral.
     * @param amountCollateral: The amount of collateral to deposit.
     */
    function depositCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral
    ) external moreThanZero(amountCollateral) {}
}
