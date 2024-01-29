# What to do in Stable Coin:

1. Relative Stability: Anchored or Pegged -> $1.00
   1. Chainlink Price feed.
   2. Set a function to exchange ETH&BTC -> ~$$$
2. Stability Mechanism (Minting): Algorithmic (Decentralized)
   1. People can only mint with stablecoin with enough collateral (coded).
3. Collateral: Exogenous (Crypto)
   1. wETH (wrapped ETH i.e. ERC20 Version of ETH)
   2. wBTC (wrapped BTC i.e. ERC20 Version of BTC)

# Two Contracts:

## Decentralized Stable Coin is ERC20Burnable (is ERC20) and Ownable.

   ### Functions:

   1. constructor() ERC20() Ownable()
   2. burn(uint256 amount)
   3. mint(address to, uint256 amount) : bool

## DSCEngine

  ### Functions:

   1. depositCollateralAndMintDSC()
   2. depositCollateral()
   3. redeemCollateralForDSC()
   4. redeemCollateral()
   5. mintDSC()
   6. burnDSC()
   7. liquidate()
   8. getHealthFactor()

Set Threshold to let's say 150%
$100 worth of ETH (Collateral) <PersonA>
$50 worth of DSC (Minted) <PersonA>
Collateral should always be more than 150% of DSC i.e. $75 worth of ETH

If ETH price drops to $74
Collateral is less than Threshold
UNDERCOLLATERALIZED!!!!

```
   Someone else <PersonB> sees this.
   Pays $50 for that person <PersonA>
   Gets that person's <PersonA> all collateral.

   $0 worth of ETH (Collateral)     <PersonA>
   $0 DSC                         <PersonA>
   $50                              <PersonA>
   $74 worth of ETH (Collateral)    <PersonB>
   -$50 DSC                         <PersonB>
   +$24                             <PersonB>
```
