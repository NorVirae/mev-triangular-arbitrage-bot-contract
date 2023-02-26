# MEV TRIANGULAR ARBITRAGE BOT - [Smart contract part]

To run this project

1. git clone ```https://github.com/NorVirae/mev-triangular-arbitrage-bot-contract.git```
2. run ```npm install```
3. run ```npx hardhat test```, to see project execute on a fork of mainnet
4. run ```npx hardhat run scripts/deploy.js --network [network_name]```, Network Name from "hardhat.config"
5. you can hook up the smart contract interface with a nodejs, python django/flask server(bot), to call the interfaces to perform arbitrage on block change.
