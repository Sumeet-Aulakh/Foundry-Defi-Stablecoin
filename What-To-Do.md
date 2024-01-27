What to doin Stable Coin:

1. Relative Stability: Anchored or Pegged -> $1.00
   1. Chainlink Price feed.
   2. Set a function to exchange ETH&BTC -> ~$$$
2. Stability Mechanism (Minting): Algorithmic (Decentralized)
   1. People can only mint with stablecoin with enough collateral (coded).
3. Collateral: Exogenous (Crypto)
   1. wETH (wrapped ETH i.e. ERC20 Version of ETH)
   2. wBTC (wrapped BTC i.e. ERC20 Version of BTC)

Two Contracts:

1. Decentralized Stable Coin is ERC20Burnable (is ERC20) and Ownable.

   Functions:

   1. constructor() ERC20() Ownable()
   2. burn(uint256 amount)
   3. mint(address to, uint256 amount) : bool

2. DSCEngine

   Functions:

   1. depositCollateralAndMintDSC()
   2. depositCollateral()
   3. redeemCollateralForDSC()
   4. redeemCollateral()
   5. mintDSC()
   6. burnDSC()
   7. liquidate()
   8. getHealthFactor()
