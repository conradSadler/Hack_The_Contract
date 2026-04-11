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

    function exit() public returns(bool)
    {
        (bool success,bytes memory dBalance) = dDAI.call(abi.encodeWithSignature("balanceOf(address)", msg.sender));
        require(success, "Did not get dDAI balance");
        uint256 amountD = abi.decode(dBalance, (uint256));
        uint256 amountE = balanceOf(msg.sender);

        require(amountE >= amountD, "Can not liduidate until eDAI is greater than or equal to dDAI");


        (bool successMult,bytes memory mult) = euler.call(abi.encodeWithSignature("multiplyerTable(address)", msg.sender));
        require(successMult, "Did not get multiplyer");
        uint256 multiplyer = abi.decode(mult, (uint256));
        uint256 leftOverE = amountE;

        if(multiplyer != 0)
        {
            uint256 ActualE = amountE / multiplyer;
            leftOverE = amountE - ActualE;
        }

        _burn(msg.sender,leftOverE); //remove the leveraged eDAI

        (bool destroyDebt, ) = dDAI.call(abi.encodeWithSignature("deLever(address,uint256)", msg.sender,amountD));
        require(destroyDebt, "Did not destroy dDAI in exit()");


        (bool mintD, ) = sDAIContract.call(abi.encodeWithSignature("create(address,uint256)", msg.sender,leftOverE));
        require(mintD, "Was not able to mint debt");
        return true;
    }

    function lever(address account, uint256 amount) public returns(bool)
    {
        require(msg.sender == euler); // only the euler contract can call this function
        _mint(account,amount - balanceOf(account)); // if they have 2M and leverage 10x, then they need 17M more not 20M more
        (bool mintD, ) = dDAI.call(abi.encodeWithSignature("leverD(address,uint256)", account,amount));
        require(mintD, "Was not able to mint debt");
        return true;
    }
    //looks good
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

    //note that this will revert if the insolivent account does not have eDAI >= eDAIGained
    function liquidate(address account, address badAccount, uint256 amount, uint256 eDAIGained) external //you want the liquidator to deposite sDAI for eDAI, not eDAI for eDAI
    {
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