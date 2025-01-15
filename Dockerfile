# Use the official minimal Debian image
FROM debian:bullseye-slim

# Set environment variables for non-interactive installations
ENV DEBIAN_FRONTEND=noninteractive

# Install necessary packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        wget \
        ca-certificates \
        tar \
        gnupg \
        libssl-dev \
        git \
        build-essential \
        && rm -rf /var/lib/apt/lists/*

# Define environment variables for OdysseyGo
ENV ODOMYSGO_VERSION=latest
ENV NETWORK=testnet
ENV RPC_ACCESS=private
ENV STATE_SYNC=off
ENV IP_MODE=static
ENV PUBLIC_IP=""
ENV DB_DIR=/odysseygo/db
ENV LOG_LEVEL_NODE=info
ENV LOG_LEVEL_DCHAIN=info
ENV INDEX_ENABLED=false
ENV ARCHIVAL_MODE=false
ENV ADMIN_API=false
ENV ETH_DEBUG_RPC=false

# Create necessary directories
RUN mkdir -p /odysseygo/odyssey-node /odysseygo/.odysseygo/configs/chains/D /odysseygo/.odysseygo/plugins

# Set working directory
WORKDIR /odysseygo

# Download or build OdysseyGo
RUN if [ "$ODOMYSGO_VERSION" = "latest" ]; then \
        ARCH=$(dpkg --print-architecture | awk '{ if ($1=="amd64") print "amd64"; else if ($1=="arm64") print "arm64"; else exit 1 }') && \
        wget -q "https://github.com/DioneProtocol/odysseygo/releases/latest/download/odysseygo-linux-$ARCH-latest.tar.gz" -O odysseygo.tar.gz && \
        tar -xzf odysseygo.tar.gz -C odysseygo-node --strip-components=1 && \
        rm odysseygo.tar.gz; \
    else \
        ARCH=$(dpkg --print-architecture | awk '{ if ($1=="amd64") print "amd64"; else if ($1=="arm64") print "arm64"; else exit 1 }') && \
        echo "https://github.com/DioneProtocol/odysseygo/releases/download/v$ODOMYSGO_VERSION/odysseygo-linux-$ARCH-$ODOMYSGO_VERSION.tar.gz" && \
        wget -q "https://github.com/DioneProtocol/odysseygo/releases/download/v$ODOMYSGO_VERSION/odysseygo-linux-$ARCH-$ODOMYSGO_VERSION.tar.gz" -O odysseygo.tar.gz && \
        tar -xzf odysseygo.tar.gz -C odysseygo-node --strip-components=1 && \
        rm odysseygo.tar.gz; \
    fi


# Optional: If you prefer building from source when a specific version is not available
# Uncomment the following block if building from source is desired
# RUN if [ "$ODOMYSGO_VERSION" != "latest" ]; then \
#         git clone https://github.com/DioneProtocol/odysseygo.git && \
#         cd odysseygo && \
#         git checkout "$ODOMYSGO_VERSION" && \
#         ./scripts/build.sh && \
#         cp ./build/* /odysseygo/odyssey-node/ && \
#         cd .. && \
#         rm -rf odysseygo; \
#     fi

# Copy entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Expose necessary ports
# Adjust ports as needed based on OdysseyGo's requirements
EXPOSE 9650 9651

# Define volumes for persistent data
VOLUME ["/odysseygo/.odysseygo", "/odysseygo/odyssey-node"]

# Set the entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
