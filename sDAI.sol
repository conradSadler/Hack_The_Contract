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

    function burn(address account,uint256  amount) public //you want the liquidator to deposite sDAI for eDAI, not eDAI for eDAI
    {
        require(msg.sender == eDAI, "Caller must only be eDAI contract");
        _burn(account,amount);
    }

    function create(address account,uint256  amount) public
    {
        require(msg.sender == lender ||  msg.sender == eDAI, "Only the lender or eDAI contract can call this function");
        _mint(account,amount);
    }

    function destroy(address account,uint256  amount) public
    {
        require(msg.sender == lender, "Only the lender can call this function");
        require(balanceOf(account)>= amount,"Attempting to destroy more sDAI than balance");
         _burn(account, amount);
    }

    function greaterThanZero(address account) public view
    {
        require(balanceOf(account) > 0,"Users account in not greater than zero sDAI");
    }
}