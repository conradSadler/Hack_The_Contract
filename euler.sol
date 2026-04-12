// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract euler
{

    mapping(address => uint256) public liquidateOptions;
    mapping(address => uint256) public multiplyerTable;
    address public eDAI;
    address public dDAI;
    address public owner;

    event health(address account, string health, uint256 EquityToDebt);

    constructor(address _owner, address _dDAI)
    {
        owner = _owner;
        dDAI = _dDAI;
    }
    
    function setEDAI(address _eDAI) public
    {
        require(msg.sender == owner, "Only the owner can change the eDAI");
        eDAI = _eDAI;
    }

    //This function is called by those who want to liquidate unsolivent accounts
    function liquidateAccount(address account, uint256 amount) public
    {

        uint256 reward = liquidateOptions[account]; //get the liquidation rate
        require(reward > 12, "Can not liquidate a solivent account"); //must be greater than 12 meaning that the account must have 125% dDAI to eDAI
        (bool getAmount, bytes memory accountAmount) = eDAI.call(abi.encodeWithSignature("balanceOf(address)", account));  //get the balance of the unsolivent account
        require(getAmount, "Could not get the bad account's balance of eDAI");

        uint256 amountE = abi.decode(accountAmount, (uint256)); //get the balance of the unsolivent account as number

        uint256 amountGained = (amount*(100+reward)) / 100 ;

        require(amountGained <= amountE, "Liquidation amount + reward is above insolvent accounts eDAI");

        (bool liquidate , ) = eDAI.call(abi.encodeWithSignature("liquidate(address,address,uint256,uint256)", msg.sender,account,amount,amountGained));
        require(liquidate, "Could not complete liquidation");
    }
    
    
    function healthCheck(address account) public returns(uint256)
    {
        (bool success1,bytes memory eBalance) = eDAI.call(abi.encodeWithSignature("balanceOf(address)", account));
        require(success1, "Did not get eDAI balance");
        uint256 amountE = abi.decode(eBalance, (uint256));

         (bool success2,bytes memory dBalance) = dDAI.call(abi.encodeWithSignature("balanceOf(address)", account));
        require(success2, "Did not get dDAI balance");
         uint256 amountD = abi.decode(dBalance, (uint256));
        if(amountD != 0)
        {
            uint256 eToD = (amountE * 100) / amountD;
            uint256 liquidationRate = 100000/(eToD *100);
            if(liquidationRate > 20)
            {
                liquidateOptions[account] = 20;
            }
            else
            {
                liquidateOptions[account] = liquidationRate;
            }

            if(liquidationRate > 10)
            {
                emit health(account, "Bad Health", eToD);
            }
            else
            {
                emit health(account, "Good Health", eToD);
            }
            return liquidationRate;
        }
        else
        {
            return 0;
        }
    }
    
    /// @notice This function is used to increase a account's leverage
    /// @param multiplyer this must be below 20 (can leverage accounts assets by less than 20x)
    function leverage(uint256 multiplyer) public
    {
        uint256 accountHealth = healthCheck(msg.sender);
        require(accountHealth  <= 10, "Can not leverage assets becasue eDAI is not 1 to 1 with dDAI");
        require(multiplyer < 20 && multiplyer > 1, "multilyer must be less than 20x and greater than 1");
        uint256 startingAmount = multiplyerTable[msg.sender];

        (bool getAmount, bytes memory accountAmount) = eDAI.call(abi.encodeWithSignature("balanceOf(address)", msg.sender));
        require(getAmount, "Could not get the callers balance of eDAI");
        uint256 balanceSender = abi.decode(accountAmount, (uint256));

        if(startingAmount == 0)
        {
            multiplyerTable[msg.sender] = balanceSender;
            uint256 createEDAI = (balanceSender * multiplyer) - balanceSender;
            uint256 createDDAI = (balanceSender * multiplyer);
            (bool makeCoins,) = eDAI.call(abi.encodeWithSignature("lever(address,uint256,uint256)", msg.sender, createEDAI,createDDAI));
            require(makeCoins, "Failed to make eDAI and dDAI for leverage");
        }
        else
        {
            uint256 amountWithMul = startingAmount * multiplyer;
            uint256 difference = amountWithMul - balanceSender;
            (bool makeCoins,) = eDAI.call(abi.encodeWithSignature("lever(address,uint256,uint256)", msg.sender, difference,difference));
            require(makeCoins, "Failed to make eDAI and dDAI for already leveraged account");
        }
    }
    
    function resetInitialBalance(address account) public
    {
        require(msg.sender == eDAI, "Only eDAI contract can call");
        multiplyerTable[account] = 0;

    }

}