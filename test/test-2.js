const { expect } = require("chai");
const { ethers } = require("hardhat");

const {
  formatUnits,
  parseUnits,
  formatEther,
  parseEther,
} = require("@ethersproject/units");

describe("ERC721 Refactored - Test 2", function () {
  let owner, account1, account2, account3, state, erc721, baseURI, maxMint;

  it("Should set accounts", async function () {
    [owner, account1, account2, account3, _] = await ethers.getSigners();

    expect(await account1.getBalance()).to.equal(parseEther("10000"));
  });

  it("Should take snapshot", async function () {
    state = await hre.network.provider.request({
      method: "evm_snapshot",
    });
  });

  it("Should deploy new ERC721 contract", async function () {
    const ERC721 = await ethers.getContractFactory(
      "./contracts/ERC721.sol:ERC721"
    );

    let name = "TestToken";
    let symbol = "test";
    baseURI = "https://ipfs/test/";
    maxMint = 15;
    erc721 = await ERC721.deploy(name, symbol, baseURI, maxMint);
    await erc721.deployed();

    expect(await erc721.name()).to.equal(name);
    expect(await erc721.symbol()).to.equal(symbol);
    expect(await erc721.baseURI()).to.equal(baseURI);
  });

  it("Should NOT allow to check tokens uri if token doesn't exists", async function () {
    await expect(erc721.tokenURI("0")).to.be.reverted;
  });

  it("Should allow account1 to mint", async function () {
    let override = {
      value: parseEther("0.1"),
    };

    let mint = await erc721.connect(account1).mint(1, override);
    await mint.wait();

    expect(await erc721.balanceOf(account1.address)).to.be.equal(1);
    expect(await erc721.ownerOf("0")).to.be.equal(account1.address);
  });

  it("Should allow to check tokens uri", async function () {
    let tokenURI = await erc721.tokenURI("0");
    expect(tokenURI).to.be.equal(baseURI + "0");
  });

  it("Should allow to check totalSupply", async function () {
    let totalSupply = await erc721.totalSupply();
    expect(totalSupply).to.be.equal("1");
  });

  it("Should revert state", async function () {
    await hre.network.provider.request({
      method: "evm_revert",
      params: [state],
    });

    expect(await account1.getBalance()).to.equal(parseEther("10000"));
  });
});
