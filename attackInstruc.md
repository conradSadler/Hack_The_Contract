**Call being in donate():**

cast send 0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0 "begin()" \--private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

**Check user score:**

cast call 0x5FbDB2315678afecb367f032d93F642f64180aa3 "get\_score(address) (uint256)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

**Note:** for troubleshooting import: import "forge-std/console.sol"; and add the following in functions to track:  
       uint256 my\_variable\_31 \= 31;  
       console.log(my\_variable\_31);