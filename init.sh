#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPDIR="$DIR/appdata"
LOGDIR="$DIR/logs"
CERTDIR="$DIR/certs"
SECRETDIR="$DIR/secrets"

echo "=== Docker Traefik Cloudflare DNS Stack - Initialization ==="

# --- Create directory structure ---
echo "[1/6] Creating directories..."
mkdir -p "$APPDIR/traefik/rules"
mkdir -p "$APPDIR/authelia"
mkdir -p "$APPDIR/telegraf"
mkdir -p "$APPDIR/adguard/conf"
mkdir -p "$LOGDIR/traefik"
mkdir -p "$LOGDIR/authelia"
mkdir -p "$CERTDIR"
mkdir -p "$DIR/dump"
mkdir -p "$SECRETDIR/authelia"
mkdir -p "$SECRETDIR/cf"
mkdir -p "$SECRETDIR/db"
mkdir -p "$SECRETDIR/vl"
mkdir -p "$SECRETDIR/telegraf"
mkdir -p "$SECRETDIR/traefik"

# Secure the secrets directory
chmod 700 "$SECRETDIR"

# --- Create acme.json with correct permissions ---
echo "[2/6] Setting up acme.json..."
if [ ! -f "$APPDIR/traefik/acme.json" ]; then
  touch "$APPDIR/traefik/acme.json"
fi
chmod 600 "$APPDIR/traefik/acme.json"

# --- Create log files ---
echo "[3/6] Creating log files..."
if [ ! -f "$LOGDIR/authelia/notification.txt" ]; then
  touch "$LOGDIR/authelia/notification.txt"
fi
chmod 755 "$LOGDIR/authelia"
chmod 644 "$LOGDIR/authelia/notification.txt"

# --- Generate random secrets ---
echo "[4/6] Generating secrets..."

generate_secret() {
  local file="$1"
  local desc="$2"
  if [ -s "$file" ]; then
    echo "  [SKIP] $desc (already exists)"
  else
    openssl rand -hex 32 > "$file"
    chmod 600 "$file"
    echo "  [OK]   $desc"
  fi
}

generate_secret "$SECRETDIR/authelia/jwt_secret" "Authelia JWT secret"
generate_secret "$SECRETDIR/authelia/session_secret" "Authelia session secret"
generate_secret "$SECRETDIR/authelia/storage_encryption_key" "Authelia storage encryption key"
generate_secret "$SECRETDIR/authelia/storage_mysql_password" "Authelia MySQL password"
generate_secret "$SECRETDIR/db/mysql_root_password" "MariaDB root password"
generate_secret "$SECRETDIR/influxdb_password" "InfluxDB password"
generate_secret "$SECRETDIR/crowdsec_api_key" "CrowdSec API key"
generate_secret "$SECRETDIR/wud_auth_hash" "WUD auth hash (placeholder)"

# Create placeholder files for tokens that must be set manually
for f in "$SECRETDIR/cf/cf_dns_api_token" \
         "$SECRETDIR/vl/vaultwarden_admin_token" \
         "$SECRETDIR/telegraf/influx_token" \
         "$SECRETDIR/traefik/influx_token" \
         "$SECRETDIR/htpasswd"; do
  if [ ! -f "$f" ]; then
    touch "$f"
    chmod 600 "$f"
    echo "  [TODO] $(basename "$f") - needs manual configuration"
  fi
done

# --- Create Docker networks ---
echo "[5/6] Creating Docker networks..."

create_network() {
  local name="$1"
  local opts="${2:-}"
  if docker network inspect "$name" >/dev/null 2>&1; then
    echo "  [SKIP] Network $name (already exists)"
  else
    # shellcheck disable=SC2086
    docker network create $opts "$name" >/dev/null
    echo "  [OK]   Network $name"
  fi
}

create_network "net_t2" "--subnet=172.16.90.0/24"
create_network "socket_proxy" "--subnet=172.16.91.0/24"
create_network "socket_proxy_admin" "--internal"
create_network "net_db" ""
create_network "net_redis" ""

# --- Create .env from template ---
echo "[6/6] Setting up environment..."
if [ ! -f "$DIR/.env" ]; then
  if [ -f "$DIR/.env.example" ]; then
    cp "$DIR/.env.example" "$DIR/.env"
    
    # Cross-platform sed for replacing path
    if sed --version 2>/dev/null | grep -q GNU; then
      sed -i "s|/home/user/docker-traefik-cloudflare-dns|$DIR|g" "$DIR/.env"
    else
      # macOS/BSD sed
      sed -i '' "s|/home/user/docker-traefik-cloudflare-dns|$DIR|g" "$DIR/.env"
    fi
    
    chmod 600 "$DIR/.env"
    echo "  [OK]   .env created from template - EDIT IT NOW!"
  else
    echo "  [WARN] .env.example not found"
  fi
else
  echo "  [SKIP] .env (already exists)"
fi

echo ""
echo "=== Initialization complete ==="
echo ""
echo "TODO before starting:"
echo "  1. Edit .env with your domain and paths"
echo "  2. Set Cloudflare token:  secrets/cf/cf_dns_api_token"
echo "  3. Generate htpasswd:     htpasswd -nb admin PASSWORD > secrets/htpasswd"
echo "  4. Update appdata/traefik/traefik.yml with your domain"
echo "  5. Update appdata/authelia/configuration.yml with your domain"
echo ""
echo "Start with:"
echo "  docker compose --profile core up -d"