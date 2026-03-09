// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;
abstract contract ManagedAccountInterface
{
    // The only address with permission to withdraw from this account
    address public owner;
    // If true, only the owner of the account can receive ether from it
    bool public payOwnerOnly;
    // The sum of ether (in wei) which has been sent to this contract
    uint public accumulatedInput;

    /// @notice Sends `_amount` of wei to _recipient
    /// @param _amount The amount of wei to send to `_recipient`
    /// @param _recipient The address to receive `_amount` of wei
    /// @return True if the send completed
    function payOut(address _recipient, uint _amount) public payable virtual returns (bool);

    event PayOut(address indexed _recipient, uint _amount);
}

contract ManagedAccount is ManagedAccountInterface
{
    event Refund(address indexed to, uint value); //stores the address in the transaction's topics log rather than the data payload
    // The constructor sets the owner of the account
    constructor(address _owner, bool _payOwnerOnly) {
        owner = _owner;
        payOwnerOnly = _payOwnerOnly;
    }

    // When the contract receives a transaction without data this is called. 
    // It counts the amount of ether it receives and stores it in 
    // accumulatedInput.
    fallback() external payable {
        accumulatedInput += msg.value; 
    }
    
    receive() external payable { 
    accumulatedInput += msg.value; 
    }
    function payOut(address _recipient, uint _amount) public payable override returns (bool) {
        if (msg.sender != owner || msg.value > 0 || (payOwnerOnly && _recipient != owner))
            revert();
        (bool success, ) = _recipient.call{value:  _amount}("");
        if (success) {
            emit PayOut(_recipient, _amount);
            return true;
        } else {
            return false;
        }
    }
}

contract Dao
{
        uint256 accumulatedInput;
        uint256 closingTime;
        uint256 contract_id;
        bool isFueled;
        address proxy;
        ManagedAccount public extraBalance;
        mapping (address => uint256) weiGiven;
        event Refund(address indexed to, uint value);

        constructor(uint256 _closingTime, uint256 _contract_id)
        {
            closingTime = _closingTime;
            contract_id = _contract_id;
        }
        receive() external payable { 
            accumulatedInput += msg.value;
        }
        fallback() external payable { 
            accumulatedInput += msg.value;
        }
        function deposit() public payable
        {
            weiGiven[msg.sender] += msg.value;
            accumulatedInput += msg.value;
        }

        function refund() public payable 
        {
            if (block.timestamp > closingTime && !isFueled) {
                // Get extraBalance - will only succeed when called for the first time
                if (address(extraBalance).balance >= extraBalance.accumulatedInput())
                    extraBalance.payOut(address(this), extraBalance.accumulatedInput());

                // Execute refund
                uint256 refund_amount = weiGiven[msg.sender];
                if(address(this).balance < weiGiven[msg.sender])
                {
                    refund_amount = address(this).balance;
                }
                accumulatedInput = accumulatedInput - refund_amount;
                (bool success, ) = msg.sender.call{value:  refund_amount}("");
                if (success) {
                    emit Refund(msg.sender, weiGiven[msg.sender]);
                    weiGiven[msg.sender] = 0;
                }
            }
    }

    function powned() public //the user must call, 
    {
        if(address(this).balance == 0 )
        {
            (bool success, ) = proxy.call(abi.encodeWithSignature("increment_score(uint256 vuln_id, address player)", contract_id, msg.sender));
             require(success);
        }
    }

}
