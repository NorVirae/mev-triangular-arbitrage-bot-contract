// SPDX-License-Identifier: MIT
pragma solidity >=0.6.6;
import "hardhat/console.sol";

// import libraries and interfaces
import "./libraries/SafeERC20.sol";
import "./libraries/SafeMath.sol";

import "./libraries/UniswapV2Library.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Router01.sol";
import "./interfaces/IUniswapV2Router02.sol";

contract PancakeFlashSwap {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    // factory and router  contract addresses
    address private constant PANCAKEV2_FACTORY =
        0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;
    address private constant PANCAKEV2_ROUTER =
        0x10ED43C718714eb63d5aA57B78B54704E256024E;

    // set Deadline
    uint256 private deadline = block.timestamp + 20 minutes;
    uint256 private constant MAX_INT =
        115792089237316195423570985008687907853269984665640564039457584007913129639935;

    // Fund smart contract
    // function allows smart contract to be funded

    function fundFlashContract(
        address _owner,
        address _token,
        uint256 _amount
    ) public {
        IERC20(_token).transferFrom(_owner, address(this), _amount);
    }

    // get balance of token on contract
    function getFlashContractBalance(address _token)
        public
        view
        returns (uint256)
    {
        return IERC20(_token).balanceOf(address(this));
    }

    // place trade function
    function placeTrade(
        address _fromToken,
        address _toToken,
        uint256 _amountIn
    ) private returns (uint256) {
        // make sure pair exist so to not waste gas
        address pair = IUniswapV2Factory(PANCAKEV2_FACTORY).getPair(
            _fromToken,
            _toToken
        );
        require(pair != address(0), "There is no Liquidity");
        address[] memory path = new address[](2);
        path[0] = _fromToken;
        path[1] = _toToken;
        uint256 amountsOutMin = IUniswapV2Router01(PANCAKEV2_ROUTER)
            .getAmountsOut(_amountIn, path)[1];
        console.log("amounts required %s", amountsOutMin);

        uint256 amountsReceived = IUniswapV2Router01(PANCAKEV2_ROUTER)
            .swapExactTokensForTokens(
                _amountIn,
                amountsOutMin,
                path,
                address(this),
                deadline
            )[1];
        console.log("amounts received %s", amountsReceived);
        require(amountsReceived > 0, "Aborted Tx: Trade returned 0");
        return amountsReceived;
    }

    // Get pair balance
    function getPairBalance(address _token0, address _token1)
        public
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        address pair = IUniswapV2Factory(PANCAKEV2_FACTORY).getPair(_token0, _token1);

        uint256 balance0 = IERC20(_token0).balanceOf(
            IUniswapV2Pair(pair).token0()
        );
        uint256 balance1 = IERC20(_token1).balanceOf(
            IUniswapV2Pair(pair).token1()
        );
        uint256 balance2 = IERC20(_token0).balanceOf(address(pair));
        uint256 balance3 = IERC20(_token0).balanceOf(address(this));
        // console.log("balance0: %s, balance1: %s, balance2: %s, balance3: %s", balance0, balance1, balance2, balance3);
        return (balance0, balance1, balance2, balance3);
    }

    // checks trade profitabilty in order of token provided
    function checkTriangularTradeProfitabilityOnBlockCall(
        address _tradeToken1,
        address _tradeToken2,
        address _tradeToken3,
        uint256 _amount
    ) external view returns (bool) {
        address[] memory tPath1 = new address[](2);
        address memory tPath2 = new address[](2);
        address memory tPath3 = new address[](2);
        bool startTrade = false;

        // Trade 1 path
        tPath1[0] = _tradeToken1;
        tPath1[1] = _tradeToken2;

        // Trade 2 path
        tPath2[0] = _tradeToken2;
        tPath2[1] = _tradeToken3;

        // Trade 3 path
        tPath3[0] = _tradeToken3;
        tPath3[1] = _tradeToken1;

        // get possible trade result of first swap
        uint256 trade1PossibleOutcomeAmount = IUniswapV2Router01(
            PANCAKEV2_ROUTER
        ).getAmountsOut(_amount, tPath1)[1];

        // get posssible result of second swap
        uint256 trade2PossibleOutcomeAmount = IUniswapV2Router01(
            PANCAKEV2_ROUTER
        ).getAmountsOut(trade1PossibleOutcomeAmount, tPath2)[1];

        // get possible resultant amount  of 3rd swap
        uint256 trade3PossibleOutcomeAmount = IUniswapV2Router01(
            PANCAKEV2_ROUTER
        ).getAmountsOut(trade2PossibleOutcomeAmount, tPath3)[1];

        // fee to pay back for loan
        uint256 fee = ((_amount * 3) / 997) + 1;

        // amount to repay
        uint256 amountToRepay = _amount.add(fee);

        // check resultant amount is greater than payback amount
        if (trade3PossibleOutcomeAmount > amountToRepay) {
            startTrade = true;
        }
        return startTrade;
    }

    // Check profitablity
    function checkProfitability(uint256 input, uint256 output)
        public
        pure
        returns (bool)
    {
        bool isOutputBigger = output > input ? true : false;
        return isOutputBigger;
    }

    // get flashloan from contract
    function startLoan(
        address _tokenBorrow,
        address _tokenBaseBorrow, //probably WBNB
        address _trade1TOken,
        address _trade2Token,
        address _trade3Token,
        uint256 _amount
    ) external {
        IERC20(_trade1TOken).safeApprove(address(PANCAKEV2_ROUTER), MAX_INT);
        IERC20(_trade2Token).safeApprove(address(PANCAKEV2_ROUTER), MAX_INT);
        IERC20(_trade3Token).safeApprove(address(PANCAKEV2_ROUTER), MAX_INT);

        // get the factory pair address for combined
        address pair = IUniswapV2Factory(PANCAKEV2_FACTORY).getPair(
            _tokenBorrow,
            _tokenBaseBorrow
        );

        require(pair != address(0), "pool doesn't exist");

        // get pair
        address token0 = IUniswapV2Pair(pair).token0();
        address token1 = IUniswapV2Pair(pair).token1();
        uint256 amountOut0 = _tokenBorrow == token0 ? _amount : 0;
        uint256 amountOut1 = _tokenBorrow == token1 ? _amount : 0;

        // encode data
        bytes memory data = abi.encode(
            _tokenBorrow,
            _amount,
            msg.sender,
            _trade1TOken,
            _trade2Token,
            _trade3Token
        );

        // call swap
        IUniswapV2Pair(pair).swap(amountOut0, amountOut1, address(this), data);
    }

    function pancakeCall(
        address _sender,
        uint256 _amount0,
        uint256 _amount1,
        bytes calldata _data
    ) external {
        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();

        address pair = IUniswapV2Factory(PANCAKEV2_FACTORY).getPair(
            token0,
            token1
        );
        require(pair == msg.sender, "pool does not exist");
        require(
            _sender == address(this),
            "Swap call was not called by this contract"
        );

        // decode data
        (
            address _tokenBorrow,
            uint256 _amount,
            address myAddress,
            address _tradeToken1,
            address _tradeToken2,
            address _tradeToken3
        ) = abi.decode(
                _data,
                (address, uint256, address, address, address, address)
            );

        // calculate amount to repay
        uint256 fee = ((_amount * 3) / 997) + 1;
        uint256 amountToRepay = _amount.add(fee);

        // Perform arbitrage
        // get Trade amount
        uint256 tradeAmount = _amount0 > 0 ? _amount0 : _amount1;

        // ensure tradeToken1 is tokenBorrow
        require(
            _tradeToken1 == _tokenBorrow,
            "tokens not parsed in order, first parsed token should equal borrow token"
        );

        // placeTrade
        uint256 receivedAmountTrade1 = placeTrade(_tradeToken1, _tradeToken2, tradeAmount);
        uint256 receivedAmountTrade2 = placeTrade(
            _tradeToken2,
            _tradeToken3,
            receivedAmountTrade1
        );
        uint256 receivedAmountTrade3 = placeTrade(
            _tradeToken3,
            _tradeToken1,
            receivedAmountTrade2
        );

        // check trade profitablity
        bool isOutputBigger = checkProfitability(
            amountToRepay,
            receivedAmountTrade3
        );
        require(isOutputBigger, "Trade not profitable");

        // Pay yourself
        if (isOutputBigger) {
            IERC20 otherToken = IERC20(_tokenBorrow);
            otherToken.transfer(myAddress, receivedAmountTrade3 - amountToRepay);
        }

        // Pay back loan
        IERC20(_tokenBorrow).safeTransfer(pair, amountToRepay);
    }
}
