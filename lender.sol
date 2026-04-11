// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract lender is ReentrancyGuard{
    
    uint256 private _owed; //note that tracking owed in an integer works becasue flashloan in nonreentrant, meaning a user calls it, which triggers the nonreentrancy modifyer to block other calls to it until the function has finished execution, at which point owed will be 0 again.

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

    function payBack(uint256 amount,bool callIncrement,address player) public{ //NOTE: I was failing on nonReentrant, this function can not have nonReentrant attribute
        
        require(amount > 0, "Cant pay back 0 sDAI");
        (bool success1, ) = sDAI.call(abi.encodeWithSignature("destroy(address,uint256)", msg.sender,amount));
        require(success1, "Flash loan pay back failed");

        _owed -= amount;

        if(callIncrement)
        {
            require(_owed == 0, "Loan was not repaid");

            (bool haveDAI, ) = sDAI.call(abi.encodeWithSignature("greaterThanZero(address)", msg.sender));
            require(haveDAI, "Could not get users sDAI balance");
            (bool increment, ) = proxy.call(abi.encodeWithSignature("increment_score(uint256,address)", 16, player)); // Contract id is 16
            require(increment, "Score was not incremented");
        }
    }

    function flashLoan(uint256 amount) public nonReentrant {
        (bool success1, ) = sDAI.call(abi.encodeWithSignature("create(address,uint256)", msg.sender,amount));
        require(success1, "Flash loan was not successfully created");
        _owed += amount;

        (bool success2, ) = msg.sender.call(abi.encodeWithSignature("onFlashLoan()")); //calling contract needs a onFlashLoan() function
        require(success2, "Calling contract failed in onFlashLoan");

        require(_owed == 0, "Loan was not repaid");

    }

    function create() public payable returns(address)
    {
        (bool success1, ) = proxy.call{value:  msg.value}("");
        require(success1, "Failed to send money back to proxy");
        return address(this);
    }
}