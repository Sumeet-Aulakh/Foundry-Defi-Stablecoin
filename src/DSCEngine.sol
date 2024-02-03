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

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

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
 * Our DSC System should always be "overcollateralized". At no point, should the value of the collateral <= $ backed value by DSC.
 *
 * @notice This contract is the core of the Decentralized Stablecoin system. It handles all the logic for minting and redeeming DSC, as well as depositing and withdrawing collateral.
 *
 * @notice This contract is based on MakerDAO DSS System.
 */
contract DSCEngine is ReentrancyGuard {
    /////////////////////
    //      Errors     //
    /////////////////////

    error DSCEngine__MustBeMoreThanZero();
    error DSCEngine__TokensLengthAndPriceFeedsMustBeSameLength();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__TransferFailed();
    error DSCEngine__BreaksHealthFactor(uint256 healthFactor);
    error DSCEngine__MintFailed();

    ////////////////////////
    //   State Variables  //
    ////////////////////////

    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // 200% Overcollateralized
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1;

    // Because we need to use Pricefeeds
    // mapping(address => bool) private s_tokenToAllowed;
    mapping(address token => address priceFeed) private s_priceFeeds; // token to priceFeed
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amountDscMinted) private s_DSCMinted;
    address[] private s_collateralTokens;

    DecentralizedStableCoin private immutable i_dsc;

    ////////////////////////
    //        Event       //
    ////////////////////////

    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);
    event CollateralRedeemed(address indexed user, address indexed token, uint256 indexed amount);

    /////////////////////
    //    Modifiers    //
    /////////////////////

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__MustBeMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address tokenAddress) {
        if (s_priceFeeds[tokenAddress] == address(0)) {
            revert DSCEngine__NotAllowedToken();
        }
        _;
    }

    /////////////////////
    //    Functions    //
    /////////////////////

    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscAddress) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokensLengthAndPriceFeedsMustBeSameLength();
        }
        // USD Pricefeeds
        // ETC/USD and BTC/USD
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }

        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    ////////////////////////
    // External Functions //
    ////////////////////////

    /**
     * @notice follows CEI (Checks, Effects, Interactions)
     * @param tokenCollateralAddress the address of the collateral token to deposit collateral
     * @param amountCollateral the amount of collateral to deposit
     * @param amountDscToMint the amount of DSC to mint
     * @notice they must have more collateral value than minimum threshold
     * @notice This function will deposit the collateral and mint the DSC
     */
    function depositCollateralAndMintDSC(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDSC(amountDscToMint);
    }

    /**
     * @notice follows CEI (Checks, Effects, Interactions)
     * @param tokenCollateralAddress the address of the collateral token to deposit collateral
     * @param amountCollateral the amount of collateral to deposit
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        // Checks - done in modifiers

        // Effects
        // For every state change we should emit an event
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);

        // Interactions
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function redeemCollateralForDSC(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDscToBurn)
        external
        moreThanZero(amountCollateral)
    {
        _burnDsc(amountDscToBurn, msg.sender, msg.sender);
        _redeemCollateral(tokenCollateralAddress, amountCollateral, msg.sender, msg.sender);
    }

    /**
     *
     * @notice follows CEI (Checks, Effects, Interactions)
     *
     * @param tokenCollateralAddress is the address from where the collateral is to be redeemed
     * @param amountCollateral is amount of the collateral to be redeemed
     *
     * @notice This function will redeem the collateral
     * @notice If a user tries to withdraw more than they have, the Solidity compiler will throw an error, which is highly useful for preventing any unnecessary headaches.
     */
    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        external
        nonReentrant
        moreThanZero(amountCollateral)
    {
        // Checks - done in modifiers

        // Effects
        // For every state change we should emit an event
        s_collateralDeposited[msg.sender][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(msg.sender, tokenCollateralAddress, amountCollateral);

        // Interactions
        bool success = IERC20(tokenCollateralAddress).transfer(msg.sender, amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        _revertIfHealthFactorIsBroken(msg.sender); // Internal Function
    }

    /**
     * @notice follows CEI (Checks, Effects, Interactions)
     * @param amountDscToMint the amount of DSC to mint
     * @notice they must have more collateral value than minimum threshold
     */
    function mintDSC(uint256 amountDscToMint) public moreThanZero(amountDscToMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDscToMint;
        // What if the user minted too much DSC ($140 DSC with $100 collateral)
        _revertIfHealthFactorIsBroken(msg.sender); // Internal Function
        bool minted = i_dsc.mint(msg.sender, amountDscToMint);
        if (!minted) {
            revert DSCEngine__MintFailed();
        }
    }

    function burnDSC() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}

    /////////////////////////////////////////
    // Private and Internal View Functions //
    /////////////////////////////////////////

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralDepositedInUsd)
    {
        totalDscMinted = s_DSCMinted[user];
        collateralDepositedInUsd = getAccountCollateralValueInUsd(user);
    }

    /**
     * @notice Returns how close is the user to being liquidated
     * @notice If the health factor is less than 1, then they can liquidate
     * @param user the address of the user to check the health factor
     */
    function _healthFactor(address user) private view returns (uint256) {
        // We need totalDSC minted and totalCollateral deposited
        (uint256 totalDscMinted, uint256 collateralDepositedInUsd) = _getAccountInformation(user);
        uint256 collateralAdjustedForThreshold =
            (collateralDepositedInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

    // Check health factor (do they have enough collateral?)
    // Revert if they don't
    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 healthFactor = _healthFactor(user);
        if (healthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreaksHealthFactor(healthFactor);
        }
    }

    /**
     *
     * @notice This function will burn the DSC and transfer the collateral to the user
     * @param amountToBurn amount of DSC to burn
     * @param onBehalfOf address of the user who is burning the DSC
     * @param dscFrom address from where the DSC is to be burned
     */
    function _burnDsc(uint256 amountToBurn, address onBehalfOf, address dscFrom) internal {
        s_DSCMinted[onBehalfOf] -= amountToBurn;

        bool success = i_dsc.transferFrom(dscFrom, address(this), amountToBurn);

        // This condition is hypothetically unreachable
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        i_dsc.burn(amountToBurn);
        // revertIfHealthFactorIsBroken(msg.sender); - we don't think this is ever going to hit.
    }

    /////////////////////////////////////////
    // Public and External View Functions  //
    /////////////////////////////////////////

    function getAccountCollateralValueInUsd(address user) public view returns (uint256 totalCollateralValueInUsd) {
        // Loop through each collateral token, get amount they have deposited, and map it to price to get USD value
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        // 1 ETH = $1000
        // The returned value of CL is 1000 * 1e8
        // ((1000 * 1e8 * (1e10)) * 1000 * 1e18) / 1e18
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }
}
