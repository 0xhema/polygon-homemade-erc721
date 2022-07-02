# HomeBrew ERC721

This is my homebrew ERC721 contract.

## Gas Efficiency

It is designed for scalable and gas-efficient using soldity-bit's bitmap libary. It also uses custom errors instead of traditional require statements for even more gas-optimzation.

The next feature of my homebrew ERC721 contract is the addition of ethereum dividends. This allows users to be able to collect dividends from the smart contract. A perfect use-case for this would be if royalties from trading volume were sent to this contract. The contract would then calculate a dividend per token that users would then be able to collect whenever they wanted by calling the `withdraw` function. There can be many different ways to collect dividends and distribute them among holder that would trully allow a holder to participate in the success of a project while the project still remains profitable.

To keep this process secure, once the public sale is completed the owner of the contract can call the `withdrawAndLock` function a single time. This constraint protects user dividends from being removed in the future.

Here are the top collections and the amount that could have been distributed to each holder if they were to use my implementation of an ERC721 token

| Rank | Collection                | Life Time Volume (in Eth) | Holder Count | Potential Rewards Per Holder at 8% Royalty (in ETH) | Project Revenue at 2% Royalty |
| ---- | ------------------------- | ------------------------- | ------------ | --------------------------------------------------- | ----------------------------- |
| 1    | CryptoPunks               | 944,426                   | 3500         | 21.58688                                            | 18888.52                      |
| 2    | Bored Ape Yacht Club      | 626587                    | 6400         | 7.8323375                                           | 12531.74                      |
| 3    | Mutant Ape Yacht Club     | 426154                    | 13100        | 2.602467176                                         | 8523.08                       |
| ...  |                           |                           |              |                                                     |                               |
| 98   | Autoglyphs                | 19930                     | 156          | 10.22051282                                         | 398.6                         |
| 99   | Imposteres Genesis Aliens | 19734                     | 5100         | 0.3095529412                                        | 394.68                        |
| 100  | Ragnarak Meta             | 19480                     | 3200         | 0.487                                               | 389.6                         |

There is also the addition of a max mint and a price for mint.

## Before Gas Optmization

| Tokens Minted | Gas Used |
| ------------- | -------- |
| 1             | 111856   |
| 2             | 274525   |
| 3             | 391794   |
| 4             | 509063   |
| 5             | 626332   |

## After Gas Optmization

| Tokens Minted | Gas Used |
| ------------- | -------- |
| 1             | 124890   |
| 2             | 79711    |
| 3             | 87662    |
| 4             | 97443    |
| 5             | 109059   |

## useful commands
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
npm deploy --network `networkName` # deploys contract and verifys contract to specified network
```

### Possible additions in the future

While this contract is unique, there are some missing features that it would need to allow it to compete with the current trends in the NFT World.

- MerkleTree Whitelist Function

  > Allow for a whitelist/allowlist mint and add an enumeration for different stages of the mint. I.E. split mint into 1k at a time to avoid gas war

- Permits to allow for zero gas approvals
- Support for ERC20 dividends

### Cool addition

- An Affilate Minting feature

  > In the spirit of a truly decentralized NFT collection incentivization would be important. You could pass on the financial incentive of community growth from project owner to holders directly using an affiliate mint feature. This would add the ability for affilate codes to generated and if someone uses the affilates code you could add to their dividen balance a percentage of the mint and offer a discount to the person who uses code or something...

### Caveats

- The dividend distribution accounts for ethereum being sent to the contract. Opensea and other exchanges can distribute royalties by sending eth but they also distribute royalties in WETH and other ERC20 tokens. <ins><b>This contract does NOT take this into account</b></ins>. The contract would need the added feature of communicating with a DEX to swap the tokens that are sent to it for ETH. 
- To burn tokens you would need to send to the DeAD address, not the zero address.
- <ins><b>This contract is not audited </b></ins> Do not use in production 
