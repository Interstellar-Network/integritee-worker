#!/bin/bash

# originally from https://github.com/integritee-network/worker/blob/1f76f1acf705f1fce343e9cd7143731cc1befe74/cli/demo_rps.sh

set -euo pipefail

# setup:
# run all on localhost:
#   **IMPORTANT** MUST use the correct `--features=skip-ias-check,skip-extrinsic-filtering` else the worker will get an error
#        `[2022-08-29T15:24:24Z ERROR ws::handler] WS Error <Custom(Extrinsic("extrinsic error code 1010: Invalid Transaction: Inability to pay some fees (e.g. account balance too low)"))>`
#        or `[2022-08-29T15:24:48Z ERROR ws::handler] WS Error <Custom(Extrinsic("extrinsic error code 1012: Transaction is temporarily banned: "))>`
#   integritee-node purge-chain --dev
#   integritee-node --tmp --dev -lruntime=debug
#   rm light_client_db.bin
#   integritee-service init_shard
#   integritee-service shielding-key
#   integritee-service signing-key
#   export RUST_LOG=integritee_service=info,ita_stf=debug
#   integritee-service run

# usage:
#   [full local]    demo_interstellar.sh -p 9990 -P 2090
#   [docker/podman] We CAN NOT use only eg "CLIENT_BIN="podman run --rm ..." b/c that would use a different container
#                   between each steps, and that fails b/c the keystore MUST be shared b/w "new-account" and the other steps!
#   - podman volume create KeyStoreVolume1
#     NOTE: the volume mount point MUST match both Dockerfile's WORKDIR and "const TRUSTED_KEYSTORE_PATH"
#   - curl https://raw.githubusercontent.com/Interstellar-Network/integritee-worker/interstellar-initial/cli/demo_interstellar.sh -o /tmp/demo_interstellar.sh
#   - chmod +x /tmp/demo_interstellar.sh
#   - CLIENT_BIN="podman run --network interstellar-book_default --name integritee_cli -v KeyStoreVolume1:/usr/local/bin/my_trusted_keystore --rm ghcr.io/interstellar-network/integritee_cli:milestone4" /tmp/demo_interstellar.sh -V wss://integritee_service -p 9990 -u ws://integritee_node -P 2090

while getopts ":m:p:P:u:V:C:R:" opt; do
    case $opt in
        m)
            READMRENCLAVE=$OPTARG
            ;;
        p)
            NPORT=$OPTARG
            ;;
        P)
            WORKER1PORT=$OPTARG
            ;;
        u)
            NODEURL=$OPTARG
            ;;
        V)
            WORKER1URL=$OPTARG
            ;;
        C)
            CLIENT_BIN=$OPTARG
            ;;
        R)
            RPC_URL=$OPTARG
            ;;
    esac
done

# Using default port if none given as arguments.
NPORT=${NPORT:-9944}
NODEURL=${NODEURL:-"ws://127.0.0.1"}

WORKER1PORT=${WORKER1PORT:-2000}
WORKER1URL=${WORKER1URL:-"wss://127.0.0.1"}

CLIENT_BIN=${CLIENT_BIN:-"./../bin/integritee-cli"}

READMRENCLAVE=${READMRENCLAVE:-"onchain-registry"}

echo "Using client binary ${CLIENT_BIN}"
echo "Using node uri ${NODEURL}:${NPORT}"
echo "Using trusted-worker uri ${WORKER1URL}:${WORKER1PORT}"
echo "Reading MRENCLAVE from ${READMRENCLAVE}"

CLIENT="${CLIENT_BIN} -p ${NPORT} -P ${WORKER1PORT} -u ${NODEURL} -U ${WORKER1URL}"

if [ "$READMRENCLAVE" = "file" ]
then
    read MRENCLAVE <<< $(cat ~/mrenclave.b58)
    echo "Reading MRENCLAVE from file: ${MRENCLAVE}"
else
    # this will always take the first MRENCLAVE found in the registry !!
    read MRENCLAVE <<< $($CLIENT list-workers | awk '/  MRENCLAVE: / { print $2; exit }')
    echo "Reading MRENCLAVE from worker list: ${MRENCLAVE}"
fi
[[ -z $MRENCLAVE ]] && { echo "MRENCLAVE is empty. cannot continue" ; exit 1; }

################################################################################
# SETUP:
# // ------> ALTERNATIVE use RPCs: [grep "pub const KEY_TYPE: KeyTypeId" to get the correct IDs]
# // - author_insertKey("garb", "//Alice", 0xd43593c715fdd31c61141abd04a99fd6822c8558854ccde39a5684e7a56da27d)
# // - author_insertKey("circ", "//Alice", 0xd43593c715fdd31c61141abd04a99fd6822c8558854ccde39a5684e7a56da27d)
# THEN:
# call Extrinsic ocwCircuits::submitConfigDisplayCircuitsPackageSigned
#
# then run this script
#
# Insert keys to be able to callback from "offchain_worker" to Storage;
# else we hit "No local accounts available. Consider adding one via `author_insertKey` RPC[ALTERNATIVE DEV ONLY check 'if config.offchain_worker.enabled' in service.rs]"
# at ocw-circuits/src/lib.rs#L581
# use correct port, cf "--rpc-port" when starting "integritee-node"
# TODO can we use the worker's RPC?
RPC_URL=${RPC_URL:-"http://localhost:8990"}
# keys from: https://stackoverflow.com/questions/59770639/how-to-activate-substrate-grandpa-finalization
# 0x88dc3417d5058ec4b4503e0c12ea1a0a89be200fe98922423d4334014fa6b0ee
# --> "[ocw-circuits] callback_new_skcd_signed sent number : 0" but nothing modified in Storage?
ALICE_KEY=0xd43593c715fdd31c61141abd04a99fd6822c8558854ccde39a5684e7a56da27d
# TODO? same for ""garb", "//Alice", "0xd43593c715fdd31c61141abd04a99fd6822c8558854ccde39a5684e7a56da27d""
# --> Probably not needed b/c pallet_ocw_garble is NOT using "fn offchain_worker"
curl $RPC_URL --output /dev/null --show-error --fail -H "Content-Type:application/json;charset=utf-8" -d \
  '{
    "jsonrpc":"2.0",
    "id":2,
    "method":"author_insertKey",
    "params": [
      "circ",
      "//Alice",
      "0xd43593c715fdd31c61141abd04a99fd6822c8558854ccde39a5684e7a56da27d"
    ]
  }'

# Print the current ocwCircuits Storage
# To get the correct encoded key(SCALE codec):
# https://polkadot.js.org/apps/?rpc=ws%3A%2F%2F127.0.0.1%3A9990#/chainstate
# and use the displayed "encoded storage key"
echo -e 'ocwCircuits Storage:\n'
OCW_CIRCUITS_STORAGE=$(curl $RPC_URL --silent --show-error --fail -H "Content-Type: application/json;charset=utf-8" -d \
    '{
        "jsonrpc":"2.0",
        "id":3,
        "method": "state_getStorage",
        "params": ["0x2c644167ae9423d1f0683de9002940b8bd009489ffa75ba4c0b3f4f6fed7414b"]
    }' | jq '.result')
# The result is encoded; but we do not need to have the true value, we just want to know if is initialized or not
# eg initialized: 0xb8516d524e6244414778774e6f646e57524b7648517671657a367a615252564d34544a4b53526553324e4635656a3302000000b8516d5277654131316b67705637664a7971377a684b594b6f4d38436575524c32794e4369393167765079617774310a000000
# initial value: "null"
echo "OCW_CIRCUITS_STORAGE: $OCW_CIRCUITS_STORAGE"
if [[ "$OCW_CIRCUITS_STORAGE" == "null" ]]; then
    echo "OCW_CIRCUITS_STORAGE is NOT initialized"
    echo "MUST call extrinsic 'ocwCircuits::submitConfigDisplayCircuitsPackageSigned'"

    echo "Calling 'ocwCircuits::submitConfigDisplayCircuitsPackageSigned'"
    ${CLIENT} demo-ocw-circuits-submit-config-display-circuits-package

    # TODO goto before if and wait in loop until ready
    echo "Extrinsic started: wait a few seconds(~45-60s) and restart this script"
    exit 1
else
    echo "OCW_CIRCUITS_STORAGE already initialized"
    # Nothing to do
fi

################################################################################

PLAYER1=$($CLIENT trusted --mrenclave "$MRENCLAVE" new-account)
echo "New account created: ${PLAYER1}"

echo "Alice (sudo) sets initial balances"
${CLIENT} trusted --mrenclave "${MRENCLAVE}" --direct set-balance "${PLAYER1}" 1000
echo ""

echo "Preparing garbled circuits"
# shellcheck disable=SC2086
${CLIENT} trusted --mrenclave "${MRENCLAVE}" --direct garble-and-strip-display-circuits-package-signed "${PLAYER1}" "REPLACEME tx msg"
echo ""

echo "Query result"
RESULT=$(${CLIENT} trusted --mrenclave "${MRENCLAVE}" --direct get-circuits-package "${PLAYER1}" | xargs)
echo "RESULT: ${RESULT}"

# parse $RESULT to get the IPFS cid
IPFS_CID=$(echo ${RESULT} | awk -F 'message_pgarbled_cid: ' '{print $2}' | awk -F ', message_packmsg_cid:' '{print $1}')
echo "IPFS_CID: ${IPFS_CID}"


# DO NOT use quotes/brackets/etc for user inputs! else: [tx-validation] check_input: input_digits_str = "{"
# it MUST match watch "clap" parser expects: ie a space separated list of param b/c user_inputs is Vec<u8>
echo "Checking tx inputs"

# Get user-given inputs
echo "Go check integritee-service logs to see the correct code and permutations"
read -r -p "Inputs to use? [space separated list of int; eg 0 1 2 3] :" USER_INPUTS

${CLIENT} trusted --mrenclave "${MRENCLAVE}" --direct tx-check-input "${PLAYER1}" "${IPFS_CID}" ${USER_INPUTS}
echo ""

exit 0