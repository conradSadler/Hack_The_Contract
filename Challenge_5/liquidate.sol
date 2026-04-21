// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract liquidate
{
    address public euler;
    address public eDAI;
    address public lender;
    address public player;
   
    uint256 public amountToLiq;
    uint256 public loanAmount;

    constructor(address _euler,address _eDAI, address _lender, address _player, uint256 _amountToLiq, uint256 _loanAmount)
    {
        euler = _euler;
        eDAI= _eDAI;
        lender = _lender;
        player = _player;
        amountToLiq = _amountToLiq;
        loanAmount = _loanAmount;
    }

    function beginLiquidation(address account) public
    {

        (bool liquidateAcc,) = euler.call(abi.encodeWithSignature("liquidateAccount(address,uint256)", account,amountToLiq));
        require(liquidateAcc, "Failed to liquidate the account");

        (bool exchange,) = eDAI.call(abi.encodeWithSignature("exit()"));
        require(exchange, "Failed to exchange eDAI => sDAI");

        (bool payBack,) = lender.call(abi.encodeWithSignature("payBack(uint256,bool,address)",loanAmount,true,player));
        require(payBack, "Failed to payback loan");

    }
    function setLoanAmount(uint256 x)public 
    {
        loanAmount = x;
    }
    function setAmountToLiq(uint256 x)public 
    {
        amountToLiq= x;
    }
}