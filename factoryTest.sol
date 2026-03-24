//SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/access/Ownable.sol";
/// @notice The following contract is used purley to test proxy and factory contract capabilities
contract testDAO
{
    uint256 accumulatedInput;
    uint256 closingTime;
    uint256 contract_id;
    bool isFueled;
    address proxy;
    mapping (address => uint256) weiGiven;
    event Refund(address indexed to, uint value);

    constructor(uint256 _closingTime, uint256 _contract_id, address _proxy)
    {
        closingTime = _closingTime;
        contract_id = _contract_id;
        proxy = _proxy;
    }

	receive() external payable 
    {
        accumulatedInput += msg.value;
    }

	fallback() external payable 
    {
        accumulatedInput += msg.value;
    }

	function getBalance() public view returns(uint256)
	{
	    return address(this).balance;
	}
	function getProxy() public view returns(address)
	{
	    return proxy;
	}

	function deposit() public payable
    {
        weiGiven[msg.sender] += msg.value;
        accumulatedInput += msg.value;
    }
    /// @notice VULNERABLE anyone can take contract balance
	function refund() public payable
        {
            (bool success,) = msg.sender.call{value:  address(this).balance}("");
            require(success, "Refund failed");
	    emit Refund(msg.sender,address(this).balance);
        }

    ///@notice This function will only succeed if called by the user who generated the powned contract. Technically, anyone can drain the vulnerable Smart Contract of funds and then the user who created the contract can get the points
	function powned() public
    {
        require(address(this).balance == 0,"address balance is not 0" );
        (bool success, ) = proxy.call(abi.encodeWithSignature("increment_score(uint256,address)", contract_id, msg.sender));  //NOTE: there must not be spaces in abi.encode
        require(success, "Not able to call proxy contract");
	}
}


contract factoryTest is Ownable
{
    ///@notice This contract and all factory contracts are owned by the proxy contract. Only the proxy contract should be able to create a new clone of the vulnerable contract
    constructor()  Ownable(0x5FbDB2315678afecb367f032d93F642f64180aa3){}
    ///@notice This function is only callable by the proxy contract and creates a new testDAO smart contract with a time stamp of 5min from present(not used), the contract identifyer of 1, and the proxy contract address
    ///@notice All value sent to function by proxy is passed onto the newly created vuln contract
    function create() external onlyOwner payable returns (address)
    {
        testDAO newReEntrancy = new testDAO(block.timestamp+300,1,0x5FbDB2315678afecb367f032d93F642f64180aa3); //passing the current time + 5 minutes and the vuln_id of 1 to the newly created vuln contract's contructor
        newReEntrancy.deposit{value:  msg.value}(); //deposit function in vulnerable contract
        return address(newReEntrancy);
    }

}