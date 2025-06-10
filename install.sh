#!/bin/bash

# B1T Core Node Auto-Setup Script
# Supports: Debian 12, Ubuntu 20.04+
# Author: B1T Core Team
# License: MIT

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
B1T_USER="b1t"
B1T_HOME="/opt/b1t-core"
B1T_DATA="/var/lib/b1t"
B1T_LOGS="/var/log/b1t"
DOCKER_COMPOSE_VERSION="2.24.0"
NODE_VERSION="18"

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

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
        log_info "Detected OS: $PRETTY_NAME"
    else
        log_error "Cannot detect operating system"
        exit 1
    fi

    case $OS in
        "debian")
            if [[ "$VERSION" != "12" ]]; then
                log_warning "This script is optimized for Debian 12. Your version: $VERSION"
                read -p "Continue anyway? (y/N): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    exit 1
                fi
            fi
            PACKAGE_MANAGER="apt"
            ;;
        "ubuntu")
            if [[ $(echo "$VERSION >= 20.04" | bc -l) -ne 1 ]]; then
                log_warning "This script requires Ubuntu 20.04 or newer. Your version: $VERSION"
                exit 1
            fi
            PACKAGE_MANAGER="apt"
            ;;
        *)
            log_error "Unsupported operating system: $OS"
            log_info "Supported: Debian 12, Ubuntu 20.04+"
            exit 1
            ;;
    esac
}

update_system() {
    log_info "Updating system packages..."
    $PACKAGE_MANAGER update -y
    $PACKAGE_MANAGER upgrade -y
    
    log_info "Installing essential packages..."
    $PACKAGE_MANAGER install -y \
        curl \
        wget \
        gnupg \
        lsb-release \
        ca-certificates \
        software-properties-common \
        apt-transport-https \
        git \
        unzip \
        jq \
        bc \
        htop \
        nano \
        vim
}

check_docker() {
    if command -v docker &> /dev/null; then
        log_info "Docker is already installed"
        docker --version
        return 0
    else
        return 1
    fi
}

install_docker() {
    if check_docker; then
        log_success "Docker is already installed"
        return 0
    fi

    log_info "Installing Docker..."
    
    # Remove old versions
    $PACKAGE_MANAGER remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/$OS/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$OS $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    $PACKAGE_MANAGER update -y
    $PACKAGE_MANAGER install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    # Add current user to docker group if not root
    if [[ -n "$SUDO_USER" ]]; then
        usermod -aG docker $SUDO_USER
        log_info "Added $SUDO_USER to docker group"
    fi
    
    log_success "Docker installed successfully"
    docker --version
}

check_docker_compose() {
    if command -v docker-compose &> /dev/null; then
        log_info "Docker Compose is already installed"
        docker-compose --version
        return 0
    else
        return 1
    fi
}

install_docker_compose() {
    if check_docker_compose; then
        log_success "Docker Compose is already installed"
        return 0
    fi

    log_info "Installing Docker Compose..."
    
    # Download and install Docker Compose
    curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    # Create symlink for easier access
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    log_success "Docker Compose installed successfully"
    docker-compose --version
}

install_nodejs() {
    if command -v node &> /dev/null; then
        NODE_CURRENT=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
        if [[ $NODE_CURRENT -ge $NODE_VERSION ]]; then
            log_success "Node.js $NODE_CURRENT is already installed"
            return 0
        fi
    fi

    log_info "Installing Node.js $NODE_VERSION..."
    
    # Add NodeSource repository
    curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -
    
    # Install Node.js
    $PACKAGE_MANAGER install -y nodejs
    
    log_success "Node.js installed successfully"
    node --version
    npm --version
}

create_user() {
    if id "$B1T_USER" &>/dev/null; then
        log_info "User $B1T_USER already exists"
    else
        log_info "Creating user $B1T_USER..."
        useradd -r -s /bin/bash -d $B1T_HOME -m $B1T_USER
        usermod -aG docker $B1T_USER
        log_success "User $B1T_USER created"
    fi
}

create_directories() {
    log_info "Creating directories..."
    
    # Create main directories
    mkdir -p $B1T_HOME
    mkdir -p $B1T_DATA
    mkdir -p $B1T_LOGS
    mkdir -p $B1T_HOME/backups
    mkdir -p /etc/b1t
    
    # Set permissions
    chown -R $B1T_USER:$B1T_USER $B1T_HOME
    chown -R $B1T_USER:$B1T_USER $B1T_DATA
    chown -R $B1T_USER:$B1T_USER $B1T_LOGS
    
    chmod 755 $B1T_HOME
    chmod 700 $B1T_DATA
    chmod 755 $B1T_LOGS
    
    log_success "Directories created and configured"
}

download_project() {
    log_info "Downloading B1T Core Node project..."
    
    cd $B1T_HOME
    
    # Check if project already exists
    if [[ -d "B1T-Core-Node" ]]; then
        log_warning "Project directory already exists"
        read -p "Remove existing directory and re-download? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf B1T-Core-Node
        else
            log_info "Using existing project directory"
            return 0
        fi
    fi
    
    # Clone or download project
    if command -v git &> /dev/null; then
        log_info "Cloning from Git repository..."
        # Replace with actual repository URL when available
        # git clone https://github.com/your-repo/B1T-Core-Node.git
        
        # For now, create the structure manually
        mkdir -p B1T-Core-Node
        log_warning "Git repository not yet available. Please manually copy the project files to $B1T_HOME/B1T-Core-Node/"
    else
        log_warning "Git not available. Please manually copy the project files to $B1T_HOME/B1T-Core-Node/"
        mkdir -p B1T-Core-Node
    fi
    
    chown -R $B1T_USER:$B1T_USER $B1T_HOME/B1T-Core-Node
    
    log_success "Project downloaded"
}

configure_environment() {
    log_info "Configuring environment..."
    
    cd $B1T_HOME/B1T-Core-Node
    
    # Copy environment template if it exists
    if [[ -f ".env.example" ]]; then
        if [[ ! -f ".env" ]]; then
            cp .env.example .env
            log_info "Created .env file from template"
        else
            log_info ".env file already exists"
        fi
    fi
    
    # Generate random passwords
    RPC_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    
    # Update .env file if it exists
    if [[ -f ".env" ]]; then
        sed -i "s/RPC_PASSWORD=.*/RPC_PASSWORD=$RPC_PASSWORD/" .env
        sed -i "s|DATA_DIR=.*|DATA_DIR=$B1T_DATA|" .env
        sed -i "s|LOG_DIR=.*|LOG_DIR=$B1T_LOGS|" .env
        log_info "Updated .env configuration"
    fi
    
    # Set file permissions
    chmod 600 .env 2>/dev/null || true
    chown $B1T_USER:$B1T_USER .env 2>/dev/null || true
    
    log_success "Environment configured"
}

install_dependencies() {
    log_info "Installing Node.js dependencies..."
    
    cd $B1T_HOME/B1T-Core-Node
    
    if [[ -f "package.json" ]]; then
        sudo -u $B1T_USER npm install
        log_success "Dependencies installed"
    else
        log_warning "package.json not found, skipping npm install"
    fi
}

create_systemd_service() {
    log_info "Creating systemd service..."
    
    cat > /etc/systemd/system/b1t-core.service << EOF
[Unit]
Description=B1T Core Node
After=docker.service
Requires=docker.service

[Service]
Type=forking
User=$B1T_USER
Group=$B1T_USER
WorkingDirectory=$B1T_HOME/B1T-Core-Node
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
ExecReload=/usr/local/bin/docker-compose restart
Restart=always
RestartSec=10

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$B1T_DATA $B1T_LOGS $B1T_HOME

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable b1t-core.service
    
    log_success "Systemd service created and enabled"
}

create_logrotate() {
    log_info "Setting up log rotation..."
    
    cat > /etc/logrotate.d/b1t-core << EOF
$B1T_LOGS/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 $B1T_USER $B1T_USER
    postrotate
        systemctl reload b1t-core.service > /dev/null 2>&1 || true
    endscript
}
EOF

    log_success "Log rotation configured"
}

setup_firewall() {
    log_info "Configuring firewall..."
    
    if command -v ufw &> /dev/null; then
        # Allow SSH
        ufw allow ssh
        
        # Allow B1T Core ports (adjust as needed)
        ufw allow 33317/tcp comment 'B1T Core P2P'
        ufw allow 33318/tcp comment 'B1T Core RPC'
        
        # Enable firewall if not already enabled
        ufw --force enable
        
        log_success "UFW firewall configured"
    elif command -v firewall-cmd &> /dev/null; then
        # For systems with firewalld
        firewall-cmd --permanent --add-port=33317/tcp
        firewall-cmd --permanent --add-port=33318/tcp
        firewall-cmd --reload
        
        log_success "Firewalld configured"
    else
        log_warning "No firewall detected. Please manually configure firewall rules:"
        log_warning "  - Allow port 33317/tcp (P2P)"
        log_warning "  - Allow port 33318/tcp (RPC)"
    fi
}

create_management_scripts() {
    log_info "Creating management scripts..."
    
    # Create b1t-cli script
    cat > /usr/local/bin/b1t-cli << 'EOF'
#!/bin/bash
cd /opt/b1t-core/B1T-Core-Node
sudo -u b1t docker-compose exec b1t-core b1t-cli "$@"
EOF
    chmod +x /usr/local/bin/b1t-cli
    
    # Create b1t-logs script
    cat > /usr/local/bin/b1t-logs << 'EOF'
#!/bin/bash
cd /opt/b1t-core/B1T-Core-Node
sudo -u b1t docker-compose logs -f "$@"
EOF
    chmod +x /usr/local/bin/b1t-logs
    
    # Create b1t-status script
    cat > /usr/local/bin/b1t-status << 'EOF'
#!/bin/bash
echo "=== B1T Core Node Status ==="
systemctl status b1t-core.service
echo
echo "=== Docker Containers ==="
cd /opt/b1t-core/B1T-Core-Node
sudo -u b1t docker-compose ps
echo
echo "=== Node Info ==="
b1t-cli getinfo 2>/dev/null || echo "Node not responding"
EOF
    chmod +x /usr/local/bin/b1t-status
    
    log_success "Management scripts created"
}

run_initial_setup() {
    log_info "Running initial setup..."
    
    cd $B1T_HOME/B1T-Core-Node
    
    # Run setup script if available
    if [[ -f "scripts/setup.js" ]]; then
        sudo -u $B1T_USER node scripts/setup.js --auto
    fi
    
    # Build Docker images
    if [[ -f "docker-compose.yml" ]]; then
        sudo -u $B1T_USER docker-compose build
        log_success "Docker images built"
    fi
}

show_completion_message() {
    log_success "B1T Core Node installation completed!"
    echo
    echo -e "${GREEN}=== Installation Summary ===${NC}"
    echo -e "${BLUE}Installation Directory:${NC} $B1T_HOME/B1T-Core-Node"
    echo -e "${BLUE}Data Directory:${NC} $B1T_DATA"
    echo -e "${BLUE}Log Directory:${NC} $B1T_LOGS"
    echo -e "${BLUE}User:${NC} $B1T_USER"
    echo
    echo -e "${GREEN}=== Management Commands ===${NC}"
    echo -e "${BLUE}Start node:${NC} systemctl start b1t-core"
    echo -e "${BLUE}Stop node:${NC} systemctl stop b1t-core"
    echo -e "${BLUE}Restart node:${NC} systemctl restart b1t-core"
    echo -e "${BLUE}Check status:${NC} b1t-status"
    echo -e "${BLUE}View logs:${NC} b1t-logs"
    echo -e "${BLUE}CLI access:${NC} b1t-cli getinfo"
    echo
    echo -e "${GREEN}=== Next Steps ===${NC}"
    echo -e "1. Review configuration: ${BLUE}nano $B1T_HOME/B1T-Core-Node/.env${NC}"
    echo -e "2. Start the node: ${BLUE}systemctl start b1t-core${NC}"
    echo -e "3. Check status: ${BLUE}b1t-status${NC}"
    echo -e "4. Monitor logs: ${BLUE}b1t-logs${NC}"
    echo
    echo -e "${YELLOW}Note:${NC} If you're not root, you may need to log out and back in for Docker group membership to take effect."
    echo
    echo -e "${GREEN}=== Security Recommendations ===${NC}"
    echo -e "1. Change default RPC password in .env file"
    echo -e "2. Configure firewall rules for your network"
    echo -e "3. Set up regular backups"
    echo -e "4. Monitor system resources and logs"
    echo
}

# Main installation process
main() {
    echo -e "${GREEN}=== B1T Core Node Auto-Setup ===${NC}"
    echo -e "${BLUE}Supported Systems:${NC} Debian 12, Ubuntu 20.04+"
    echo
    
    check_root
    detect_os
    
    log_info "Starting installation process..."
    
    update_system
    install_docker
    install_docker_compose
    install_nodejs
    create_user
    create_directories
    download_project
    configure_environment
    install_dependencies
    create_systemd_service
    create_logrotate
    setup_firewall
    create_management_scripts
    run_initial_setup
    
    show_completion_message
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "B1T Core Node Auto-Setup Script"
        echo "Usage: $0 [options]"
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --version, -v  Show version information"
        echo "  --check        Check system requirements"
        exit 0
        ;;
    --version|-v)
        echo "B1T Core Node Auto-Setup v1.0.0"
        exit 0
        ;;
    --check)
        log_info "Checking system requirements..."
        detect_os
        check_docker && log_success "Docker: OK" || log_warning "Docker: Not installed"
        check_docker_compose && log_success "Docker Compose: OK" || log_warning "Docker Compose: Not installed"
        command -v node &> /dev/null && log_success "Node.js: $(node --version)" || log_warning "Node.js: Not installed"
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