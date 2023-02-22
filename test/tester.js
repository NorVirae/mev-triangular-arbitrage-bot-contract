const { expect, assert } = require("chai");
const { ethers } = require("hardhat");
const { impersonateFundErc20 } = require("../utils/utilities");

const {
  abi,
} = require("../artifacts/contracts/interfaces/IERC20.sol/IERC20.json");
const { inputToConfig } = require("@ethereum-waffle/compiler");

const provider = waffle.provider;

describe("FlashSwap Contract", () => {
  let FLASHSWAP,
    BORROW_AMOUNT,
    FUND_AMOUNT,
    initialFundingHuman,
    txArbitrage,
    gasUsedUSD;

  const DECIMALS = 18;

  const BUSD_WHALE = "0x8894e0a0c962cb723c1976a4421c95949be2d4e3";
  const WBNB = "0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c";
  const BUSD = "0xe9e7cea3dedca5984780bafc599bd69add087d56";
  const CAKE = "0x0e09fabb73bd3ade0a17ecc321fd13a19e81ce82";
  const USDT = "0x55d398326f99059ff775485246999027b3197955";
  const CROX = "0x2c094f5a7d1146bb93850f629501eb749f6ed491";

  const BASE_TOKEN_ADDRESS = BUSD;

  const tokenBase = new ethers.Contract(BASE_TOKEN_ADDRESS, abi, provider);

  beforeEach(async () => {
    // Get owner as signer
    [owner] = await ethers.getSigners();

    // Ensure that the WHALE has a balance
    const whale_balance = await provider.getBalance(BUSD_WHALE);
    expect(whale_balance).not.equal("0");

    BORROW_AMOUNT = ethers.utils.parseUnits("1", DECIMALS);

    initialFundingHuman = "100";
    FUND_AMOUNT = ethers.utils.parseUnits(initialFundingHuman, DECIMALS);
    const flashSwapFactory = await ethers.getContractFactory("PancakeFlashSwap");
    FLASHSWAP = await flashSwapFactory.deploy();
    await FLASHSWAP.deployed();

    impersonateFundErc20(
      tokenBase,
      BUSD_WHALE,
      FLASHSWAP.address,
      initialFundingHuman
    );
  });

  describe("Arbitrage Execution", () => {
    it("ensures balance was successfully transferred", async () => {
      const tokenBalance = await FLASHSWAP.getBalanceOfToken(BASE_TOKEN_ADDRESS);
      const tokenBalanceInHuman = ethers.utils.formatUnits(
        tokenBalance,
        DECIMALS
      );
      console.log(tokenBalanceInHuman);
      expect(Number(tokenBalanceInHuman)).equal(Number(initialFundingHuman));
    });
  });
});
