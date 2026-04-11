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

    function leverD(address account, uint256 amount) public
    {
        require(msg.sender == eDAI); // only the euler contract can call this function
        _mint(account,amount);
    }

    function deLever(address account, uint256 amount) public
    {
        require(msg.sender == eDAI); // only the euler contract can call this function
        _burn(account,amount);
    }

    function setEDAI(address _eDAI) public
    {
        require(msg.sender == owner, "Only the owner can change the eDAI");
        eDAI = _eDAI;
    }

}