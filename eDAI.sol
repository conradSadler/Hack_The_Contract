// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @notice Tokenised representation of assets
contract EToken  is ERC20,ReentrancyGuard
{

    address public sDAIContract;
    address public euler;
    address public dDAI;

    constructor(address _sDAIContract, address _euler, address _dDAI) ERC20("equityDAI","eDAI")
    {
        sDAIContract = _sDAIContract;
        euler = _euler;
        dDAI = _dDAI;

    }
    /// @notice This function used to exit from eDAI into synthetic DAI (sDAI)
    function exit() public returns(bool)
    {
        (bool success,bytes memory dBalance) = dDAI.call(abi.encodeWithSignature("balanceOf(address)", msg.sender));
        require(success, "Did not get dDAI balance");
        uint256 amountD = abi.decode(dBalance, (uint256));
        uint256 amountE = balanceOf(msg.sender);

        
        require(amountE >= amountD, "Can not liduidate until eDAI is greater than or equal to dDAI");


        (bool successMult,bytes memory mult) = euler.call(abi.encodeWithSignature("multiplyerTable(address)", msg.sender)); //the multiplyer table holds the amount of starting principle before the account was leveraged
        require(successMult, "Did not get multiplyer");

        uint256 startingAmount = abi.decode(mult, (uint256));
        uint256 actualE = amountE;
        if(startingAmount != 0)
        {
            uint256 multiplyer = amountD/startingAmount;
            actualE = amountE / multiplyer; //20/10=2
        }

        // /resetInitialBalance(address account)

        (bool rmBalance, ) = euler.call(abi.encodeWithSignature("resetInitialBalance(address)",msg.sender));
        require(rmBalance, "Did not zero out account balance in euler contract");

        _burn(msg.sender,amountE); //remove the leveraged eDAI


        (bool destroyDebt, ) = dDAI.call(abi.encodeWithSignature("deLever(address,uint256)", msg.sender,amountD));
        require(destroyDebt, "Did not destroy dDAI in exit()");

        (bool mintD, ) = sDAIContract.call(abi.encodeWithSignature("create(address,uint256)", msg.sender,actualE));
        require(mintD, "Was not able to mint debt");
        return true;
    }

    /// @notice This function is only callable by euler contract
    function lever(address account, uint256 createEDAI, uint256 createDDAI) public returns(bool)
    {
        require(msg.sender == euler); // only the euler contract can call this function

        _mint(account,createEDAI);

        (bool mintD, ) = dDAI.call(abi.encodeWithSignature("leverD(address,uint256)", account,createDDAI));
        require(mintD, "Was not able to mint debt");
        return true;
    }
    /// @notice This function is used to purchase eDAI with sDAI
    function purchase(uint256 amount) public
    {
        (bool success, bytes memory rawData) = sDAIContract.call(abi.encodeWithSignature("balanceOf(address)", msg.sender));
        require(success, "Was not able to get the sDAI balance of sender");
        uint256 balanceSender = abi.decode(rawData, (uint256));

        require(amount <= balanceSender, "Attempting to purchase too many eDAI tokens");

        (bool burn, ) = sDAIContract.call(abi.encodeWithSignature("burn(address,uint256)", msg.sender,amount));
        require(burn, "Did not burn sDAI");
        _mint(msg.sender,amount);
    }

    /// @notice This function is only called by euler contract to liquidate accounts that have far more debt than equity
    function liquidate(address account, address badAccount, uint256 amount, uint256 eDAIGained) external
    {
        require(msg.sender == euler);

        (bool success, bytes memory rawData) = sDAIContract.call(abi.encodeWithSignature("balanceOf(address)", account));
        require(success, "Was not able to get the sDAI balance of sender");

        uint256 balanceSender = abi.decode(rawData, (uint256));
        require(amount <= balanceSender, "Attempting to purchase too many eDAI tokens");

        _burn(badAccount,eDAIGained);


        (bool burn, ) = sDAIContract.call(abi.encodeWithSignature("burn(address,uint256)", account,amount));
        require(burn, "Did not burn sDAI");

        _mint(account,eDAIGained);
    }
    /// @notice Donate eTokens to the reserves
    /// @param amount In internal book-keeping units (as returned from balanceOf).
    function donateToReserves(uint256 amount) external nonReentrant 
    {
        uint256 balanceOfSender = balanceOf(msg.sender);
        require(amount < balanceOfSender, "Attempting to donate more than balance of your of eDAI");
        _transfer(msg.sender, euler, amount);
    }
}