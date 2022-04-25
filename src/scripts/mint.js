const { providers, ethers } = require("ethers");
const { abi } = require("../../artifacts/src/DAI.sol/DAI.json");

const hello = async () => {
    const provider = providers.getDefaultProvider('http://localhost:8545');

    const signer = new ethers.Wallet(
        '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80',
        provider,
    );

    const tokenAddress = '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512';

    const contract = new ethers.Contract(tokenAddress, abi, signer);

    const mint = await contract.mint("0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266", 1000)

    console.log(mint, 'contract!!');
}

hello();