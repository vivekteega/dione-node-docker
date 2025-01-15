#!/bin/bash
set -e

# Function to validate IP address
validate_ip() {
    local ip=$1
    local stat=1

    if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

# Function to create node.json using jq for safer JSON construction
create_node_config() {
    local config_path="/odysseygo/.odysseygo/configs/node.json"
    mkdir -p "$(dirname "$config_path")"

    # Start building the JSON configuration
    jq -n \
        --arg log_level "$LOG_LEVEL_NODE" \
        --arg network "$NETWORK" \
        --arg rpc_access "$RPC_ACCESS" \
        --arg db_dir "$DB_DIR" \
        --arg ip_mode "$IP_MODE" \
        --arg public_ip "$PUBLIC_IP" \
        --argjson index_enabled "$INDEX_ENABLED" \
        --argjson admin_api "$ADMIN_API" \
        '{
            "log-level": $log_level,
            "network-id": ($network // "mainnet"),
            "db-dir": $db_dir,
            "index-enabled": $index_enabled,
            "api-admin-enabled": $admin_api
        }' > "$config_path"

    # Add HTTP allowed hosts if RPC_ACCESS is public
    if [ "$RPC_ACCESS" = "public" ]; then
        jq '. + { "http-allowed-hosts": "*" }' "$config_path" > "${config_path}.tmp" && mv "${config_path}.tmp" "$config_path"
    fi

    # Add public IP or dynamic resolution
    if [ "$IP_MODE" = "static" ]; then
        if validate_ip "$PUBLIC_IP"; then
            jq --arg public_ip "$PUBLIC_IP" '. + { "public-ip": $public_ip }' "$config_path" > "${config_path}.tmp" && mv "${config_path}.tmp" "$config_path"
        else
            echo "Invalid PUBLIC_IP provided. Exiting."
            exit 1
        fi
    elif [ "$IP_MODE" = "dynamic" ]; then
        jq '. + { "public-ip-resolution-service": "opendns" }' "$config_path" > "${config_path}.tmp" && mv "${config_path}.tmp" "$config_path"
    fi
}

# Function to create D-Chain config.json using jq
create_dchain_config() {
    local config_path="/odysseygo/.odysseygo/configs/chains/D/config.json"
    mkdir -p "$(dirname "$config_path")"

    # Start building the JSON configuration
    jq -n \
        --arg log_level_dchain "$LOG_LEVEL_DCHAIN" \
        --argjson eth_debug_rpc "$ETH_DEBUG_RPC" \
        --argjson state_sync_enabled "$( [ "$STATE_SYNC" = "on" ] && echo "true" || echo "false" )" \
        --argjson pruning_enabled "$( [ "$ARCHIVAL_MODE" = "true" ] && echo "false" || echo "null" )" \
        '{
            "log-level": $log_level_dchain,
            "eth-apis": [
                "eth",
                "eth-filter",
                "net",
                "web3",
                "internal-eth",
                "internal-blockchain",
                "internal-personal",
                "internal-transaction",
                "internal-account"
            ],
            "state-sync-enabled": $state_sync_enabled
        }' > "$config_path"

    # Append debug APIs if ETH_DEBUG_RPC is true
    if [ "$ETH_DEBUG_RPC" = "true" ]; then
        jq '.["eth-apis"] += ["internal-debug", "debug-tracer"]' "$config_path" > "${config_path}.tmp" && mv "${config_path}.tmp" "$config_path"
    fi

    # Add pruning if archival mode is enabled
    if [ "$ARCHIVAL_MODE" = "true" ]; then
        jq '. + { "pruning-enabled": false }' "$config_path" > "${config_path}.tmp" && mv "${config_path}.tmp" "$config_path"
    fi
}

# Function to display usage
usage() {
    echo "Usage: docker run [OPTIONS] your-image
Options:
    -e NETWORK=testnet|mainnet
    -e RPC_ACCESS=public|private
    -e STATE_SYNC=on|off
    -e IP_MODE=dynamic|static
    -e PUBLIC_IP=your_public_ip
    -e DB_DIR=/path/to/db
    -e LOG_LEVEL_NODE=info|debug
    -e LOG_LEVEL_DCHAIN=info|debug
    -e INDEX_ENABLED=true|false
    -e ARCHIVAL_MODE=true|false
    -e ADMIN_API=true|false
    -e ETH_DEBUG_RPC=true|false
    -v /host/path/.odysseygo:/odysseygo/.odysseygo
    -v /host/path/odyssey-node:/odysseygo/odyssey-node
    -v /host/path/db:/odysseygo/db
    --network your_network
    --restart unless-stopped
    ..."
    exit 1
}

# Handle help flag
if [[ "$1" == "--help" ]]; then
    usage
fi

# Create configuration files
create_node_config
create_dchain_config

# Construct OdysseyGo command with dynamic arguments
CMD="/odysseygo/odyssey-node/odysseygo"

# Append additional flags based on environment variables
CMD+=" --config-file=/odysseygo/.odysseygo/configs/node.json"

# Example of adding more flags if needed
# CMD+=" --another-flag=value"

# Ensure the DB directory exists
mkdir -p "$DB_DIR"

# Start OdysseyGo and redirect logs to stdout
exec "$CMD" --log-dir=/var/log/odysseygo
