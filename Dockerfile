# B1T Core Node - Standalone Docker Image
# Optimized for production use with enhanced security and monitoring

FROM ubuntu:22.04

# Metadata
LABEL maintainer="B1T Core Team"
LABEL description="B1T Core Node - Standalone Blockchain Node"
LABEL version="2.1.0.0"

# Avoid interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    ca-certificates \
    gnupg \
    libboost-system1.74.0 \
    libboost-filesystem1.74.0 \
    libboost-thread1.74.0 \
    libboost-chrono1.74.0 \
    libboost-program-options1.74.0 \
    libssl3 \
    libdb5.3++ \
    libevent-2.1-7 \
    libevent-pthreads-2.1-7 \
    libminiupnpc17 \
    libnatpmp1 \
    libzmq5 \
    gosu \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Create b1t user and group
RUN groupadd -r b1t && \
    useradd -r -g b1t -m -s /bin/bash b1t && \
    mkdir -p /home/b1t/.b1t && \
    chown -R b1t:b1t /home/b1t

# Set working directory
WORKDIR /opt/b1t

# Download and install B1T Core
RUN wget -O b1t-core.tar.gz https://github.com/bittoshimoto/Bit/releases/download/Bit.v.2.1.0.0/Bit.v.2.1.0.0.tar.gz && \
    tar -xzf b1t-core.tar.gz && \
    rm b1t-core.tar.gz && \
    # Find and install binaries with flexible naming
    find . -name "*d" -type f -executable | head -1 | xargs -I {} cp {} /usr/local/bin/b1td 2>/dev/null || true && \
    find . -name "*-cli" -type f -executable | head -1 | xargs -I {} cp {} /usr/local/bin/b1t-cli 2>/dev/null || true && \
    find . -name "*-tx" -type f -executable | head -1 | xargs -I {} cp {} /usr/local/bin/b1t-tx 2>/dev/null || true && \
    # Alternative binary locations
    if [ -f "./bin/b1td" ]; then cp ./bin/b1td /usr/local/bin/; fi && \
    if [ -f "./bin/b1t-cli" ]; then cp ./bin/b1t-cli /usr/local/bin/; fi && \
    if [ -f "./bin/b1t-tx" ]; then cp ./bin/b1t-tx /usr/local/bin/; fi && \
    # Set permissions
    chmod +x /usr/local/bin/b1t* 2>/dev/null || true && \
    # Verify installation
    ls -la /usr/local/bin/b1t* || echo "Checking archive structure..." && \
    find . -type f -executable | grep -E "(bit|b1t)" || ls -la . && \
    # Cleanup
    rm -rf /opt/b1t/*

# Create entrypoint script
RUN cat > /usr/local/bin/docker-entrypoint.sh << 'EOF'
#!/bin/bash
set -e

# Function to generate configuration
generate_config() {
    cat > /home/b1t/.b1t/b1t.conf << CONFEOF
# B1T Core Configuration
# Generated automatically by Docker container

# Basic RPC Settings
server=1
daemon=0
rpcuser=${RPC_USER:-b1tuser}
rpcpassword=${RPC_PASSWORD:-b1tpassword}
rpcport=${RPC_PORT:-33318}
rpcbind=0.0.0.0
rpcbind=[::]

# RPC Access Control
rpcallowip=127.0.0.1
rpcallowip=::1
rpcallowip=172.16.0.0/12
rpcallowip=192.168.0.0/16
rpcallowip=10.0.0.0/8
rpcallowip=2001:db8::/64

# Network Settings
listen=1
bind=0.0.0.0:${P2P_PORT:-33317}
bind=[::]:${P2P_PORT:-33317}
port=${P2P_PORT:-33317}
ipv6=1
upnp=1

# Wallet Settings
wallet=${ENABLE_WALLET:-1}
disablewallet=${DISABLE_WALLET:-0}

# Debugging and Logging
debug=${DEBUG_LEVEL:-1}
printtoconsole=1
logips=1
logtimestamps=1
shrinkdebugfile=1

# Indexing
txindex=${TX_INDEX:-1}
addressindex=${ADDRESS_INDEX:-1}

# Performance
dbcache=${DB_CACHE:-512}
maxmempool=${MAX_MEMPOOL:-300}

# ZMQ (optional)
# zmqpubhashblock=tcp://0.0.0.0:28332
# zmqpubrawtx=tcp://0.0.0.0:28333

# Data Directory
datadir=/home/b1t/.b1t
pidfile=/home/b1t/.b1t/b1td.pid
CONFEOF
    chown b1t:b1t /home/b1t/.b1t/b1t.conf
    chmod 600 /home/b1t/.b1t/b1t.conf
}

# Function to wait for dependencies
wait_for_deps() {
    echo "Waiting for dependencies..."
    # Add any dependency checks here
    sleep 2
}

# Main execution
echo "Starting B1T Core Node..."
echo "Version: $(b1td --version 2>/dev/null || echo 'Unknown')"
echo "User: $(whoami)"
echo "Working Directory: $(pwd)"

# Generate configuration
echo "Generating configuration..."
generate_config

# Wait for dependencies
wait_for_deps

# Change to b1t user and start daemon
echo "Starting B1T daemon..."
if [ "$(id -u)" = "0" ]; then
    # Running as root, switch to b1t user
    exec gosu b1t b1td "$@"
else
    # Already running as b1t user
    exec b1td "$@"
fi
EOF

# Make entrypoint executable
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Create health check script
RUN cat > /usr/local/bin/healthcheck.sh << 'EOF'
#!/bin/bash
# Health check for B1T Core Node

set -e

# Check if daemon is responding
if ! b1t-cli getblockchaininfo >/dev/null 2>&1; then
    echo "Health check failed: b1t-cli not responding"
    exit 1
fi

# Check if we have peers
PEER_COUNT=$(b1t-cli getconnectioncount 2>/dev/null || echo "0")
if [ "$PEER_COUNT" -eq "0" ]; then
    echo "Warning: No peer connections"
    # Don't fail on no peers, just warn
fi

echo "Health check passed: $PEER_COUNT peers connected"
exit 0
EOF

RUN chmod +x /usr/local/bin/healthcheck.sh

# Set up volumes and permissions
VOLUME ["/home/b1t/.b1t"]

# Expose ports
EXPOSE 33317 33318

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh

# Default environment variables
ENV RPC_USER=b1tuser
ENV RPC_PASSWORD=b1tpassword
ENV RPC_PORT=33318
ENV P2P_PORT=33317
ENV DEBUG_LEVEL=1
ENV TX_INDEX=1
ENV ADDRESS_INDEX=1
ENV ENABLE_WALLET=1
ENV DISABLE_WALLET=0
ENV DB_CACHE=512
ENV MAX_MEMPOOL=300

# Switch to b1t user
USER b1t

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Default command
CMD ["-printtoconsole"]