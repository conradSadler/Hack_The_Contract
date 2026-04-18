**Make liquidator assumed deployed to liquidator**

forge create src/liquidate.sol:liquidate --private-key PRIVATE_KEY --broadcast --constructor-args euler eDAI lender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 22000000 30000000

**Create donate contract**

forge create src/donate.sol:donate --private-key PRIVATE_KEY --broadcast --constructor-args 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 euler lender eDAI sDAI liquidator 27000000 30000000 18 27000000

**link lender contract to player, WE DO NOT GENERATE A NEW LENDOR CONTRACT PER PLAYER**

cast send proxy "generate_contract(uint256 id)" 16 --private-key PRIVATE_KEY

**Call being in donate():**

cast send 0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0 "begin()" \--private-key PRIVATE_KEY

**Check user score:**

cast call 0x5FbDB2315678afecb367f032d93F642f64180aa3 "get\_score(address) (uint256)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

**Note:** for troubleshooting import: import "forge-std/console.sol"; and add the following in functions to track:  
       uint256 my\_variable\_31 \= 31;  
       console.log(my\_variable\_31);
       
