#!/usr/bin/env bash
set -e

oops() {
    echo "$0:" "$@" >&2
    exit 1
}

export ETH_RPC_URL="https://fee7372b6e224441b747bf1fde15b2bd.eth.rpc.rivet.cloud/"

export DAPP_SRC=./contracts
export DAPP_SOLC_VERSION=0.5.15
export SOLC_FLAGS="--optimize --optimize-runs 50000"

block=$(seth block latest)

export DAPP_TEST_TIMESTAMP=$(seth --field timestamp <<< "$block")
export DAPP_TEST_NUMBER=$(seth --field number <<< "$block")
export DAPP_TEST_ORIGIN="0x683A78bA1f6b25E29fbBC9Cd1BFA29A51520De84"
export DAPP_TEST_CHAINED=99
export DAPP_TEST_ADDRESS="0x683A78bA1f6b25E29fbBC9Cd1BFA29A51520De84"
printf 'building'
LANG=C.UTF-8 dapp build --extract
