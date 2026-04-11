#!/bin/bash
# ------------------------------------------------------------------
# 
#   Description: Automate the deployement of contracts on foundry for Flash loan attack ALSO fund the proxy contract
#
#   Author: Conrad Sadler
# ------------------------------------------------------------------
# Make Proxy, assumed deployed to 0x5FbDB2315678afecb367f032d93F642f64180aa3
forge create src/proxy.sol:proxy --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast --constructor-args 69
#Make dDAI assumed deployed to 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
forge create src/dDAI.sol:DToken --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast --constructor-args 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
#Make euler assumed deployed to 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
forge create src/euler.sol:euler --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast --constructor-args 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
#Make lender assumed deployed to 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9
forge create src/lender.sol:lender --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast --constructor-args 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 0x5FbDB2315678afecb367f032d93F642f64180aa3
#Add Lender to proxy: Note that the command BELOW sets the VULN ID to be 16
cast send 0x5FbDB2315678afecb367f032d93F642f64180aa3 "add_contract(uint256 id, address contract_address, uint128 _price_for_slot)" 16 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 1000 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
#Make sDAI assumed deployed to 0x5FC8d32690cc91D4c39d9d3abcBD16989F875707
forge create src/sDAI.sol:sDAI --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast --constructor-args 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9
#Make eDAI assumed deployed to 0x0165878A594ca255338adfa4d48449f69242Eb8F
forge create src/eDAI.sol:EToken --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast --constructor-args 0x5FC8d32690cc91D4c39d9d3abcBD16989F875707 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
#Set eDAI for dDAI:
cast send 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 "setEDAI(address)" 0x0165878A594ca255338adfa4d48449f69242Eb8F --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
#Set eDAI for euler:
cast send 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0 "setEDAI(address)" 0x0165878A594ca255338adfa4d48449f69242Eb8F --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
#Set sDAI for lender:
cast send 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 "setSDAI(address)" 0x5FC8d32690cc91D4c39d9d3abcBD16989F875707 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
#Set eDAI for sDAI:
cast send 0x5FC8d32690cc91D4c39d9d3abcBD16989F875707 "setEDAI(address)" 0x0165878A594ca255338adfa4d48449f69242Eb8F --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
#Make liquidator assumed deployed to 0xB7f8BC63BbcaD18155201308C8f3540b07f84F5e
forge create src/liquidate.sol:liquidate --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast --constructor-args 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0 0x0165878A594ca255338adfa4d48449f69242Eb8F 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 22000000 30000000
#Create donate contract assumed deployed to 0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0
forge create src/donate.sol:donate --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast --constructor-args 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 0x0165878A594ca255338adfa4d48449f69242Eb8F 0x5FC8d32690cc91D4c39d9d3abcBD16989F875707 0xB7f8BC63BbcaD18155201308C8f3540b07f84F5e 27000000 30000000 18 27000000
#Fund proxy contract
cast send 0x5FbDB2315678afecb367f032d93F642f64180aa3 --value 1ether --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
#link lender contract to player, WE DO NOT GENERATE A NEW LENDOR CONTRACT PER PLAYER
cast send 0x5FbDB2315678afecb367f032d93F642f64180aa3 "generate_contract(uint256 id)" 16 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

