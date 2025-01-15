#!/bin/bash
set -e

# Function to create node.json
create_node_config() {
    cat <<EOF > /odysseygo/.odysseygo/configs/node.json
{
  "log-level": "${LOG_LEVEL_NODE}",
EOF

    if [ "$RPC_ACCESS" = "public" ]; then
        echo '  "http-allowed-hosts": "*",' >> /odysseygo/.odysseygo/configs/node.json
    fi

    if [ "$ADMIN_API" = "true" ]; then
        echo '  "api-admin-enabled": true,' >> /odysseygo/.odysseygo/configs/node.json
    fi

    if [ "$INDEX_ENABLED" = "true" ]; then
        echo '  "index-enabled": true,' >> /odysseygo/.odysseygo/configs/node.json
    fi

    if [ "$NETWORK" = "testnet" ]; then
        echo '  "network-id": "testnet",' >> /odysseygo/.odysseygo/configs/node.json
    fi

    if [ "$DB_DIR" != "/odysseygo/db" ]; then
        echo "  \"db-dir\": \"$DB_DIR\"," >> /odysseygo/.odysseygo/configs/node.json
    fi

    if [ "$IP_MODE" = "dynamic" ]; then
        echo '  "public-ip-resolution-service": "opendns"' >> /odysseygo/.odysseygo/configs/node.json
    else
        echo "  \"public-ip\": \"$PUBLIC_IP\"" >> /odysseygo/.odysseygo/configs/node.json
    fi

    echo "}" >> /odysseygo/.odysseygo/configs/node.json
}

# Function to create D-Chain config.json
create_dchain_config() {
    local commaAdd=""
    if [ "$ETH_DEBUG_RPC" = "true" ]; then
        commaAdd=","
    fi

    cat <<EOF > /odysseygo/.odysseygo/configs/chains/D/config.json
{
  "log-level": "${LOG_LEVEL_DCHAIN}",
  "eth-apis": [
    "eth",
    "eth-filter",
    "net",
    "web3",
    "internal-eth",
    "internal-blockchain",
    "internal-personal",
    "internal-transaction",
    "internal-account"${commaAdd}
EOF

    if [ "$ETH_DEBUG_RPC" = "true" ]; then
        echo '    "internal-debug",' >> /odysseygo/.odysseygo/configs/chains/D/config.json
        echo '    "debug-tracer"' >> /odysseygo/.odysseygo/configs/chains/D/config.json
    else
        # Remove trailing comma if present
        sed -i '$ s/,$//' /odysseygo/.odysseygo/configs/chains/D/config.json
    fi

    echo "  ]," >> /odysseygo/.odysseygo/configs/chains/D/config.json

    commaAdd=""
    if [ "$ARCHIVAL_MODE" = "true" ]; then
        commaAdd=","
    fi

    if [ "$STATE_SYNC" = "on" ]; then
        echo "  \"state-sync-enabled\": true${commaAdd}" >> /odysseygo/.odysseygo/configs/chains/D/config.json
    elif [ "$STATE_SYNC" = "off" ]; then
        echo "  \"state-sync-enabled\": false${commaAdd}" >> /odysseygo/.odysseygo/configs/chains/D/config.json
    fi

    if [ "$ARCHIVAL_MODE" = "true" ]; then
        echo "  \"pruning-enabled\": false" >> /odysseygo/.odysseygo/configs/chains/D/config.json
    fi

    echo "}" >> /odysseygo/.odysseygo/configs/chains/D/config.json
}

# Create configuration files
create_node_config
create_dchain_config

# Construct OdysseyGo command with dynamic arguments
CMD="/odysseygo/odyssey-node/odysseygo"

# Append additional flags based on environment variables
CMD+=" --config-file=/odysseygo/.odysseygo/configs/node.json"

if [ "$RPC_ACCESS" = "public" ]; then
    CMD+=" --http-allowed-hosts=*"
fi

# Add more flags as needed based on configurations
# Example:
# CMD+=" --some-other-flag=value"

# Start OdysseyGo
exec $CMD
