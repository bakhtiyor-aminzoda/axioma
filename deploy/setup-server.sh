#!/usr/bin/env bash
set -e

# ==============================================================================
# Axioma Platform - 1-Click Server Setup for Hetzner Ubuntu 24.04 / 22.04 LTS
# ==============================================================================

echo "=========================================================="
echo "🚀 Starting Axioma Platform Installation..."
echo "=========================================================="

# 1. System Updates
echo "📦 Updating system packages..."
apt-get update && apt-get upgrade -y
apt-get install -y curl wget git ufw htop jq certbot python3-certbot-nginx nginx

# 2. Configure Swap (2GB) to ensure smooth operation on 4GB RAM VPS
if [ ! -f /swapfile ]; then
    echo "🧠 Creating 2GB Swap file for RAM stability..."
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
    sysctl vm.swappiness=10
    echo 'vm.swappiness=10' >> /etc/sysctl.conf
fi

# 3. Install Docker & Docker Compose
if ! command -v docker &> /dev/null; then
    echo "🐳 Installing Docker Engine..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
fi

# 4. Configure Firewall (UFW)
echo "🛡️ Configuring Firewall (ports 22, 80, 443)..."
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# 5. Prepare Axioma Directory
echo "📁 Setting up Axioma directory at /opt/axioma..."
mkdir -p /opt/axioma
cd /opt/axioma

echo "=========================================================="
echo "✅ Server dependencies installed successfully!"
echo "Next step: Copy docker-compose.production.yaml and .env to /opt/axioma"
echo "and run: docker compose -f docker-compose.production.yaml up -d"
echo "=========================================================="
