# Docker Traefik Cloudflare DNS Stack

A production-ready Docker stack with Traefik reverse proxy, Cloudflare DNS challenge, Authelia authentication, and monitoring.

## 📁 Project Structure

```text
docker-traefik-cloudflare-dns/
├── appdata/
│   ├── authelia/
│   │   ├── configuration.yml
│   │   └── users.yml
│   ├── telegraf/
│   │   └── telegraf.conf
│   └── traefik/
│       ├── rules/
│       │   ├── cert.yml.example
│       │   ├── dashboard.yml
│       │   ├── dynamic.yml.example
│       │   └── middlewares.yml
│       ├── acme.json
│       └── traefik.yml
├── certs/
├── compose/
│   ├── adguard.yml
│   ├── authelia.yml
│   ├── dozzle.yml
│   ├── influxdb.yml
│   ├── mariadb.yml
│   ├── portainer.yml
│   ├── redis.yml
│   ├── socket-proxy.yml
│   ├── socket-proxy-admin.yml
│   ├── telegraf.yml
│   ├── traefik-certs-dumper.yml
│   ├── traefik.yml
│   ├── uptime-kuma.yml
│   ├── vaultwarden.yml
│   ├── whats-up-docker.yml
│   └── whoami.yml
├── logs/
├── secrets/
├── .env.example
├── compose.yml
├── init.sh
└── README.md
```

## 🚀 Quick Start

### Prerequisites

- Docker & Docker Compose v2+
- Cloudflare account with API token
- Domain configured in Cloudflare

### 1. Clone and Initialize

```bash
git clone <repo-url>
cd docker-traefik-cloudflare-dns
chmod +x init.sh
./init.sh
```

The init script will:
- Create all required directories
- Set correct permissions on `acme.json`
- Generate random secrets (Authelia, MariaDB, InfluxDB)
- Create Docker networks
- Create `.env` from template

### 2. Configure Environment

```bash
nano .env
```

Update all values, especially:
- `DOMAINNAME` — your domain
- `DOCKERDIR` — project path (auto-set by `init.sh`)

### 3. Configure Secrets (Manual Steps)

```bash
# Cloudflare DNS API token
echo "your-cloudflare-api-token" > secrets/cf/cf_dns_api_token

# Traefik dashboard password
htpasswd -nb admin YOUR_PASSWORD > secrets/htpasswd
```

**Vaultwarden admin token** (when enabling vaultwarden):
```bash
docker run --rm -it vaultwarden/server /vaultwarden hash --preset owasp

# Generate an Argon2id PHC string using the 'owasp' preset:
# Password: <YOUR_PASSWORD>
# Confirm Password: <YOUR_PASSWORD>
# ADMIN_TOKEN='$argon2id$v=19$m=19456...<HASH_HERE>'

# Save it to the secret file:
echo '$argon2id$v=19$m=19456...<HASH_HERE>' > secrets/vl/vaultwarden_admin_token
```

### 4. Update Domain Configuration

**Traefik** — `appdata/traefik/traefik.yml`:
```yaml
entryPoints:
  https:
    address: ':443'
    http:
      tls:
        certResolver: dns-cloudflare
        domains:
          - main: yourdomain.com
            sans:
              - '*.yourdomain.com'

certificatesResolvers:
  dns-cloudflare:
    acme:
      # Switch to production after testing!
      caServer: https://acme-staging-v02.api.letsencrypt.org/directory
      # caServer: 'https://acme-v02.api.letsencrypt.org/directory'
      email: dns@yourdomain.com
```

**Authelia** — `appdata/authelia/configuration.yml`:
Replace all `<SITE.COM>` with your domain.

### 5. Verify Cloudflare Token

```bash
curl "https://api.cloudflare.com/client/v4/accounts/<ACCOUNT_ID>/tokens/verify" \
  -H "Authorization: Bearer $(cat secrets/cf/cf_dns_api_token)"
```

---

## 📦 Deployment

### Step 0. Check secrets
```bash
secrets/
├── authelia
│   ├── jwt_secret
│   ├── session_secret
│   ├── storage_encryption_key
│   └── storage_mysql_password
├── cf
│   └── cf_dns_api_token
├── crowdsec_api_key
├── db
│   └── mysql_root_password
├── htpasswd
├── influxdb_password
├── telegraf
│   └── influx_token
├── vl
│   └── vaultwarden_admin_token
└── wud_auth_hash
```
### Step 1: Core Services (Traefik + Socket Proxy + Portainer)

```bash
docker compose --profile core config   # Validate
docker compose --profile core up -d
docker compose --profile core logs -f
```

Monitor ACME certificate generation:
```bash
cat logs/traefik/traefik.json | jq .
```

### Step 2: Database Services

```bash
docker compose --profile database config
docker compose --profile database up -d
docker compose --profile database logs -f
```

### Step 3: Auth (Authelia)

Set up the database first:
```bash
MYSQL_ROOT_PASS=$(cat secrets/db/mysql_root_password)
AUTHELIA_DB_PASS=$(cat secrets/authelia/storage_mysql_password)

docker exec -it mariadb mariadb -u root -p"${MYSQL_ROOT_PASS}" -e "
CREATE DATABASE IF NOT EXISTS authelia CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'authelia'@'%' IDENTIFIED BY '${AUTHELIA_DB_PASS}';
GRANT ALL PRIVILEGES ON authelia.* TO 'authelia'@'%';
FLUSH PRIVILEGES;
"
```

Start Authelia:
```bash
docker compose --profile auth config
docker compose --profile auth up -d
docker compose --profile auth logs -f
```

Generate a user password hash:
```bash
docker exec -it authelia authelia crypto hash generate argon2 \
  --password 'YOUR_SECURE_PASSWORD'
```

Add the hash to `appdata/authelia/users.yml`:
```yaml
users:
  admin:
    displayname: Admin User
    password: "$argon2id$v=19$m=65536,t=3,p=4$..."
    email: admin@yourdomain.com
    groups:
      - dev
```

Restart Authelia:
```bash
docker compose --profile auth restart authelia
```

### Step 4: Monitoring

```bash
docker compose --profile monitoring config
docker compose --profile monitoring up -d
docker compose --profile monitoring logs -f
```

### Step 5: Applications

```bash
docker compose --profile apps config
docker compose --profile apps up -d
docker compose --profile apps logs -f
```

---

## 📊 InfluxDB Setup

*(Note: Replace `<YOUR_ADMIN_TOKEN>` with the token you set as `DOCKER_INFLUXDB_INIT_ADMIN_TOKEN` in `compose/influxdb.yml`)*

### Create Buckets and Tokens

**For Telegraf (Docker metrics):**
```bash
docker exec influxdb influx bucket create \
  --name docker --org myorg --retention 30d \
  -t "<YOUR_ADMIN_TOKEN>"
  
# Note the <BUCKET_ID> from the output, then create the auth token:
docker exec influxdb influx auth create \
  --org myorg --description "telegraf" \
  --write-bucket <BUCKET_ID> \
  --read-bucket <BUCKET_ID> \
  -t "<YOUR_ADMIN_TOKEN>"

# Save the generated token
echo "TOKEN_HERE" > secrets/telegraf/influx_token
```

**For Traefik metrics:**
```bash
docker exec influxdb influx bucket create \
  --name traefik --org myorg --retention 30d \
  -t "<YOUR_ADMIN_TOKEN>"

# Note the <BUCKET_ID> for traefik, then create the auth token:
docker exec influxdb influx auth create \
  --org myorg --description "traefik" \
  --write-bucket <TRAEFIK_BUCKET_ID> \
  --read-bucket <TRAEFIK_BUCKET_ID> \
  -t "<YOUR_ADMIN_TOKEN>"

# Save the generated token
echo "TOKEN_HERE" > secrets/traefik/influx_token
```

### Enable Traefik Metrics

Insert your token and uncomment the metrics section in `appdata/traefik/traefik.yml`:
```yaml
metrics:
  influxDB2:
    addEntryPointsLabels: true
    addServicesLabels: true
    addRoutersLabels: true
    address: 'http://influxdb:8086'
    bucket: traefik
    org: myorg
    pushInterval: 30s
    token: '<YOUR_TRAEFIK_TOKEN_HERE>'
    additionalLabels:
      environment: production
      host: '{{env "DOMAINNAME"}}'
```

Restart Traefik to apply changes:
```bash
docker compose --profile core restart traefik
```

### Import Docker Dashboard Template

```bash
docker exec influxdb influx apply \
  -u https://raw.githubusercontent.com/influxdata/community-templates/master/docker/docker.yml \
  --force \
  -t "<YOUR_ADMIN_TOKEN>"
```

---

## 🔒 Security Architecture

### Socket Proxy Separation

The stack uses two separate Docker socket proxies for security:

| Proxy | Network | Permissions | Consumers |
|-------|---------|-------------|-----------|
| `socket-proxy` | `socket_proxy` | Read-only (no POST/EXEC) | Traefik, Telegraf, Dozzle, WUD, Uptime Kuma |
| `socket-proxy-admin` | `socket_proxy_admin` (internal) | Read-write (POST/EXEC) | Portainer only |

This ensures that a compromise of any monitoring service cannot lead to container manipulation.

### Middleware Chains

All services are protected by Traefik middleware chains:

| Chain | Protection |
|-------|------------|
| `chain-internal` | Local IP + rate limit + secure headers |
| `chain-internal-authelia` | Local IP + rate limit + Authelia SSO + secure headers |
| `chain-authelia` | Rate limit + Authelia SSO + secure headers |
| `chain-public` | Rate limit + public secure headers |
| `chain-vaultwarden` | Rate limit + Vaultwarden-specific headers |
| `chain-internal-basic-auth` | Local IP + rate limit + basic auth + secure headers |

---

## 🏷️ Compose Profiles

| Profile | Services |
|---------|----------|
| `core` | traefik, socket-proxy, socket-proxy-admin, portainer |
| `database` | mariadb, redis, influxdb |
| `auth` | authelia |
| `monitoring` | uptime-kuma, telegraf |
| `apps` | vaultwarden, dozzle, whats-up-docker |
| `adguard` | adguard, traefik-certs-dumper |
| `test` | whoami |
| `all` | everything |

---

## 🌐 Networks

| Network | Subnet | Purpose |
|---------|--------|---------|
| `net_t2` | 172.16.90.0/24 | Traefik frontend |
| `socket_proxy` | 172.16.91.0/24 | Docker socket proxy (read-only) |
| `socket_proxy_admin` | auto (internal) | Docker socket proxy (admin, no external) |
| `net_db` | auto | Database connections |
| `net_redis` | auto | Redis connections |

---

## 📚 Services

| Service | Subdomain | Purpose |
|---------|-----------|---------|
| **Traefik** | `traefik.*` | Reverse proxy with automatic SSL |
| **Authelia** | `auth.*` | SSO & 2FA authentication |
| **Portainer** | `portainer.*` | Container management |
| **InfluxDB** | `influx.*` | Time-series metrics |
| **Vaultwarden** | `vault.*` | Password manager |
| **AdGuard Home** | `adguard.*` | DNS & ad blocking |
| **Uptime Kuma** | `status.*` | Uptime monitoring |
| **What's Up Docker** | `wud.*` | Update notifications |
| **Dozzle** | `dozz.*` | Real-time container logs |

---

## ⚠️ Production Checklist

- [ ] Switch ACME to production CA server in `traefik.yml`
- [ ] Replace filesystem notifier with SMTP in Authelia
- [ ] Set up Authelia user accounts with strong passwords
- [ ] Rotate all auto-generated secrets
- [ ] Configure Cloudflare DNS records for all subdomains
- [ ] Enable CrowdSec bouncer plugin
- [ ] Set up regular backup for MariaDB and named volumes
- [ ] Review `socket-proxy-admin` permissions

---

## 📖 References

- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Authelia Documentation](https://www.authelia.com/docs/)
- [InfluxDB Templates](https://github.com/influxdata/community-templates)
- [Cloudflare API Tokens](https://developers.cloudflare.com/api/tokens/create/)