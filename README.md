# streamer_vault
A smart contract that allows a user to create an account and earn yield on deposited assets thanks to ERC4626. 
Users can whitelist accounts allowed to withdraw funds via a custom wallet as a relay mechanism. 

Deployed contract on [Kovan-Optimistic](https://kovan-optimistic.etherscan.io/address/0xc07eaa947369b0692a5e2408e5d40ef6f08e6ff5)

## Thesis
Interaction with newly created smart contracts can be scary. That's why we created stroopwallet. A smart contract wallet with disposable EOA accounts. Users can now interact with contracts with the risk of only the transaction value and not all account funds inside the smart wallet. On top of that, users earn yield on their deposited funds with the contract using ERC4626 to invest in enabled vaults. In the future, we plan to add time-based whitelist addresses, multiple yield strategies, batched transactions, and cross-network transactions.

![StroopWallet](/assets/stroopwallet.jpeg)