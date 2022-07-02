const { expect } = require("chai");
const { ethers } = require("hardhat");

const {
  formatUnits,
  parseUnits,
  formatEther,
  parseEther,
} = require("@ethersproject/units");

describe("ERC721 Refactored - Minting Gas Optimization - Test 4", function () {
  let owner, account1, account2, account3, state, erc721;

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
    expect(await erc721.maxMint()).to.equal(maxMint);
  });

  it("Should allow account1 to mint 1 token ", async function () {
    let override = {
      value: parseEther("0.1"),
    };

    let mint = await erc721.connect(account1).mint(1, override);
    let tx = await mint.wait();
    console.log("Gas Used to mint 1 token:", tx.gasUsed.toString());
    expect(await erc721.balanceOf(account1.address)).to.be.equal(1);
    expect(await erc721.ownerOf("0")).to.be.equal(account1.address);
  });

  it("Should allow account1 to mint 2 tokens ", async function () {
    let override = {
      value: parseEther("0.2"),
    };

    let mint = await erc721.connect(account1).mint(2, override);
    let tx = await mint.wait();
    console.log("Gas Used to mint 2 token:", tx.gasUsed.toString());
    expect(await erc721.balanceOf(account1.address)).to.be.equal(3);
    expect(await erc721.ownerOf("0")).to.be.equal(account1.address);
  });

  it("Should allow account1 to mint 3 tokens", async function () {
    let override = {
      value: parseEther("0.3"),
    };

    let mint = await erc721.connect(account1).mint(3, override);
    let tx = await mint.wait();
    console.log("Gas Used to mint 3 token:", tx.gasUsed.toString());
    expect(await erc721.balanceOf(account1.address)).to.be.equal(6);
    expect(await erc721.ownerOf("0")).to.be.equal(account1.address);
  });

  it("Should allow account1 to mint 4 tokens", async function () {
    let override = {
      value: parseEther("0.4"),
    };

    let mint = await erc721.connect(account1).mint(4, override);
    let tx = await mint.wait();
    console.log("Gas Used to mint 4 token:", tx.gasUsed.toString());

    expect(await erc721.balanceOf(account1.address)).to.be.equal(10);
    expect(await erc721.ownerOf("0")).to.be.equal(account1.address);
  });

  it("Should allow account1 to mint 5 tokens ", async function () {
    let override = {
      value: parseEther("0.5"),
    };

    let mint = await erc721.connect(account1).mint(5, override);
    let tx = await mint.wait();
    console.log("Gas Used to mint 5 token:", tx.gasUsed.toString());
    expect(await erc721.balanceOf(account1.address)).to.be.equal(15);
    expect(await erc721.ownerOf("0")).to.be.equal(account1.address);
  });

  it("Should revert state", async function () {
    await hre.network.provider.request({
      method: "evm_revert",
      params: [state],
    });

    expect(await account1.getBalance()).to.equal(parseEther("10000"));
  });
});
