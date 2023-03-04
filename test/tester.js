const { expect, assert } = require("chai");
const { ethers } = require("hardhat");
const { impersonateFundErc20 } = require("../utils/utilities");

const {
  abi,
} = require("../artifacts/contracts/interfaces/IERC20.sol/IERC20.json");

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
  const BUSD = "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56";
  const CAKE = "0x0e09fabb73bd3ade0a17ecc321fd13a19e81ce82";
  const DOT = "0x55d398326f99059ff775485246999027b3197955";

  const BASE_TOKEN_ADDRESS = BUSD;

  const tokenBase = new ethers.Contract(BASE_TOKEN_ADDRESS, abi, provider);

  beforeEach(async () => {
    // Ensure that the WHALE has a balance
    const whale_balance = await provider.getBalance(BUSD_WHALE);
    expect(whale_balance).not.equal("0");

    const amountToBorrowInHuman = "1";
    BORROW_AMOUNT = ethers.utils.parseUnits(amountToBorrowInHuman, DECIMALS);
    initialFundingHuman = "10";
    FUND_AMOUNT = ethers.utils.parseUnits(initialFundingHuman, DECIMALS);
    const flashSwapFactory = await ethers.getContractFactory(
      "PancakeFlashSwap"
    );
    FLASHSWAP = await flashSwapFactory.deploy();
    await FLASHSWAP.deployed();

    await impersonateFundErc20(
      tokenBase,
      BUSD_WHALE,
      FLASHSWAP.address,
      initialFundingHuman
    );
  });

  describe("Arbitrage Execution", () => {
    it("ensures contract is funded", async () => {
      const tokenBalance = await FLASHSWAP.getFlashContractBalance(
        BASE_TOKEN_ADDRESS
      );

      const tokenBalances = await FLASHSWAP.getPairBalance(WBNB, BUSD);
      console.log(
        "CHECK THIS ",
        ethers.utils.formatUnits(tokenBalances[0], DECIMALS),
        ethers.utils.formatUnits(tokenBalances[1], DECIMALS),
        ethers.utils.formatUnits(tokenBalances[2], DECIMALS),
        ethers.utils.formatUnits(tokenBalances[3], DECIMALS),
        tokenBalances[3].toString(),

        " CHECK THIS"
      );
      const tokenBalanceInHuman = ethers.utils.formatUnits(
        tokenBalance,
        DECIMALS
      );
      expect(Number(tokenBalanceInHuman)).equal(Number(initialFundingHuman));
    });

    it("excutes an arbitrage", async () => {
      txArbitrage = await FLASHSWAP.startLoan(
        BUSD,
        WBNB,
        CAKE,
        DOT,
        BORROW_AMOUNT
      );

      const balanceAfterArbitrage = await FLASHSWAP.getFlashContractBalance(
        BASE_TOKEN_ADDRESS
      );
      const formattedAmount = ethers.utils.formatUnits(
        balanceAfterArbitrage,
        DECIMALS
      );

      const currentBalance = await FLASHSWAP.getFlashContractBalance(
        BASE_TOKEN_ADDRESS
      );

      const currentBalanceCAKE = await FLASHSWAP.getFlashContractBalance(CAKE);

      console.log("BUSD: ", ethers.utils.formatUnits(currentBalance, DECIMALS));
      console.log(
        "CAKE: ",
        ethers.utils.formatUnits(currentBalanceCAKE, DECIMALS)
      );

      assert(txArbitrage);
    });

    it("checks if a trade is profitable", async () => {
      let startTrade =
        await FLASHSWAP.checkTriangularTradeProfitabilityOnBlockCall(
          BUSD,
          CAKE,
          DOT,
          BORROW_AMOUNT
        );
      console.log("Start trade status", startTrade);
      expect(startTrade).not(undefined);
    });
  });
});
