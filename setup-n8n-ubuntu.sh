#!/bin/bash

# n8n Setup Script for Ubuntu 24.04 LTS Server
# This script installs Docker, Docker Compose, and sets up n8n

set -e

echo "🚀 Setting up n8n on Ubuntu 24.04 LTS Server..."

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo "❌ This script should not be run as root for security reasons."
   echo "Please run as a regular user with sudo privileges."
   exit 1
fi

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Update system packages
echo "📦 Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install required packages
echo "📦 Installing required packages..."
sudo apt install -y curl wget gnupg lsb-release ca-certificates software-properties-common

# Install Docker if not already installed
if ! command_exists docker; then
    echo "🐳 Installing Docker..."
    
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Add current user to docker group
    sudo usermod -aG docker $USER
    
    echo "✅ Docker installed successfully"
    echo "⚠️  You may need to log out and back in for Docker group changes to take effect"
else
    echo "✅ Docker is already installed"
fi

# Install Docker Compose standalone if not available
if ! command_exists docker-compose && ! docker compose version >/dev/null 2>&1; then
    echo "🐳 Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo "✅ Docker Compose installed successfully"
else
    echo "✅ Docker Compose is already available"
fi

# Create n8n directory
N8N_DIR="/opt/n8n"
echo "📁 Creating n8n directory at $N8N_DIR..."
sudo mkdir -p $N8N_DIR
sudo chown $USER:$USER $N8N_DIR
cd $N8N_DIR

# Create necessary directories
mkdir -p data local-files

# Get server IP for configuration
SERVER_IP=$(hostname -I | awk '{print $1}')

# Create environment file
echo "⚙️  Creating environment configuration..."
cat > .env << EOF
# n8n Configuration
N8N_HOST=0.0.0.0
N8N_PORT=5678
N8N_PROTOCOL=http

# Database (using SQLite by default - change to PostgreSQL for production)
DB_TYPE=sqlite
DB_SQLITE_DATABASE=/home/node/.n8n/database.sqlite

# Security
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=n8n_password_change_me

# Timezone
GENERIC_TIMEZONE=UTC

# Webhook URL (change this to your domain or server IP)
WEBHOOK_URL=http://$SERVER_IP:5678/

# Executions
EXECUTIONS_PROCESS=main
EXECUTIONS_DATA_SAVE_ON_ERROR=all
EXECUTIONS_DATA_SAVE_ON_SUCCESS=all
EXECUTIONS_DATA_SAVE_MANUAL_EXECUTIONS=true

# Performance
N8N_PAYLOAD_SIZE_MAX=16
NODE_OPTIONS=--max-old-space-size=1024
EOF

# Create docker-compose.yml for production
echo "🐳 Creating Docker Compose configuration..."
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  n8n:
    image: docker.n8n.io/n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      - N8N_HOST=${N8N_HOST:-0.0.0.0}
      - N8N_PORT=${N8N_PORT:-5678}
      - N8N_PROTOCOL=${N8N_PROTOCOL:-http}
      - DB_TYPE=${DB_TYPE:-sqlite}
      - DB_SQLITE_DATABASE=${DB_SQLITE_DATABASE:-/home/node/.n8n/database.sqlite}
      - N8N_BASIC_AUTH_ACTIVE=${N8N_BASIC_AUTH_ACTIVE:-true}
      - N8N_BASIC_AUTH_USER=${N8N_BASIC_AUTH_USER:-admin}
      - N8N_BASIC_AUTH_PASSWORD=${N8N_BASIC_AUTH_PASSWORD:-changeme}
      - WEBHOOK_URL=${WEBHOOK_URL:-http://localhost:5678/}
      - GENERIC_TIMEZONE=${GENERIC_TIMEZONE:-UTC}
      - EXECUTIONS_PROCESS=${EXECUTIONS_PROCESS:-main}
      - EXECUTIONS_DATA_SAVE_ON_ERROR=${EXECUTIONS_DATA_SAVE_ON_ERROR:-all}
      - EXECUTIONS_DATA_SAVE_ON_SUCCESS=${EXECUTIONS_DATA_SAVE_ON_SUCCESS:-all}
      - EXECUTIONS_DATA_SAVE_MANUAL_EXECUTIONS=${EXECUTIONS_DATA_SAVE_MANUAL_EXECUTIONS:-true}
      - N8N_PAYLOAD_SIZE_MAX=${N8N_PAYLOAD_SIZE_MAX:-16}
      - NODE_OPTIONS=${NODE_OPTIONS:---max-old-space-size=1024}
    volumes:
      - ./data:/home/node/.n8n
      - ./local-files:/files
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:5678/healthz"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
EOF

# Create systemd service for auto-start
echo "🔧 Creating systemd service..."
sudo tee /etc/systemd/system/n8n.service > /dev/null << EOF
[Unit]
Description=n8n workflow automation
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$N8N_DIR
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
sudo systemctl daemon-reload
sudo systemctl enable n8n.service

# Configure UFW firewall if it's active
if sudo ufw status | grep -q "Status: active"; then
    echo "🔥 Configuring firewall..."
    sudo ufw allow 5678/tcp comment "n8n"
    echo "✅ Firewall configured to allow n8n on port 5678"
fi

# Start n8n
echo "🚀 Starting n8n..."
docker compose up -d

# Wait for n8n to be ready
echo "⏳ Waiting for n8n to start..."
sleep 10

# Check if n8n is running
if docker ps | grep -q n8n; then
    echo ""
    echo "🎉 n8n has been successfully installed and started!"
    echo ""
    echo "📋 Access Information:"
    echo "   URL: http://$SERVER_IP:5678"
    echo "   Username: admin"
    echo "   Password: n8n_password_change_me"
    echo ""
    echo "🔧 Management Commands:"
    echo "   Start:   sudo systemctl start n8n"
    echo "   Stop:    sudo systemctl stop n8n"
    echo "   Restart: sudo systemctl restart n8n"
    echo "   Status:  sudo systemctl status n8n"
    echo "   Logs:    docker compose logs -f"
    echo ""
    echo "📁 Configuration files located at: $N8N_DIR"
    echo ""
    echo "⚠️  SECURITY NOTES:"
    echo "   1. Change the default password in $N8N_DIR/.env"
    echo "   2. Consider setting up SSL/TLS with a reverse proxy (nginx/apache)"
    echo "   3. For production, use PostgreSQL instead of SQLite"
    echo "   4. Regularly backup the data directory: $N8N_DIR/data"
    echo ""
else
    echo "❌ Something went wrong. Check logs with: docker compose logs"
    exit 1
fi 