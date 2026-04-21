// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract lender is ReentrancyGuard{
    
    uint256 private _owed; //note that tracking owed in an integer works becasue flashloan is nonreentrant, meaning a user calls it, which triggers the nonreentrancy modifyer to block other calls to it until the function has finished execution, at which point owed will be 0 again.

    address public sDAI;

    address public proxy;

    address public owner;

    
    constructor(address _owner, address _proxy)
    {
        owner = _owner;
        proxy = _proxy;
    }
    
    function setSDAI(address _sDAI) public
    {
        require(msg.sender == owner, "Only the owner can change the sDAI");
        sDAI = _sDAI;
    }
    /// @notice This function is used to payback flash loan
    /// @param amount must be greater than 0
    /// @param callIncrement should be 'true' if the user wants to get scored for completing the challange. Otherwise, it should be 'false'
    /// @param player should be the address of the player who initiated the flash loan attack inorder for proper scoring to occur
    function payBack(uint256 amount,bool callIncrement,address player) public
    {
        
        require(amount > 0, "Cant pay back 0 sDAI");
        (bool success1, ) = sDAI.call(abi.encodeWithSignature("burn(address,uint256)", msg.sender,amount));
        require(success1, "Flash loan pay back failed");

        _owed -= amount;

        if(callIncrement)
        {
            require(_owed == 0, "Loan was not repaid");

            (bool haveDAI, ) = sDAI.call(abi.encodeWithSignature("greaterThanMillion(address)", msg.sender));
            require(haveDAI, "Could not get users sDAI balance");
            (bool increment, ) = proxy.call(abi.encodeWithSignature("increment_score(uint256,address)", 16, player)); //note: Contract ID is 16
            require(increment, "Score was not incremented");
        }
    }

    function flashLoan(uint256 amount) public nonReentrant 
    {
        (bool success1, ) = sDAI.call(abi.encodeWithSignature("create(address,uint256)", msg.sender,amount));
        require(success1, "Flash loan was not successfully created");
        _owed += amount;

        (bool success2, ) = msg.sender.call(abi.encodeWithSignature("onFlashLoan()")); //calling contract needs a onFlashLoan() function
        require(success2, "Calling contract failed in onFlashLoan");

        require(_owed == 0, "Loan was not repaid");

    }
    //note: create() for proxy contract to call when setting users current contract to flash loan challange, this DOES NOT make a copy of the lender contract for each user as that would be complex and unnessesary
    function create() public payable returns(address)
    {
        (bool success1, ) = proxy.call{value:  msg.value}("");
        require(success1, "Failed to send money back to proxy");
        return address(this);
    }
}