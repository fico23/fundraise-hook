## FairLaunchoor
Worlds fairest fair launch model.

## How it works?
Users call hook.createFairLaunch which then:
- deploys new token with given symbol, name and 420M total supply
- initializes token/ETH pool
- deploys 50% of total supply to one sided pool and starts the timer
- for 1 hour price is nearly constant, since all liquidity is in one narrow range
- after 1 hour, whatever ETH was raised is now put into one narrow one sided range, and remaining tokens are put into one sided wide range
- after 7 days if tokens are still not sold -> pool is cancelled and users can only sell back their bought tokens
- if all tokens are bought before 7 days mark -> liquidity is removed and new pool is initialized, where all collected ETH and other half of tokens supply is put into full range liquidity
- LP tokens are owned by hook, effectively burned