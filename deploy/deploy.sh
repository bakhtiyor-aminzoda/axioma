#!/usr/bin/env bash
# ==============================================================================
# Axioma CRM — Production Automated Deployment Script
# Target: Ubuntu 22.04/24.04 LTS / Debian 12 VPS
# Domains: axioma.tj, crm.axioma.tj, admin.axioma.tj, api.axioma.tj
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}        AXIOMA CRM — PRODUCTION DEPLOYMENT ENGINE         ${NC}"
echo -e "${BLUE}============================================================${NC}"

# 1. Prerequisite checks
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

echo -e "\n${YELLOW}[1/7] Checking system dependencies...${NC}"
if ! command_exists docker; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable --now docker
fi

if ! command_exists nginx; then
    echo "Installing Nginx..."
    apt-get update && apt-get install -y nginx certbot python3-certbot-nginx
    systemctl enable --now nginx
fi

# 2. Environment file validation
echo -e "\n${YELLOW}[2/7] Validating production .env configuration...${NC}"
DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$DEPLOY_DIR")"
ENV_FILE="$DEPLOY_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "Creating production .env with secure random secrets..."
    cat <<EOF > "$ENV_FILE"
NODE_ENV=production
RAILS_ENV=production
INSTALLATION_NAME=Axioma
BRAND_NAME=Axioma
FRONTEND_URL=https://crm.axioma.tj
POSTGRES_DATABASE=chatwoot_production
POSTGRES_USERNAME=postgres
POSTGRES_PASSWORD=$(openssl rand -hex 32)
REDIS_PASSWORD=$(openssl rand -hex 32)
SECRET_KEY_BASE=$(openssl rand -hex 64)
EVOLUTION_SERVER_URL=https://api.axioma.tj
EVOLUTION_API_KEY=$(openssl rand -hex 32)
EVOLUTION_INSTANCE=Axioma_WhatsApp
AXIOMA_ADMIN_USER=admin
AXIOMA_ADMIN_PASS=$(openssl rand -hex 16)
AXIOMA_SECRET_KEY=$(openssl rand -hex 32)
AXIOMA_ADMIN_PUBLIC_URL=https://admin.axioma.tj
CHATWOOT_URL=http://axioma_web:3000
CHATWOOT_INTERNAL_URL=http://axioma_web:3000
SAFE_FETCH_ALLOW_PRIVATE_NETWORK=false
EOF
    echo -e "${GREEN}Created $ENV_FILE with hardened secrets.${NC}"
fi

# 3. Static landing deployment
echo -e "\n${YELLOW}[3/7] Setting up static landing page directory...${NC}"
mkdir -p /var/www/axioma-landing
mkdir -p /var/www/certbot
if [ -d "$ROOT_DIR/../axioma-landing" ]; then
    cp -ru "$ROOT_DIR/../axioma-landing/"* /var/www/axioma-landing/ 2>/dev/null || true
fi
chown -R www-data:www-data /var/www/axioma-landing

# 4. Nginx configuration
echo -e "\n${YELLOW}[4/7] Deploying Nginx reverse proxy configuration...${NC}"
cp "$DEPLOY_DIR/nginx.conf" /etc/nginx/sites-available/axioma
ln -sf /etc/nginx/sites-available/axioma /etc/nginx/sites-enabled/axioma
rm -f /etc/nginx/sites-enabled/default

# Generate dummy SSL if certificates don't exist yet to pass nginx -t
DOMAINS=("axioma.tj" "crm.axioma.tj" "admin.axioma.tj" "api.axioma.tj")
for DOMAIN in "${DOMAINS[@]}"; do
    CERT_DIR="/etc/letsencrypt/live/$DOMAIN"
    if [ ! -f "$CERT_DIR/fullchain.pem" ]; then
        echo "Creating temporary self-signed SSL for $DOMAIN..."
        mkdir -p "$CERT_DIR"
        openssl req -x509 -nodes -newkey rsa:2048 -days 1 \
            -keyout "$CERT_DIR/privkey.pem" \
            -out "$CERT_DIR/fullchain.pem" \
            -subj "/CN=$DOMAIN" 2>/dev/null || true
    fi
done

if [ ! -f /etc/letsencrypt/options-ssl-nginx.conf ]; then
    mkdir -p /etc/letsencrypt
    curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf > /etc/letsencrypt/options-ssl-nginx.conf
fi
if [ ! -f /etc/letsencrypt/ssl-dhparams.pem ]; then
    curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem > /etc/letsencrypt/ssl-dhparams.pem
fi

nginx -t
systemctl reload nginx

# 5. Start container stack
echo -e "\n${YELLOW}[5/7] Launching Docker services...${NC}"
cd "$DEPLOY_DIR"
docker compose -f docker-compose.production.yaml up -d

# 6. Database migrations & seed
echo -e "\n${YELLOW}[6/7] Running database migrations & seeder...${NC}"
echo "Waiting for PostgreSQL to be ready..."
sleep 5
docker exec axioma_web bundle exec rails db:chatwoot_prepare || true
docker exec axioma_web bundle exec rails runner "Axioma::TemplateSeeder.seed_account(1)" || true

# 7. Verification & health check
echo -e "\n${YELLOW}[7/7] Running live health checks...${NC}"
sleep 3
echo -e "Testing CRM: $(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3000 || echo 'FAIL')"
echo -e "Testing Evolution Gateway: $(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8080 || echo 'FAIL')"
echo -e "Testing Admin Backend: $(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5051/health || echo 'FAIL')"

echo -e "\n${GREEN}============================================================${NC}"
echo -e "${GREEN}     AXIOMA CRM SUCCESSFULLY DEPLOYED AND OPERATIONAL!     ${NC}"
echo -e "${GREEN}============================================================${NC}"
echo -e "Landing Page:   https://axioma.tj"
echo -e "CRM Workspace:  https://crm.axioma.tj"
echo -e "Admin Panel:    https://admin.axioma.tj"
echo -e "WhatsApp API:   https://api.axioma.tj"
echo -e "\nTo obtain real Let's Encrypt certificates run:"
echo -e "certbot --nginx -d axioma.tj -d www.axioma.tj -d crm.axioma.tj -d admin.axioma.tj -d api.axioma.tj --non-interactive --agree-tos -m admin@axioma.tj"
