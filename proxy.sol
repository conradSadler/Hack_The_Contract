// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity ^0.8.22;
/// @notice This contract only supports 30 vulnerable smart contracts. This capacity could be increased by changing where the free contract generation bit is stored
contract proxy is Ownable
{

    // A table of user address to user stats
    mapping (address => uint256) public user_stats;
    
    //A table of  contract id to factory contract address
    mapping (uint256 => address) public vuln_gen;

    //A table of  contract user address to contract they are currently working on
    mapping (address=> address) public current_contract;

    uint128 public price_for_slot; // if public, there will be a getter for it impicitly included in the signiture

    event balance(uint256 amount);

    /// @notice making the proxy contract ownable so that only the maker of the contract can add new vulnerable contracts
    constructor(uint128 price) Ownable(msg.sender)
    {
        price_for_slot = price;
    }

    receive() external payable 
    { 
        emit balance(address(this).balance);
    }

    /// @notice This function is only callable by owner
    /// @param id must be a power of 2 for scoring system
    /// @param _price_for_slot if price per slot does not need to change, then pass in existing price for slot
    function add_contract(uint256 id, address contract_address, uint128 _price_for_slot) external onlyOwner
    {
        require(vuln_gen[id] == address(0),"A contract is already mapped to this id");
        require(id > 0 && ( (id & (id-1) ) == 0), "id is not a power of two");
        vuln_gen[id] = contract_address;
        price_for_slot = _price_for_slot;
    }

    /// @notice This function removes free cotract tracking bit to extract score
    /// @param user is the address of the user you want to look up
    function get_score(address user) external view returns (uint256)
    {
        uint256 score = user_stats[user];
        require(score!= 0, "The user does not exist");
        return 2147483647 & score; //(2**31) -1 mask b/c 31 bit used to indicate free contract creation
    }

    /// @notice This function will call the nessesary factory contract which will make a new vulnerable contract of type specified by id
    /// @param id used to specify the contract to be generated
    function generate_contract(uint256 id) public returns(address)
    {
        require(vuln_gen[id] != address(0),"The contract does not exist");
        uint256 stats = user_stats[msg.sender];

        //require(stats & id ==0, "You have already completed this contract"); #There is no harm in redoing a contract, they just cant increase their score
        require((stats & 2147483648) == 0, "Free creation already used, send amount of price_for_slot to reset() or finish created contract before making a new contract."); 
        require(address(this).balance >= 10000, "Contract does not have 10000 wei.");
        user_stats[msg.sender] = stats + 2147483648;
        (bool success, bytes memory data) = vuln_gen[id].call{value:  10000 }(abi.encodeWithSignature("create()"));
        require(success, "Contract creation failed");
        current_contract[msg.sender] = abi.decode(data, (address)); // data must be an address; if a user starts new contract before finishing the previous contract, then the incomplete contract will be lost(over written)
        return abi.decode(data, (address));
    }

    function reset() public payable returns(bool)
    {
        require(msg.value == price_for_slot);
        uint256 stats = user_stats[msg.sender];
        require(stats >= 2147483648, "No reason to pay reset() function");
        user_stats[msg.sender] = stats - 2147483648;
        return true;
    }

    function increment_score(uint256 vuln_id, address player) public returns(uint256)
    {
        require(msg.sender == current_contract[player], "Only vulnerable contract mapped to user can call this function");  //the msg.sender must be the vulnerable contract mapped to the users address in current_contract mapping
        uint256 stats = user_stats[player];
        if(stats & vuln_id == 0)
        {
            user_stats[player] = (stats - 2147483648) + vuln_id; //vuln_id must structly be a power of 2
        }
        else
        {
	        require(stats > 2147483647, "No reason to decriment score");
            //per function generate_contract all users will have 2147483648 added to their score, so no risk of underflow unless they try to call increment score multipule times. The require above handles this case.
            user_stats[player] = stats - 2147483648;
        }
	    return user_stats[player];
    }

}
