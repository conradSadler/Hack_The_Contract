//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Dao.sol";

contract vulnGenProxy is Ownable{
    constructor()  Ownable(**REPLACE WITH PROXY ADDRESS**){}
    function create() external payable returns (address) onlyOwner
    {
        Dao newReEntrancy = new Dao(block.timestamp+300,1); //passing the current time + 5 minutes and the vuln_id of 1 to the newly created vuln contract's contructor
        newReEntrancy.deposit{value:  msg.value}(); //need corresponding function in vulnerable contract
        return address(newReEntrancy );
    }

}
