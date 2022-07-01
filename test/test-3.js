const { expect } = require("chai");
const { ethers } = require("hardhat");

const {
  formatUnits,
  parseUnits,
  formatEther,
  parseEther,
} = require("@ethersproject/units");
const { LogDescription } = require("ethers/lib/utils");

describe("ERC721", function () {
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
    const ERC721 = await ethers.getContractFactory("ERC721");

    let name = "TestToken";
    let symbol = "test";
    baseURI = "https://ipfs/test/";
    maxMint = 5;
    erc721 = await ERC721.deploy(name, symbol, baseURI, maxMint);
    await erc721.deployed();
    console.log("ether price", parseEther("0.1"));

    expect(await erc721.name()).to.equal(name);
    expect(await erc721.symbol()).to.equal(symbol);
    expect(await erc721.baseURI()).to.equal(baseURI);
    expect(await erc721.maxMint()).to.equal(maxMint);
  });

  it("Should allow account1 to mint", async function () {
    let override = {
      value: parseEther("0.1"),
    };

    let mint = await erc721.connect(account1).mint(2, override);
    await mint.wait();

    expect(await erc721.balanceOf(account1.address)).to.be.equal(2);
    expect(await erc721.ownerOf("0")).to.be.equal(account1.address);
  });

  it("Should allow account2 to mint", async function () {
    let override = {
      value: parseEther("0.1"),
    };

    let mint = await erc721.connect(account2).mint(1, override);
    await mint.wait();

    expect(await erc721.balanceOf(account2.address)).to.be.equal(1);
    //expect(await erc721.ownerOf("1")).to.be.equal(account2.address);
  });
  it("Should load up contract", async function () {
    let val = parseEther("500");
    console.log(val);
    const params = [
      {
        from: owner.address,
        to: erc721.address,
        value: val.toHexString(),
      },
    ];
    let before = formatEther(await ethers.provider.getBalance(erc721.address));

    const transactionHash = await ethers.provider.send(
      "eth_sendTransaction",
      params
    );
    let after = formatEther(await ethers.provider.getBalance(erc721.address));

    expect(parseFloat(after)).to.be.equal(
      parseFloat(before) + parseFloat(formatEther(val))
    );
  });

  //   it("Should allow account1 to send to account2", async function () {
  //     let transfer = await erc721
  //       .connect(account1)
  //       .transferFrom(account1.address, account2.address, "0");
  //     await transfer.wait();

  //     expect(await erc721.balanceOf(account1.address)).to.be.equal(15);
  //     expect(await erc721.balanceOf(account2.address)).to.be.equal(1);
  //     expect(await erc721.ownerOf("0")).to.be.equal(account2.address);
  //   });

  it("Should show dividends", async function () {
    let balance = await ethers.provider.getBalance(account1.address);
    //let dividend = await erc721.dividendOf(account2.address);
    // let withdrawableDividendOf = await erc721.withdrawableDividendOf(
    //   account1.address
    // );
    //console.log("dividend", dividend);
    console.log("balance", balance);
    //console.log("withdrawableDividendOf", withdrawableDividendOf);
  });

  it("Should allow account 1 to claim dividends", async function () {
    let balanceBefore = formatEther(
      await ethers.provider.getBalance(account1.address)
    );
    //let dividend = await erc721.connect(account1).withdrawDividend();
    let withdrawableDividendOf = await erc721.connect(account1).withdraw();
    let balanceAfter = formatEther(
      await ethers.provider.getBalance(account1.address)
    );
    //console.log("dividend", dividend);
    console.log("balanceBefore", balanceBefore);
    console.log("balanceAfter", balanceAfter);
    let balanceContract = await ethers.provider.getBalance(erc721.address);
    console.log("balanceContract", balanceContract);

    //console.log("withdrawableDividendOf", withdrawableDividendOf);
  });

  it("Should revert state", async function () {
    await hre.network.provider.request({
      method: "evm_revert",
      params: [state],
    });

    expect(await account1.getBalance()).to.equal(parseEther("10000"));
  });
});

// it("Should allow account2 to mint ", async function () {
//     let override = {
//       value: parseEther("0.1"),
//     };
//     for (let i = 0; i < 15; i++) {
//       let mint = await erc721.connect(account1).mint(1, override);
//       await mint.wait();
//     }

//     expect(await erc721.balanceOf(account1.address)).to.be.equal(16);
//     expect(await erc721.ownerOf("15")).to.be.equal(account1.address);
//   });
