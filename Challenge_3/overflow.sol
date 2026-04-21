// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/access/Ownable.sol";

contract TimeLock {
    mapping(address => uint256) public balance;
    uint256 public vaultValue;
    uint256 public lockTime;
    address public proxy;
    uint256 public contract_id;

    constructor(address _proxy, uint256 _contract_id, uint256 _lockTime, uint256 _vaultValue) {
        proxy = _proxy;
        contract_id = _contract_id;
        lockTime = _lockTime;
        vaultValue = _vaultValue;
    }

    function deposit() external {
        vaultValue += 10;
        unchecked {
            lockTime += 1 weeks;
        }
    }

    function increaseLockTime(uint256 _seconds) external {
        unchecked {
            lockTime += _seconds;
        }
    }

    function withdraw() external {
        require(block.timestamp > lockTime, "Lock time not expired");
        balance[msg.sender] += vaultValue;
        vaultValue = 0;
    }

    function powned() external {
        require(balance[msg.sender] >= 50, "You have not collected enough money from the TimeLock");
        (bool success, ) = proxy.call(
            abi.encodeWithSignature(
                "increment_score(uint256,address)",
                contract_id,
                msg.sender
            )
        );
        require(success, "Failed to increment score");
    }
}

contract IntegerOverflowFactory is Ownable {
    constructor() Ownable(0x5FbDB2315678afecb367f032d93F642f64180aa3) {}

    uint256 constant VULN_ID = 4;

    function create() external payable onlyOwner returns (address) {
        address proxyAddr = 0x5FbDB2315678afecb367f032d93F642f64180aa3;

        TimeLock timeLock_ = new TimeLock(proxyAddr, VULN_ID, 7100782712, 10);

        return address(timeLock_);
    }
}