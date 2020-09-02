#!/usr/bin/env bash
source "${0%/*}/conf.sh"

NAME="YAMv3"
DOMAIN_SEPARATOR=$(seth keccak \
     $(seth keccak $(seth --from-ascii "EIP712Domain(string name,uint256 chainId,address verifyingContract)"))\
$(echo $(seth keccak $(seth --from-ascii "$NAME"))\
$(seth --to-uint256 $CHAIN_ID)\
$(seth --to-uint256 $ADDRESS) | sed 's/0x//g'))
echo "$DOMAIN_SEPARATOR"
