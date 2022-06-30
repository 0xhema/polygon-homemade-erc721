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
    erc721 = await ERC721.deploy(name, symbol);
    await erc721.deployed();

    // expect(await erc721.balance()).to.equal("Hello, world!");

    // const setGreetingTx = await greeter.setGreeting("Hola, mundo!");

    // wait until the transaction is mined
    // await setGreetingTx.wait();

    expect(await erc721.name()).to.equal(name);
    expect(await erc721.symbol()).to.equal(symbol);
  });

  it("Should allow owner to send to account2", async function () {
    let transfer = await erc721.transferFrom(
      owner.address,
      account2.address,
      "0"
    );
    await transfer.wait();

    expect(await erc721.balanceOf(owner.address)).to.be.equal(0);
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

  it("Should revert state", async function () {
    await hre.network.provider.request({
      method: "evm_revert",
      params: [state],
    });

    expect(await account1.getBalance()).to.equal(parseEther("10000"));
  });
});
