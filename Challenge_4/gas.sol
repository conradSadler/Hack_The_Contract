// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Target {
    mapping(address => bool) public enoughGas;
    mapping(address => bool) public executed;
    address public proxy;
    uint256 public contract_id;
    address public relayer;
    address public deployer;

    constructor(address _proxy, uint256 _contract_id, address _relayer) {
        proxy = _proxy;
        contract_id = _contract_id;
        relayer = _relayer;
        deployer = msg.sender;
    }

    function setRelayer(address _relayer) external {
        require(msg.sender == deployer, "Only deployer can call");
        require(relayer == address(0), "Already set");
        relayer = _relayer;
    }

    function resetExecuted(address user) external {
        require(msg.sender == relayer, "Only relayer can call");
        enoughGas[user] = false;
        executed[user] = false;
    }
   
    function gasCheck(address user, uint256 _gas) external {
        require(msg.sender == relayer, "Only relayer can call");
        
        // SUPER important loop, can you smell the gas fumes?
        uint256 x = 0;
        for (uint256 i = 0; i < 2; i++) {
            x += i;
        }

        enoughGas[user] = true;
        (bool success, ) = address(this).call{gas: (_gas)}(abi.encodeWithSignature("execute(address)", user));
    }

    function execute(address user) external {
        executed[user] = true;
    }

    function powned() external {
        require(Relayer(relayer).wasExecuted(msg.sender), "Call relayer.forward() first");
        require(enoughGas[msg.sender], "gasCheck was not passed, call relayer.reset() to try again D:");
        require(!executed[msg.sender], "Your transaction executed and gasCheck was passed, but no griefing occurred, call relayer.reset() to try again D:");
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

contract Relayer {
    mapping(address => bool) public wasExecuted;
    Target public target;

    constructor(address _target) {
        target = Target(_target);
    }

    function forward(address user, uint256 _gas) external {
        require(!wasExecuted[user], "Already executed, call reset() to try again");
        wasExecuted[user] = true;
        require(gasleft() > 90000, "not enough gas left"); // this has to be here so foundry doesn't automatically decide that the call can fail and function still returns by undershooting the gas
        (bool success, ) = address(target).call{gas: _gas}(abi.encodeWithSignature("gasCheck(address,uint256)", user, _gas));
        //require(success, "execute failed"); If you require this to be success everything reverts if the call fails and the challenge doesn't work :D
    }

    function reset(address user) external {
        wasExecuted[user] = false;
        target.resetExecuted(user);
    }
}

contract GasGriefingFactory is Ownable {
    constructor() Ownable(0x5FbDB2315678afecb367f032d93F642f64180aa3) {}

    uint256 constant VULN_ID = 8;

    function create() external payable onlyOwner returns (address) {
        address proxyAddr = 0x5FbDB2315678afecb367f032d93F642f64180aa3;

        Target  target_ = new Target(proxyAddr, VULN_ID, address(0));
        Relayer relayer_ = new Relayer(address(target_));

        target_.setRelayer(address(relayer_));

        return address(target_);
    }
}