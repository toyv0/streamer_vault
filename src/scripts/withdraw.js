const { abi } = require("../../artifacts/src/Streamer.sol/Streamer.json");
const daiJson = require("../../artifacts/src/DAI.sol/DAI.json")
const { providers, ethers } = require("ethers");

const hello = async () => {
    const contractAddress = '0x5FbDB2315678afecb367f032d93F642f64180aa3';

    const provider = providers.getDefaultProvider('http://localhost:8545');

    const signer = new ethers.Wallet(
        '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80',
        provider,
    );

    const contract = new ethers.Contract(contractAddress, abi, signer);

    const daiAddress = '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512';

    const daicontract = new ethers.Contract(daiAddress, daiJson.abi, signer);

    await daicontract.approve(contract.address, 20);
    console.log(await daicontract.allowance(signer.address, contract.address));

    // const withdraw = await contract.withdraw(daiAddress, 1);


    // const deposit = await contract.deposit(daiAddress, 10);
}

hello();