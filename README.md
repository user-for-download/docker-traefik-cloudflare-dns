# Docker Traefik Cloudflare DNS Stack

A production-ready Docker stack with Traefik reverse proxy, Cloudflare DNS challenge, Authelia authentication, and monitoring.

## 📁 Project Structure

```bash
docker-traefik-cloudflare-dns/
├── appdata/
│   ├── authelia/
│   │   ├── configuration.yml
│   │   └── users.yml
│   └── traefik/
│       ├── rules/
│       ├── acme.json
│       └── traefik.yml
├── compose/
│   ├── adguard.yml
│   ├── authelia.yml
│   ├── dozzle.yml
│   ├── influxdb.yml
│   ├── mariadb.yml
│   ├── portainer.yml
│   ├── redis.yml
│   ├── socket-proxy.yml
│   ├── telegraf.yml
│   ├── traefik-certs-dumper.yml
│   ├── traefik.yml
│   ├── uptime-kuma.yml
│   ├── vaultwarden.yml
│   ├── whats-up-docker.yml
│   └── whoami.yml
├── logs/
│   ├── authelia/
│   └── traefik/
├── secrets/
│   ├── authelia/
│   ├── cf/
│   ├── db/
│   ├── telegraf/
│   └── vl/
├── .env
├── compose.yml
└── README.md
```

## 🚀 Quick Start

### Prerequisites

- Docker & Docker Compose
- Cloudflare account with API token
- Domain configured in Cloudflare

### 1. Initial Setup

```bash
#!/bin/bash
DIR=$(pwd)
APPDIR="$DIR/appdata"

# Create acme.json with correct permissions
if [ ! -f "$APPDIR/traefik/acme.json" ]; then
    rm -rf "$APPDIR/traefik/acme.json"
    touch "$APPDIR/traefik/acme.json"
    chmod 600 "$APPDIR/traefik/acme.json"
    echo "Created acme.json"
fi

# Create Docker networks
docker network create --subnet=172.16.90.0/24 net_t2
docker network create --subnet=172.16.91.0/24 socket_proxy
docker network create net_db
docker network create net_redis

echo "Networks created successfully!"
```

### 2. Configure Secrets

Populate the following secret files:

| File | Description |
|------|-------------|
| `secrets/cf/cf_dns_api_token` | Cloudflare DNS API token |
| `secrets/db/mysql_root_password` | MariaDB root password |
| `secrets/authelia/jwt_secret` | Authelia JWT secret |
| `secrets/authelia/session_secret` | Authelia session secret |
| `secrets/authelia/storage_encryption_key` | Authelia storage key |
| `secrets/authelia/storage_mysql_password` | Authelia DB password |

```bash
# Authelia secrets
echo $(openssl rand -hex 32) > secrets/authelia/jwt_secret
echo $(openssl rand -hex 32) > secrets/authelia/session_secret
echo $(openssl rand -hex 32) > secrets/authelia/storage_encryption_key
echo $(openssl rand -hex 32) > secrets/authelia/storage_mysql_password

and others...
```

### 3. Update Configuration

Edit `appdata/traefik/traefik.yml` with your domain settings.
```yaml
  https:
    address: ':443'
    http:
      tls:
        certResolver: dns-cloudflare
        domains:
          - main: <SITE.COM>
            sans:
              - '*.<SITE.COM>'
```
```yaml
certificatesResolvers:
  dns-cloudflare:
    acme:
      caServer: https://acme-staging-v02.api.letsencrypt.org/directory # Use staging during testing!
      # caServer: 'https://acme-v02.api.letsencrypt.org/directory'
      email: DNS@<SITE.COM>
```
---

### 4 . Update env
```bash
# Timezone
TZ=UTC

# Domain
DOMAINNAME=<SITE.COM>
DOMAINNAME_CLOUD_SERVER=<SITE.COM>

# Paths
DOCKERDIR=/home/<USER>/<FOLDER>
APPDIR=/home/<USER>/<FOLDER>/appdata
LOGDIR=/home/<USER>/<FOLDER>/logs

# InfluxDB
INFLUXDB_USER=admin
INFLUXDB_ORG=myorg
INFLUXDB_BUCKET=default

# User/Group IDs
PUID=1000
PGID=1000
```
---

## 📦 Deployment

### Step 1: Start Core Services

```bash
docker compose --profile core up -d
```

Monitor ACME certificate generation:
```bash
docker compose logs -f traefik
```

### Step 2: Start Database Services

```bash
docker compose --profile database up -d
```

---

## 📊 InfluxDB Setup

### Create Buckets and Tokens

```bash
# Create Docker metrics bucket
docker exec influxdb influx bucket create \
  --name docker \
  --org myorg \
  --retention 30d

# Note the bucket ID, then create auth token
docker exec influxdb influx auth create \
  --org myorg \
  --description "telegraf" \
  --write-bucket <DOCKER_BUCKET_ID> \
  --read-bucket <DOCKER_BUCKET_ID>
```

Save the token to `secrets/telegraf/influx_token`

```bash
# Create Traefik metrics bucket
docker exec influxdb influx bucket create \
  --name traefik \
  --org myorg \
  --retention 30d

# Create Traefik auth token
docker exec influxdb influx auth create \
  --org myorg \
  --description "traefik" \
  --write-bucket <TRAEFIK_BUCKET_ID> \
  --read-bucket <TRAEFIK_BUCKET_ID>
```

### Configure Traefik Metrics

Add to `appdata/traefik/traefik.yml`:

```yaml
metrics:
  influxDB2:
    addEntryPointsLabels: true
    addServicesLabels: true
    addRoutersLabels: true
    address: "http://influxdb:8086"
    bucket: traefik
    org: myorg
    pushInterval: 30s
    token: "<-----------YOUR_TRAEFIK_TOKEN>----------------"
    additionalLabels:
      environment: production
      host: "yourdomain.com" # change this!!!!
```

### Import Docker Dashboard Template

```bash
docker exec influxdb influx apply \
  -f https://raw.githubusercontent.com/influxdata/community-templates/master/docker/docker.yml
```

This imports:
- 1 Bucket: docker (7d retention)
- 1 Telegraf Configuration
- 1 Dashboard: Docker
- 4 Alerts: Container CPU, memory, disk, non-zero exit

### Restart Traefik

```bash
docker compose --profile core restart traefik
```

---

## 🔐 Authelia Setup

### Create Database

```bash
# Read passwords from secrets
MYSQL_ROOT_PASS=$(cat secrets/db/mysql_root_password)
AUTHELIA_DB_PASS=$(cat secrets/authelia/storage_mysql_password)

# Create database and user
docker exec -it mariadb mariadb -u root -p"${MYSQL_ROOT_PASS}" -e "
CREATE DATABASE IF NOT EXISTS authelia CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'authelia'@'%' IDENTIFIED BY '${AUTHELIA_DB_PASS}';
GRANT ALL PRIVILEGES ON authelia.* TO 'authelia'@'%';
FLUSH PRIVILEGES;
"

# Verify
docker exec -it mariadb mariadb -u root -p"${MYSQL_ROOT_PASS}" -e "
SHOW DATABASES;
SELECT User, Host FROM mysql.user;
"
```

### Set Permissions

```bash
# Authelia logs
sudo chown -R 1000:1000 logs/authelia
sudo chmod 755 logs/authelia
touch logs/authelia/notification.txt
sudo chown 1000:1000 logs/authelia/notification.txt
```

### Start Authelia

```bash
docker compose --profile auth up -d
```

### Generate Password Hashes

```bash
docker exec -it authelia authelia crypto hash generate argon2 \
  --password 'YOUR_SECURE_PASSWORD'
```

Create New user and add the hash to `appdata/authelia/users.yml`
---

## 🎯 Start Applications

```bash
docker compose --profile apps up -d
```

---

## 🔧 Useful Commands

### Verify Cloudflare Token

```bash
curl "https://api.cloudflare.com/client/v4/accounts/<ACCOUNT_ID>/tokens/verify" \
  -H "Authorization: Bearer <YOUR_TOKEN>"
```

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f traefik
docker compose logs -f authelia
```

### Restart Services

```bash
docker compose --profile core restart
docker compose --profile auth restart
docker compose --profile apps restart
```

---

## 🏷️ Compose Profiles

| Profile | Services |
|---------|----------|
| `core` | traefik, socket-proxy |
| `database` | mariadb, redis, influxdb |
| `auth` | authelia |
| `apps` | All application services |

---

## 🌐 Networks

| Network | Subnet | Purpose |
|---------|--------|---------|
| `net_t2` | 172.16.90.0/24 | Traefik frontend |
| `socket_proxy` | 172.16.91.0/24 | Docker socket proxy |
| `net_db` | auto | Database connections |
| `net_redis` | auto | Redis connections |

---

## 📚 Services Included

- **Traefik** - Reverse proxy with automatic SSL
- **Authelia** - SSO & 2FA authentication
- **MariaDB** - Database server
- **Redis** - Session storage
- **InfluxDB** - Time-series metrics
- **Telegraf** - Metrics collection
- **Portainer** - Container management
- **Dozzle** - Log viewer
- **Vaultwarden** - Password manager
- **AdGuard Home** - DNS & ad blocking
- **Uptime Kuma** - Uptime monitoring
- **What's Up Docker** - Update notifications

---

## 🛡️ Security Notes

1. **Never commit secrets** - All sensitive data in `secrets/` folder
2. **acme.json permissions** - Must be `600`
3. **Socket proxy** - Isolates Docker socket access
4. **Authelia** - Protects sensitive endpoints

---

## 📖 References

- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Authelia Documentation](https://www.authelia.com/docs/)
- [InfluxDB Templates](https://github.com/influxdata/community-templates)
- [Cloudflare API Tokens](https://developers.cloudflare.com/api/tokens/create/)