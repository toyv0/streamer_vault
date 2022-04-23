const { providers, ethers } = require("ethers");
const { abi } = require("../../artifacts/src/DAI.sol/DAI.json");

const hello = async () => {
    const provider = providers.getDefaultProvider('http://localhost:8545');

    const signer = new ethers.Wallet(
        '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80',
        provider,
    );

    const tokenAddress = '0x0165878A594ca255338adfa4d48449f69242Eb8F';

    const contract = new ethers.Contract(tokenAddress, abi, signer);

    const mint = await contract.mint("0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266", 1000)

    console.log(mint, 'contract!!');
}

hello();