#!/bin/bash
### run the test script in an infinite loop
### this is useful for testing the script on a testnet
### just don't forget to stop it when you're done
### it'll drain your goerli wallet if you leave it on all night

while [ 1 == 1 ]; do
    bun run index.ts
    echo "sleeping for 2 min..."
    sleep 120
done
