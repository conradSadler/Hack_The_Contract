**Call being in donate():**

cast send 0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0 "begin()" \--private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

**Check user score:**

cast call 0x5FbDB2315678afecb367f032d93F642f64180aa3 "get\_score(address) (uint256)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

**Make liquidator assumed deployed to 0xB7f8BC63BbcaD18155201308C8f3540b07f84F5e**
forge create src/liquidate.sol:liquidate --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast --constructor-args 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0 0x0165878A594ca255338adfa4d48449f69242Eb8F 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 22000000 30000000

**Create donate contract assumed deployed to 0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0**
forge create src/donate.sol:donate --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast --constructor-args 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 0x0165878A594ca255338adfa4d48449f69242Eb8F 0x5FC8d32690cc91D4c39d9d3abcBD16989F875707 0xB7f8BC63BbcaD18155201308C8f3540b07f84F5e 27000000 30000000 18 27000000


**Note:** for troubleshooting import: import "forge-std/console.sol"; and add the following in functions to track:  
       uint256 my\_variable\_31 \= 31;  
       console.log(my\_variable\_31);
       
