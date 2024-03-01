#!/bin/bash

FUNDED_PRV_KEY=0x91ab9a7e53c220e6210460b65a7a3bb2ca181412a8a7b43ff336b3df1737ce12
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR/contracts
forge build
createOutput=$(forge create --private-key $FUNDED_PRV_KEY --chain-id 16813125 -r http://localhost:8545 src/OFA.sol:OFAPrivate)
deployedAddress=$(echo "$createOutput" | grep 'Deployed to:' | awk '{print $3}')
echo "Deployed to: $deployedAddress"
echo '{"address": ''"'$deployedAddress'"}' > $SCRIPT_DIR/deployedAddress.json
