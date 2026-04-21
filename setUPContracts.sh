#!/bin/bash
# ------------------------------------------------------------------
# 
#   Description: Automate the deployement of contracts on foundry for all 5 challenges including Reentrancy attack easy, Reentrancy attack hard, overflow, gas attack, euler attack
#
#   Author: ConRad Sadler
# Note I should have used $(echo $proxy | grep "Deployed to:" | awk '{print $3}') or something like that
# ------------------------------------------------------------------


usage="Usage: ./setUPContracts.sh  [ public key ] [ private key ] [ price_for_slot ] [ rpc url (optional, defaults to http://127.0.0.1:8545) ]"
example="Example: ./setUPContracts.sh 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 1000"
example2="Example: ./setUPContracts.sh 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 1000 https://ethereum-sepolia-rpc.publicnode.com"

rpc_url="http://127.0.0.1:8545"

if [ $# -lt 3 ] || [ $# -gt 4 ]; then
    echo "$usage"
    echo "$example"
    echo "$example2"
    exit 1
elif [ $# -eq 4 ]; then
    rpc_url=$4
fi


public_key=$1
private_key=$2
price_for_slot=$3


# Make Proxy Contract
proxy=$(forge create src/proxy.sol:proxy --private-key "$private_key" --broadcast --constructor-args 69 --rpc-url "$rpc_url")

if [ $? -ne 0 ]; then
        echo "Failed to deploy proxy contract"
        echo "$proxy"
        exit 1
fi
proxyPartial=${proxy##*"Deployed to: "}
proxyAddress=${proxyPartial:0:42}


#Make dDAI Contract
dDAI=$(forge create src/Challenge_5/dDAI.sol:DToken --private-key "$private_key" --broadcast --constructor-args "$public_key" --rpc-url "$rpc_url")

if [ $? -ne 0 ]; then
        echo "Failed to create dDAI contract"
        echo "$dDAI"
        exit 1
fi
dDAIPartial=${dDAI##*"Deployed to: "}
dDAIAddress=${dDAIPartial:0:42}

#Make euler Contract
euler=$(forge create src/Challenge_5/euler.sol:euler --private-key "$private_key" --broadcast --constructor-args "$public_key" "$dDAIAddress" --rpc-url "$rpc_url")

if [ $? -ne 0 ]; then
        echo "Failed to create euler contract"
        echo "$euler"
        exit 1
fi

eulerPartial=${euler##*"Deployed to: "}
eulerAddress=${eulerPartial:0:42}

#Make lender Contract
lender=$(forge create src/Challenge_5/lender.sol:lender --private-key "$private_key" --broadcast --constructor-args "$public_key" "$proxyAddress" --rpc-url "$rpc_url")

if [ $? -ne 0 ]; then
        echo "Failed to create lender contract"
        echo "$lender"
        exit 1
fi
lenderPartial=${lender##*"Deployed to: "}
lenderAddress=${lenderPartial:0:42}

#Add Lender to proxy: Note that the command BELOW sets the VULN ID to be 16
addLender=$(cast send "$proxyAddress" "add_contract(uint256 id, address contract_address, uint128 _price_for_slot)" 16 "$lenderAddress" "$price_for_slot" --private-key "$private_key" --rpc-url " $rpc_url")

if [ $? -ne 0 ]; then
        echo "Failed to add lender to proxy contract vuln mapping"
        echo "$addLender"
        exit 1
fi

#Make sDAI Contract
sDAI=$(forge create src/Challenge_5/sDAI.sol:sDAI --private-key "$private_key" --broadcast --constructor-args "$public_key" "$lenderAddress" --rpc-url " $rpc_url")

if [ $? -ne 0 ]; then
        echo "Failed to create sDAI contract"
        echo "$sDAI"
        exit 1
fi

sDAIPartial=${sDAI##*"Deployed to: "}
sDAIAddress=${sDAIPartial:0:42}

#Make eDAI Contract
eDAI=$(forge create src/Challenge_5/eDAI.sol:EToken --private-key "$private_key" --broadcast --constructor-args "$sDAIAddress" "$eulerAddress" "$dDAIAddress" --rpc-url " $rpc_url")

if [ $? -ne 0 ]; then
        echo "Failed to create eDAI"
        echo "$eDAI"
        exit 1
fi

eDAIPartial=${eDAI##*"Deployed to: "}
eDAIAddress=${eDAIPartial:0:42}


#Set eDAI for dDAI:
cast send "$dDAIAddress" "setEDAI(address)" "$eDAIAddress" --private-key "$private_key" --rpc-url " $rpc_url"

if [ $? -ne 0 ]; then
	echo "Set eDAI for dDAI"
	exit 1
fi

#Set eDAI for euler:
cast send "$eulerAddress" "setEDAI(address)" "$eDAIAddress" --private-key "$private_key" --rpc-url " $rpc_url"

if [ $? -ne 0 ]; then
	echo "Set eDAI for euler"
	exit 1
fi

#Set sDAI for lender:
cast send "$lenderAddress" "setSDAI(address)" "$sDAIAddress" --private-key "$private_key" --rpc-url " $rpc_url"

if [ $? -ne 0 ]; then
	echo "Set sDAI for lender"
	exit 1
fi

#Set eDAI for sDAI:
cast send "$sDAIAddress" "setEDAI(address)" "$eDAIAddress" --private-key "$private_key" --rpc-url " $rpc_url"

if [ $? -ne 0 ]; then
	echo "Set eDAI for sDAI failed"
	exit 1
fi

#Fund proxy contract
cast send "$proxyAddress" --value 1ether --private-key "$private_key" --rpc-url " $rpc_url"

if [ $? -ne 0 ]; then
	echo "Failed to fund proxy contract"
	exit 1
fi

#Make DAOFactory Contract
daoEasy=$(forge create src/Challenge_1/DAOFactory.sol:DAOFactory --private-key "$private_key" --broadcast --rpc-url " $rpc_url")

if [ $? -ne 0 ]; then
        echo "Failed to create DAOFactory for the easy Re-entrancy attack"
        echo "$daoEasy"
        exit 1
fi

daoEasyPartial=${daoEasy##*"Deployed to: "}
daoEasyAddress=${daoEasyPartial:0:42}

#Add DAOFactory to proxy: Note that the command BELOW sets the VULN ID to be 1
cast send "$proxyAddress" "add_contract(uint256 id, address contract_address, uint128 _price_for_slot)" 1 "$daoEasyAddress" "$price_for_slot" --private-key "$private_key" --rpc-url " $rpc_url"

if [ $? -ne 0 ]; then
	echo "Adding DAOFactory to proxy failed"
	exit 1
fi

#Make DAOFactoryTwo Contract
daoHard=$(forge create src/Challenge_2/DAOFactoryTwo.sol:DAOFactoryTwo --private-key "$private_key" --broadcast --rpc-url " $rpc_url")

if [ $? -ne 0 ]; then
    echo "Failed to create DAOFactoryTwo for the hard Re-entrancy attack"
    echo "$daoHard"
    exit 1
fi

daoHardPartial=${daoHard##*"Deployed to: "}
daoHardAddress=${daoHardPartial:0:42}

#Add DAOFactory to proxy: Note that the command BELOW sets the VULN ID to be 2
cast send "$proxyAddress" "add_contract(uint256 id, address contract_address, uint128 _price_for_slot)" 2 "$daoHardAddress" "$price_for_slot" --private-key "$private_key" --rpc-url " $rpc_url"

if [ $? -ne 0 ]; then
	echo "Adding hard Re-entrancy challenge to proxy failed"
	exit 1
fi

#Make gas Contract
gas=$(forge create src/Challenge_4/gas.sol:GasGriefingFactory --private-key "$private_key" --broadcast --rpc-url " $rpc_url")

if [ $? -ne 0 ]; then
    echo "Failed to create gas contract"
    echo "$gas"
    exit 1
fi

gasPartial=${gas##*"Deployed to: "}
gasAddress=${gasPartial:0:42}

#Add gas challenge to proxy: Note that the command BELOW sets the VULN ID to be 8
cast send "$proxyAddress" "add_contract(uint256 id, address contract_address, uint128 _price_for_slot)" 8 "$gasAddress" "$price_for_slot" --private-key "$private_key" --rpc-url " $rpc_url"

if [ $? -ne 0 ]; then
	echo "Adding gas challenge to proxy failed"
	exit 1
fi

#Make overflow Contract
overflow=$(forge create src/Challenge_3/overflow.sol:IntegerOverflowFactory --private-key "$private_key" --broadcast --rpc-url " $rpc_url")

if [ $? -ne 0 ]; then
    echo "Failed to create overflow contract"
    echo "$overflow"
    exit 1
fi

overflowPartial=${overflow##*"Deployed to: "}
overflowAddress=${overflowPartial:0:42}

#Add overflow challenge to proxy: Note that the command BELOW sets the VULN ID to be 4
cast send "$proxyAddress" "add_contract(uint256 id, address contract_address, uint128 _price_for_slot)" 4 "$overflowAddress" "$price_for_slot" --private-key "$private_key" --rpc-url " $rpc_url"

if [ $? -ne 0 ]; then
    echo "Adding overflow challenge to proxy failed"
    exit 1
fi

echo
echo "The following contracts were deployed:"
echo
echo "Proxy: $proxyAddress "
echo "DAOFactory (Challenge 1): $daoEasyAddress "
echo "DAOFactoryTwo (Challenge 2): $daoHardAddress "
echo "overflowFactory (Challenge 3): $overflowAddress "
echo "Gas Attack (Challenge 4): $gasAddress "
echo "euler (Challenge 5): $eulerAddress "
echo "sDAI (Challenge 5): $sDAIAddress "
echo "eDAI (Challenge 5): $eDAIAddress "
echo "dDAI (Challenge 5): $dDAIAddress "
echo "lender (Challenge 5): $lenderAddress "
echo
