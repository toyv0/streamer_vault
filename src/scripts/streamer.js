const { abi } = require("../../artifacts/src/Streamer.sol/Streamer.json");
const daiJson = require("../../artifacts/src/DAI.sol/DAI.json")
const { providers, ethers } = require("ethers");

const hello = async () => {
    const contractAddress = '0x5fc8d32690cc91d4c39d9d3abcbd16989f875707';


    const provider = providers.getDefaultProvider('http://localhost:8545');

    const signer = new ethers.Wallet(
        '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80',
        provider,
    );

    const contract = new ethers.Contract(contractAddress, abi, signer);

    const daiAddress = '0x0165878a594ca255338adfa4d48449f69242eb8f';

    const daicontract = new ethers.Contract(daiAddress, daiJson.abi, signer);


    await daicontract.approve(contract.address, 10);

    console.log(await daicontract.allowance(signer.address, contract.address));

    const deposit = await contract.deposit(daiAddress, 10);
}

hello();