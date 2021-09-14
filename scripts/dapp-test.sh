#!/usr/bin/env bash
set -e

oops() {
    echo "$0:" "$@" >&2
    exit 1
}

export ETH_RPC_URL="https://fee7372b6e224441b747bf1fde15b2bd.eth.rpc.rivet.cloud"

export DAPP_SRC=./contracts
export DAPP_SOLC_VERSION=0.5.15
export SOLC_FLAGS="--optimize --optimize-runs 50000"

dapp build

block=$(seth block latest)

export DAPP_TEST_TIMESTAMP=$(seth --field timestamp <<< "$block")
export DAPP_TEST_NUMBER=$(seth --field number <<< "$block")
export DAPP_TEST_ORIGIN="0xec3281124d4c2fca8a88e3076c1e7749cfecb7f2"
export DAPP_TEST_CHAINED=99
export DAPP_TEST_ADDRESS="0xec3281124d4c2fca8a88e3076c1e7749cfecb7f2"
printf 'Running test for address %s\n' "$DAPP_TEST_ADDRESS"
LANG=C.UTF-8 dapp test --rpc-url "https://fee7372b6e224441b747bf1fde15b2bd.eth.rpc.rivet.cloud" -v --verbosity 5 --match test_onchain_prop_18
