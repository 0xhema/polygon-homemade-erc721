const { expect } = require("chai");
const { ethers } = require("hardhat");

const {
  formatUnits,
  parseUnits,
  formatEther,
  parseEther,
} = require("@ethersproject/units");

describe("ERC721", function () {
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
    const ERC721 = await ethers.getContractFactory("ERC721");

    let name = "TestToken";
    let symbol = "test";
    baseURI = "https://ipfs/test/";
    maxMint = 5;
    erc721 = await ERC721.deploy(name, symbol, baseURI);
    await erc721.deployed();

    expect(await erc721.name()).to.equal(name);
    expect(await erc721.symbol()).to.equal(symbol);
    expect(await erc721.baseURI()).to.equal(baseURI);
    expect(await erc721.maxMint()).to.equal(maxMint);
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

  it("Should allow account1 to send to account2", async function () {
    let transfer = await erc721
      .connect(account1)
      .transferFrom(account1.address, account2.address, "0");
    await transfer.wait();

    expect(await erc721.balanceOf(account1.address)).to.be.equal(0);
    expect(await erc721.balanceOf(account2.address)).to.be.equal(1);
    expect(await erc721.ownerOf("0")).to.be.equal(account2.address);
  });

  it("Should NOT allow account1 to transfer account2's token", async function () {
    await expect(
      erc721
        .connect(account1)
        .transferFrom(account2.address, account1.address, "0")
    ).to.be.reverted;

    expect(await erc721.balanceOf(account1.address)).to.be.equal(0);
    expect(await erc721.balanceOf(account2.address)).to.be.equal(1);
    expect(await erc721.ownerOf("0")).to.be.equal(account2.address);
  });

  it("Should approve account3 to transfer account2's token", async function () {
    let approve = await erc721.connect(account2).approve(account3.address, "0");
    await approve.wait();
    expect(await erc721.getApproved("0")).to.be.equal(account3.address);
  });

  it("Should allow account3 to transfer account2's token to account1", async function () {
    let transfer = await erc721
      .connect(account3)
      .transferFrom(account2.address, account1.address, "0");

    await transfer.wait();

    expect(await erc721.balanceOf(account1.address)).to.be.equal(1);
    expect(await erc721.balanceOf(account2.address)).to.be.equal(0);
    expect(await erc721.ownerOf("0")).to.be.equal(account1.address);
  });

  it("Should NOT allow account2 to transfer account1's token to account3", async function () {
    await expect(
      erc721
        .connect(account2)
        .transferFrom(account1.address, account3.address, "0")
    ).to.be.reverted;

    expect(await erc721.balanceOf(account1.address)).to.be.equal(1);
    expect(await erc721.balanceOf(account2.address)).to.be.equal(0);
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
