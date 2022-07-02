# HomeBrew ERC721

This is my homebrew ERC721 contract. It is designed for scalable and gas-efficient minting and transfers using the power of bitmaps.

The next feature of my homebrew ERC721 contract is the addition of ethereum dividends. This allows users to be able to collect dividends from the smart contract. A perfect use-case for this would be if royalties from trading volume were sent to this contract. The contract would then calculate a dividend per token that users would then be able to collect whenever they wanted by calling the `withdraw` function. There can be many different ways to collect dividends and distribute them among holder that would trully allow a holder to participate in the success of a project while the project still remains profitable. 

To keep this process secure, once the public sale is completed the owner of the contract can call the `withdrawAndLock` function a single time. This constraint protects user dividends from being removed in the future.


| Rank | Collection                | Life Time Volume (in Eth) | Holder Count | Potential Rewards Per Holder at 8% Royalty (in ETH) | Project Revenue at 2% Royalty |
|------|---------------------------|---------------------------|--------------|-----------------------------------------------------|-------------------------------|
|    1 | CryptoPunks               |                   944,426 |         3500 |                                            21.58688 |                      18888.52 |
|    2 | Bored Ape Yacht Club      |                    626587 |         6400 |                                           7.8323375 |                      12531.74 |
|    3 | Mutant Ape Yacht Club     |                    426154 |        13100 |                                         2.602467176 |                       8523.08 |
| ...  |                           |                           |              |                                                     |                               |
|   98 | Autoglyphs                |                     19930 |          156 |                                         10.22051282 |                         398.6 |
|   99 | Imposteres Genesis Aliens |                     19734 |         5100 |                                        0.3095529412 |                        394.68 |
|  100 | Ragnarak Meta             |                     19480 |         3200 |                                               0.487 |                         389.6 |

There is also the addition of a max mint and a price for mint.

## Before Gas Optmization

Gas Used to mint 1 token: 111856
✓ Should allow account1 to mint 1 token
Gas Used to mint 2 token: 274525
✓ Should allow account1 to mint 2 tokens
Gas Used to mint 3 token: 391794
✓ Should allow account1 to mint 3 tokens
Gas Used to mint 4 token: 509063
✓ Should allow account1 to mint 4 tokens
Gas Used to mint 5 token: 626332

## After Gas Optmization

Gas Used to mint 1 token: 124890
✓ Should allow account1 to mint 1 token
Gas Used to mint 2 token: 79711
✓ Should allow account1 to mint 2 tokens
Gas Used to mint 3 token: 87662
✓ Should allow account1 to mint 3 tokens
Gas Used to mint 4 token: 97443
✓ Should allow account1 to mint 4 tokens
Gas Used to mint 5 token: 109059

```shell
npx hardhat accounts
npx hardhat compile
npx hardhat clean
npx hardhat test
npx hardhat node
node scripts/sample-script.js
npx hardhat help

or

npm test # run all tests
```
