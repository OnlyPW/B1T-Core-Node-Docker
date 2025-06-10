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
        
        echo
        echo -e "${GREEN}=== Useful Commands ===${NC}"
        echo -e "${BLUE}View logs:${NC} $COMPOSE_CMD logs -f"
        echo -e "${BLUE}Stop node:${NC} $COMPOSE_CMD down"
        echo -e "${BLUE}Restart node:${NC} $COMPOSE_CMD restart"
        echo -e "${BLUE}Check status:${NC} $COMPOSE_CMD ps"
        
        echo
        echo -e "${YELLOW}=== Important Notes ===${NC}"
        echo -e "1. Change the default RPC password in the .env file"
        echo -e "2. The node data is stored in the ./data directory"
        echo -e "3. RPC is available on port 33318 (default)"
        echo -e "4. P2P is available on port 33317 (default)"
        
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
        if command -v docker-compose &> /dev/null; then
            docker-compose up -d
        else
            docker compose up -d
        fi
        log_success "Started successfully"
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
