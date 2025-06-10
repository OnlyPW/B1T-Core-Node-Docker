#!/bin/bash

# B1T Core Node - Simple Docker Setup Script
# This script installs Docker (if needed) and builds/starts the project

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is installed
check_docker() {
    if command -v docker &> /dev/null; then
        log_success "Docker is already installed: $(docker --version)"
        return 0
    else
        return 1
    fi
}

# Install Docker
install_docker() {
    log_info "Installing Docker..."
    
    # Detect OS
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
    else
        log_error "Cannot detect operating system"
        exit 1
    fi
    
    case $OS in
        "debian"|"ubuntu")
            # Update package index
            sudo apt-get update
            
            # Install required packages
            sudo apt-get install -y \
                ca-certificates \
                curl \
                gnupg \
                lsb-release
            
            # Add Docker's official GPG key
            sudo mkdir -p /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/$OS/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            
            # Set up the repository
            echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS \
                $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            # Install Docker Engine
            sudo apt-get update
            sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            
            # Start and enable Docker
            sudo systemctl start docker
            sudo systemctl enable docker
            
            # Add current user to docker group
            sudo usermod -aG docker $USER
            
            log_success "Docker installed successfully"
            ;;
        "centos"|"rhel"|"fedora")
            # Install Docker on CentOS/RHEL/Fedora
            sudo yum install -y yum-utils
            sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            
            sudo systemctl start docker
            sudo systemctl enable docker
            sudo usermod -aG docker $USER
            
            log_success "Docker installed successfully"
            ;;
        *)
            log_error "Unsupported operating system: $OS"
            log_info "Please install Docker manually: https://docs.docker.com/get-docker/"
            exit 1
            ;;
    esac
}

# Configure RPC access for external connections
configure_rpc_access() {
    log_info "Configuring RPC access for external connections..."
    
    # Wait for container to be fully started
    sleep 5
    
    # Get server's external IP (optional)
    EXTERNAL_IP=$(curl -s ifconfig.me 2>/dev/null || echo "")
    
    # Add localhost access
    log_info "Adding localhost access..."
    docker exec b1t-core-node bash -c "echo 'rpcallowip=127.0.0.1/32' >> /home/b1t/.b1t/b1t.conf" 2>/dev/null || true
    
    # Add external IP if detected
    if [[ -n "$EXTERNAL_IP" ]]; then
        log_info "Adding external IP access: $EXTERNAL_IP"
        docker exec b1t-core-node bash -c "echo 'rpcallowip=$EXTERNAL_IP/32' >> /home/b1t/.b1t/b1t.conf" 2>/dev/null || true
    fi
    
    # Ask user if they want to allow all IPs (less secure)
    echo
    echo -e "${YELLOW}=== RPC Access Configuration ===${NC}"
    echo -e "${BLUE}Current configuration allows:${NC}"
    echo -e "- Localhost (127.0.0.1)"
    if [[ -n "$EXTERNAL_IP" ]]; then
        echo -e "- Your external IP ($EXTERNAL_IP)"
    fi
    echo
    echo -e "${RED}WARNING: Allowing all IPs (0.0.0.0/0) is less secure!${NC}"
    read -p "Do you want to allow RPC access from ALL IPs? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_warning "Adding access for all IPs (0.0.0.0/0) - SECURITY RISK!"
        docker exec b1t-core-node bash -c "echo 'rpcallowip=0.0.0.0/0' >> /home/b1t/.b1t/b1t.conf" 2>/dev/null || true
    fi
    
    # Restart container to apply changes
    log_info "Restarting container to apply RPC configuration..."
    if command -v docker-compose &> /dev/null; then
        docker-compose restart b1t-core
    else
        docker compose restart b1t-core
    fi
    
    # Wait for restart
    sleep 10
    
    log_success "RPC access configuration completed!"
}

# Check if Docker Compose is available
check_docker_compose() {
    if command -v docker-compose &> /dev/null; then
        log_success "Docker Compose is available: $(docker-compose --version)"
        return 0
    elif docker compose version &> /dev/null; then
        log_success "Docker Compose (plugin) is available: $(docker compose version)"
        return 0
    else
        return 1
    fi
}

# Install Docker Compose (standalone)
install_docker_compose() {
    log_info "Installing Docker Compose..."
    
    # Download and install Docker Compose
    DOCKER_COMPOSE_VERSION="2.24.0"
    sudo curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    log_success "Docker Compose installed successfully"
}

# Create required directories
create_directories() {
    log_info "Creating required directories..."
    
    # Create data directory
    if [[ ! -d "data" ]]; then
        mkdir -p data
        log_success "Created data directory"
    else
        log_info "Data directory already exists"
    fi
    
    # Create logs directory
    if [[ ! -d "logs" ]]; then
        mkdir -p logs
        log_success "Created logs directory"
    else
        log_info "Logs directory already exists"
    fi
}

# Create .env file if it doesn't exist
setup_environment() {
    log_info "Setting up environment..."
    
    if [[ ! -f ".env" ]]; then
        if [[ -f ".env.example" ]]; then
            cp .env.example .env
            log_success "Created .env file from .env.example"
            
            # Generate a random password
            if command -v openssl &> /dev/null; then
                RANDOM_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
                sed -i "s/RPC_PASSWORD=.*/RPC_PASSWORD=$RANDOM_PASSWORD/" .env
                log_info "Generated random RPC password"
            fi
        else
            log_warning ".env.example not found, creating basic .env file"
            cat > .env << EOF
# B1T Core Node Configuration
RPC_USER=b1tuser
RPC_PASSWORD=change_this_secure_password_123
RPC_PORT=33318
P2P_PORT=33317
DEBUG_LEVEL=1
TX_INDEX=1
ADDRESS_INDEX=1
ENABLE_WALLET=1
DISABLE_WALLET=0
DB_CACHE=512
MAX_MEMPOOL=300
DATA_DIR=./data
EOF
            log_success "Created basic .env file"
        fi
    else
        log_info ".env file already exists"
    fi
}

# Build and start the project
build_and_start() {
    log_info "Building Docker images..."
    
    # Use docker-compose or docker compose based on availability
    if command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    else
        COMPOSE_CMD="docker compose"
    fi
    
    # Build the images
    $COMPOSE_CMD build
    log_success "Docker images built successfully"
    
    # Start the containers
    log_info "Starting B1T Core Node..."
    $COMPOSE_CMD up -d
    
    # Wait a moment for containers to start
    sleep 5
    
    # Check if containers are running
    if $COMPOSE_CMD ps | grep -q "Up"; then
        log_success "B1T Core Node started successfully!"
        
        echo
        echo -e "${GREEN}=== B1T Core Node Status ===${NC}"
        $COMPOSE_CMD ps
        
        # Check node status after 15 seconds
        echo
        log_info "Waiting 15 seconds before checking node status..."
        sleep 15
        
        echo -e "${BLUE}=== Node Status Check (15s) ===${NC}"
        if docker exec b1t-core-node b1t-cli getblockchaininfo 2>/dev/null; then
            log_success "Node is responding to CLI commands after 15 seconds"
        else
            log_warning "Node not yet responding to CLI commands after 15 seconds"
            echo "Container logs:"
            $COMPOSE_CMD logs --tail=10 b1t-core
        fi
        
        # Check node status after 30 seconds total
        echo
        log_info "Waiting additional 15 seconds (30s total) for final status check..."
        sleep 15
        
        echo -e "${BLUE}=== Final Node Status Check (30s) ===${NC}"
        if docker exec b1t-core-node b1t-cli getblockchaininfo 2>/dev/null; then
            log_success "Node is fully operational!"
            
            echo
            echo -e "${GREEN}=== Node Information ===${NC}"
            echo -e "${BLUE}Blockchain Info:${NC}"
            docker exec b1t-core-node b1t-cli getblockchaininfo 2>/dev/null || echo "Unable to get blockchain info"
            
            echo
            echo -e "${BLUE}Network Info:${NC}"
            docker exec b1t-core-node b1t-cli getnetworkinfo 2>/dev/null || echo "Unable to get network info"
            
            echo
            echo -e "${BLUE}Peer Connections:${NC}"
            PEER_COUNT=$(docker exec b1t-core-node b1t-cli getconnectioncount 2>/dev/null || echo "0")
            echo "Connected peers: $PEER_COUNT"
            
        else
            log_warning "Node still not responding after 30 seconds"
            echo "This might be normal for initial sync. Check logs for details:"
            $COMPOSE_CMD logs --tail=20 b1t-core
        fi
        
        # Configure RPC access for external connections
        configure_rpc_access
        
        echo
        echo -e "${GREEN}=== Useful Commands ===${NC}"
        echo -e "${BLUE}View logs:${NC} $COMPOSE_CMD logs -f"
        echo -e "${BLUE}Stop node:${NC} $COMPOSE_CMD down"
        echo -e "${BLUE}Restart node:${NC} $COMPOSE_CMD restart"
        echo -e "${BLUE}Check status:${NC} $COMPOSE_CMD ps"
        echo -e "${BLUE}CLI access:${NC} docker exec -it b1t-core-node b1t-cli help"
        
        echo
        echo -e "${YELLOW}=== RPC Access Credentials ===${NC}"
        if [[ -f ".env" ]]; then
            RPC_USER=$(grep "^RPC_USER=" .env | cut -d'=' -f2)
            RPC_PASSWORD=$(grep "^RPC_PASSWORD=" .env | cut -d'=' -f2)
            RPC_PORT=$(grep "^RPC_PORT=" .env | cut -d'=' -f2)
            echo -e "${BLUE}RPC Username:${NC} $RPC_USER"
            echo -e "${BLUE}RPC Password:${NC} $RPC_PASSWORD"
            echo -e "${BLUE}RPC Port:${NC} $RPC_PORT"
            echo -e "${BLUE}RPC URL:${NC} http://localhost:$RPC_PORT"
        else
            echo -e "${RED}Could not read .env file${NC}"
        fi
        
        echo
        echo -e "${YELLOW}=== Important Notes ===${NC}"
        echo -e "1. Save the RPC credentials above - they are randomly generated"
        echo -e "2. The node data is stored in the ./data directory"
        echo -e "3. RPC is available on port 33318 (default)"
        echo -e "4. P2P is available on port 33317 (default)"
        echo -e "5. Initial blockchain sync may take some time"
        echo -e "6. RPC access has been configured for external connections"
        
    else
        log_error "Failed to start B1T Core Node"
        echo "Container status:"
        $COMPOSE_CMD ps
        echo
        echo "Logs:"
        $COMPOSE_CMD logs
        exit 1
    fi
}

# Clean installation function
clean_install() {
    log_warning "This will remove all existing B1T Core Node containers, volumes, and data!"
    echo -e "${RED}WARNING: This action cannot be undone!${NC}"
    echo
    read -p "Are you sure you want to proceed with clean installation? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Clean installation cancelled"
        return 1
    fi
    
    log_info "Performing clean installation..."
    
    # Use docker-compose or docker compose based on availability
    if command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    else
        COMPOSE_CMD="docker compose"
    fi
    
    # Stop and remove containers
    log_info "Stopping and removing containers..."
    $COMPOSE_CMD down --remove-orphans --volumes 2>/dev/null || true
    
    # Remove specific containers if they exist
    if docker ps -a --format "table {{.Names}}" | grep -q "b1t-core-node"; then
        log_info "Removing b1t-core-node container..."
        docker rm -f b1t-core-node 2>/dev/null || true
    fi
    
    # Remove volumes
    log_info "Removing Docker volumes..."
    docker volume rm b1t-core-node-docker_b1t_data 2>/dev/null || true
    docker volume rm $(docker volume ls -q | grep b1t) 2>/dev/null || true
    
    # Remove networks
    log_info "Removing Docker networks..."
    docker network rm b1t-core-node-docker_b1t_network 2>/dev/null || true
    docker network rm $(docker network ls -q | grep b1t) 2>/dev/null || true
    
    # Remove images
    log_info "Removing Docker images..."
    docker rmi b1t-core-node:latest 2>/dev/null || true
    docker rmi $(docker images | grep b1t | awk '{print $3}') 2>/dev/null || true
    
    # Remove local directories
    log_info "Removing local data directories..."
    if [[ -d "data" ]]; then
        rm -rf data
        log_success "Removed data directory"
    fi
    
    if [[ -d "logs" ]]; then
        rm -rf logs
        log_success "Removed logs directory"
    fi
    
    # Remove .env file
    if [[ -f ".env" ]]; then
        rm -f .env
        log_success "Removed .env file"
    fi
    
    log_success "Clean installation completed!"
    return 0
}

# Main function
main() {
    echo -e "${GREEN}=== B1T Core Node - Docker Setup ===${NC}"
    echo -e "${BLUE}This script will install Docker (if needed) and build/start the B1T Core Node${NC}"
    echo
    
    # Check if we're in the right directory
    if [[ ! -f "docker-compose.yml" ]]; then
        log_error "docker-compose.yml not found in current directory"
        log_info "Please run this script from the B1T-Core-Node directory"
        exit 1
    fi
    
    # Ask for clean installation if Docker containers/volumes exist
    if docker ps -a --format "table {{.Names}}" | grep -q "b1t-core-node" || docker volume ls | grep -q "b1t"; then
        echo -e "${YELLOW}Existing B1T Core Node installation detected!${NC}"
        echo
        read -p "Do you want to perform a clean installation? This will remove all existing data! (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if ! clean_install; then
                exit 1
            fi
        else
            log_info "Continuing with existing installation..."
        fi
    fi
    
    # Check and install Docker if needed
    if ! check_docker; then
        log_warning "Docker is not installed"
        read -p "Do you want to install Docker? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_docker
            
            log_warning "You may need to log out and back in for Docker group membership to take effect"
            log_info "Alternatively, you can run: newgrp docker"
        else
            log_error "Docker is required to run this project"
            exit 1
        fi
    fi
    
    # Check Docker Compose
    if ! check_docker_compose; then
        log_warning "Docker Compose is not available"
        read -p "Do you want to install Docker Compose? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_docker_compose
        else
            log_error "Docker Compose is required to run this project"
            exit 1
        fi
    fi
    
    # Create required directories
    create_directories
    
    # Setup environment
    setup_environment
    
    # Build and start
    build_and_start
    
    log_success "Setup completed successfully!"
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "B1T Core Node - Docker Setup Script"
        echo "Usage: $0 [options]"
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --check        Check if Docker is installed"
        echo "  --build-only   Only build, don't start"
        echo "  --start-only   Only start (assumes already built)"
        echo "  --clean        Perform clean installation (remove all existing data)"
        exit 0
        ;;
    --check)
        log_info "Checking Docker installation..."
        check_docker && log_success "Docker: OK" || log_warning "Docker: Not installed"
        check_docker_compose && log_success "Docker Compose: OK" || log_warning "Docker Compose: Not available"
        exit 0
        ;;
    --build-only)
        setup_environment
        if command -v docker-compose &> /dev/null; then
            docker-compose build
        else
            docker compose build
        fi
        log_success "Build completed"
        exit 0
        ;;
    --start-only)
        create_directories
        if command -v docker-compose &> /dev/null; then
            docker-compose up -d
        else
            docker compose up -d
        fi
        log_success "Started successfully"
        exit 0
        ;;
    --clean)
        clean_install
        if [[ $? -eq 0 ]]; then
            log_info "Proceeding with fresh installation..."
            main
        fi
        exit 0
        ;;
    "")
        main
        ;;
    *)
        log_error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac
