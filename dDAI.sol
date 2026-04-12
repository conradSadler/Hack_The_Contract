// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DToken  is ERC20
{
    address public eDAI;
    address public owner;

    constructor(address _owner) ERC20("debtDAI","dDAI")
    {
        owner = _owner;
    }
    //notice:  only the eDAI contract can call this function
    function leverD(address account, uint256 amount) public
    {
        require(msg.sender == eDAI);
        _mint(account,amount);
    }
    //notice:  only the eDAI contract can call this function
    function deLever(address account, uint256 amount) public
    {
        require(msg.sender == eDAI);
        _burn(account,amount);
    }
    //notice: Only the owner can change the eDAI
    function setEDAI(address _eDAI) public
    {
        require(msg.sender == owner, "Only the owner can change the eDAI");
        eDAI = _eDAI;
    }

}