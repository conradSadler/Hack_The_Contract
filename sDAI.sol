// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice Tokenised representation of assets
contract sDAI  is ERC20
{

    mapping(address => uint256) internal payedIn;
    address public eDAI;
    address public lender;
    address public owner;

    constructor(address _owner, address _lender) ERC20("syntheticDAI","sDAI")
    {
        owner= _owner;
        lender = _lender;
    }
    
    function setEDAI(address _eDAI) public
    {
        require(msg.sender == owner, "Only the owner can change the eDAI");
        eDAI = _eDAI;
    }

    function burn(address account,uint256  amount) public
    {
        require(msg.sender == lender || msg.sender == eDAI, "Caller must only be eDAI contract");
        _burn(account,amount);
    }

    function create(address account,uint256  amount) public
    {
        require(msg.sender == lender ||  msg.sender == eDAI, "Only the lender or eDAI contract can call this function");
        _mint(account,amount);
    }

    function greaterThanMillion(address account) public view
    {
        require(balanceOf(account) > 1000000,"Users account in not greater than zero sDAI");
    }
}