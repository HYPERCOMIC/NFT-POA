const hre = require("hardhat");

async function main() {
    const ContractCode = await hre.ethers.getContractFactory("POANFT");
    const contractCode = await ContractCode.deploy();

    await contractCode.deployed();

    console.log("POANft deployed to : ", contractCode.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
