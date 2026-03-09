// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity ^0.8.22;

contract proxy is Ownable{

    // A table of user address to user stats
    mapping (address => uint256) public user_stats;
    
    //A table of  contract id to factory contract address
    mapping (uint256 => address) public vuln_gen;

    //A table of  contract user address to contract they are currently working on
    mapping (address=> address) public current_contract;

    uint128 public price_for_slot; // if public, there will be a getter for it impicitly included in the signiture

    constructor(uint256 id, address first_contract, uint128 price) Ownable(msg.sender){
        vuln_gen[id] = first_contract;
        price_for_slot = price;
    }

    function add_contract(uint256 id, address contract_address, uint128 _price_for_slot) external onlyOwner
    {
        require(vuln_gen[id] == address(0),"A contract is already mapped to this id");
        require(id > 0 && ( (id & (id-1) ) == 0), "id is not a power of two");
        vuln_gen[id] = contract_address;
        price_for_slot = _price_for_slot;
    }

    function get_score(address user) external view returns (uint256)
    {
        uint256 score = user_stats[user];
        require(score!= 0, "The user does not exist");
        return 2147483647 & score; //(2**31) -1 mask b/c 2**32 should be plenty big for scores
    }
    
    function generate_contract(uint256 id) public payable
    {
        require(vuln_gen[id] != address(0),"The contract does not exist");
        uint256 stats = user_stats[msg.sender];

        //require(stats & id ==0, "You have already completed this contract"); #There is no harm in redoing a contract, they just cant increase their score
        bool free_contract = ((stats & 2147483648) == 0); 

        if(free_contract)
        {
            require(msg.value == 0); // the user should not pay if they are able to use a free contract
            user_stats[msg.sender] = stats + 2147483648;
        }
        else
        {
            require(msg.value  == price_for_slot);
        }
        (bool success, bytes memory data) = vuln_gen[id].call{value:  1000 gwei}(abi.encodeWithSignature("create()"));
        require(success, "Contract creation failed"); //prevents gas greiving
        current_contract[msg.sender] = abi.decode(data, (address)); // data must be an address, if a user starts new contract before finishing the previous contract, they the incomplete contract will be lost

    }

    function increment_score(uint256 vuln_id, address player) public
    {
        require(msg.sender == current_contract[player], "You are not working on this contract");
        uint256 stats = user_stats[player];
        if(stats & vuln_id == 0)
        {
            user_stats[player] = (stats - 2147483648) + vuln_id; //vuln_id must structly be a power of 2
        }
        else
        {
            //per function generate_contract all users will have 2147483648 added to their score, so no risk of underflow
            user_stats[player] = stats - 2147483648; //yes, even players that payed for the contract get their free contract reset, this means that someone could expend system resources by not completing,completing,notcompleting,...
        }
    }

}
