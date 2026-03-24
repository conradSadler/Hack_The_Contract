*Note: that cast send must be used to change state*  
*Note: unless variables are specified as public, they will not have a getter*
*Note: spin up anvil and these instruction will work for the first vulnerable contract created*

**Build proxy contract:**

forge create src/proxy.sol:proxy \--private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \--broadcast \--constructor-args 69

**Build VulnGen contract:**

forge create src/factoryTest.sol:factoryTest \--private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \--broadcast

**Add VulnGen to proxy:(Tested to ensure only owner could call and that existing contracts could not be over written)**

cast send 0x5FbDB2315678afecb367f032d93F642f64180aa3 "add\_contract(uint256 id, address contract\_address, uint128 \_price\_for\_slot)" 1 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 1000 \--private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

**Fund Proxy:**  
cast send 0x5FbDB2315678afecb367f032d93F642f64180aa3 \--value 1ether \--private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

**As User, create contract:**

cast send 0x5FbDB2315678afecb367f032d93F642f64180aa3 "generate\_contract(uint256 id)" 1 \--private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

**Check current contract status:**

cast call 0x5FbDB2315678afecb367f032d93F642f64180aa3 "current\_contract(address) (address)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

**Check score:**

cast call 0x5FbDB2315678afecb367f032d93F642f64180aa3 "get\_score(address)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

**Check vuln contract balance:**  
cast call 0xCafac3dD18aC6c6e92c921884f9E4176737C052c "getBalance()"

**Exploit the contract:**

cast send 0xCafac3dD18aC6c6e92c921884f9E4176737C052c "refund()" \--private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

**Check vuln contract balance:**  
cast call 0xCafac3dD18aC6c6e92c921884f9E4176737C052c "getBalance()"

**Call powned:**

cast send 0xCafac3dD18aC6c6e92c921884f9E4176737C052c "powned()" \--private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

**View new score:**

cast call 0x5FbDB2315678afecb367f032d93F642f64180aa3 "get\_score(address)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266  