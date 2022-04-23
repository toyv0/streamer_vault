// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
// const { abi, bytecode } = require("../../artifacts/src/Streamer.sol/Streamer.json")

async function main() {
    // Hardhat always runs the compile task when running scripts with its command
    // line interface.
    //
    // If this script is run directly using `node` you may want to call compile
    // manually to make sure everything is compiled
    // await hre.run('compile');

    // const provider = new ethers.getDefaultProvider('http://localhost:8545');
    // const signer = new ethers.Wallet("0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80", provider);

    // We get the contract to deploy
    // const contract = new ethers.ContractFactory(abi, bytecode, signer);

    const [deployer] = await ethers.getSigners();
    console.log("deploying with: ", deployer.address);
    const contract = await hre.ethers.getContractFactory("Streamer");
    const contracterc20 = await hre.ethers.getContractFactory("DAI");

    const account1 = "0x70997970c51812dc3a010c7d01b50e0d17dc79c8";
    const account2 = "0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc";
    const account3 = "0x90f79bf6eb2c4f870365e785982e1f101e93b906";

    const streamer = await contract.deploy(account1, account2, account3);
    const token = await contracterc20.deploy();
    await streamer.deployed();
    await token.deployed();

    console.log(token.address, 'token.address');

    console.log("Streamer deployed to:", streamer.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
