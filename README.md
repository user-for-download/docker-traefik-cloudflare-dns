# Docker Traefik Cloudflare DNS Stack

A Docker stack with Traefik reverse proxy, Cloudflare DNS challenge (or local certificates), Authelia authentication, and monitoring.

## Project Structure

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
│       │   ├── middlewares.yml
│       │   └── tls.yml
│       ├── acme.json
│       └── traefik.yml
├── certs/
├── compose/
│   ├── adguard.yml
│   ├── authelia.yml
│   ├── dozzle.yml
│   ├── influxdb.yml
│   ├── mariadb.yml
│   ├── navidrome.yml
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
├── music/
├── secrets/
├── .env.example
├── compose.yml
├── init.sh
└── README.md
```

## Quick Start

### Prerequisites

- Docker & Docker Compose v2+

### 1. Clone and Initialize

```bash
git clone https://github.com/user-for-download/docker-traefik-cloudflare-dns
cd docker-traefik-cloudflare-dns
chmod +x init.sh
./init.sh
```

The init script will:
- Create all required directories
- Set correct permissions on `acme.json`
- Generate random secrets (Authelia, MariaDB, InfluxDB, Redis)
- Create placeholder files for manual secrets
- Create Docker networks
- Create `.env` from template

### 2. Configure Environment

```bash
nano .env
```

Update values:
- `DOMAINNAME` — your domain
- `DOCKERDIR` — project path (auto-set by `init.sh`)
- `ACME_EMAIL` — email for Let's Encrypt (when using Cloudflare DNS)

### 3. Manual Secrets

```bash
# Traefik dashboard password
htpasswd -nb admin YOUR_PASSWORD > secrets/htpasswd

# Vaultwarden admin token (when enabling vaultwarden):
docker run --rm -it vaultwarden/server /vaultwarden hash --preset owasp
echo '$argon2id$v=19$m=19456...<HASH_HERE>' > secrets/vl/vaultwarden_admin_token
```

---

## TLS Certificate Modes

Switch between local testing and Cloudflare DNS challenge by toggling comments in two files.

### Local Testing (default)

No domain required. Self-signed certs. Dashboard at `http://localhost:8080/dashboard/`.

**Generate self-signed cert:**
```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout certs/selfsigned.key -out certs/selfsigned.crt \
  -subj "/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,DNS:*.localhost,IP:127.0.0.1"
```

**Verify these settings in `appdata/traefik/traefik.yml`:**
```yaml
entryPoints:
  https:
    http:
      tls:
        certResolver: local-cert       # <-- active
        # certResolver: dns-cloudflare  # <-- commented out
```

**Verify these settings in `appdata/traefik/rules/dashboard.yml`:**
```yaml
      rule: 'Host(`localhost`)'
      # rule: 'Host(`traefik.{{env "DOMAINNAME"}}`)'
      middlewares:
        - chain-internal-basic-auth@file
        # - chain-internal-authelia@file
      tls:
        certResolver: local-cert
        # certResolver: dns-cloudflare
```

### Cloudflare DNS Challenge (production)

Real domains with Let's Encrypt certificates.

**1. Set Cloudflare API token:**
```bash
echo "your-cloudflare-api-token" > secrets/cf/cf_dns_api_token
```

**2. Update `appdata/traefik/traefik.yml` - toggle comments:**
```yaml
entryPoints:
  https:
    http:
      tls:
        # certResolver: local-cert       # <-- comment out
        certResolver: dns-cloudflare      # <-- activate
        domains:
          - main: '{{env "DOMAINNAME"}}'
            sans:
              - '*.{{env "DOMAINNAME"}}'

certificatesResolvers:
  # local-cert:                          # <-- comment out
  #   local:
  #     cert: /certs/selfsigned.crt
  #     key: /certs/selfsigned.key

  dns-cloudflare:                        # <-- activate
    acme:
      caServer: 'https://acme-v02.api.letsencrypt.org/directory'
      email: '{{env "ACME_EMAIL"}}'
      storage: /acme.json
      dnsChallenge:
        provider: cloudflare
        propagation:
          delayBeforeChecks: 90s
        resolvers:
          - '1.1.1.1:53'
          - '1.0.0.1:53'
```

**3. Update `appdata/traefik/rules/dashboard.yml`:**
```yaml
      rule: 'Host(`traefik.{{env "DOMAINNAME"}}`)'
      middlewares:
        - chain-internal-authelia@file
      tls:
        certResolver: dns-cloudflare
```

**4. Update `appdata/authelia/configuration.yml`** with your domain:
```yaml
totp:
  issuer: auth.yourdomain.com
access_control:
  rules:
    - domain: "auth.yourdomain.com"
      policy: bypass
    - domain: "*.yourdomain.com"
      policy: one_factor
session:
  cookies:
    - domain: "yourdomain.com"
      authelia_url: "https://auth.yourdomain.com"
      default_redirection_url: "https://traefik.yourdomain.com"
```

---

## Deployment

### Secrets Structure

```
secrets/
├── authelia
│   ├── jwt_secret
│   ├── session_secret
│   ├── storage_encryption_key
│   └── storage_mysql_password
├── cf
│   └── cf_dns_api_token          # Only needed for Cloudflare mode
├── crowdsec_api_key
├── db
│   └── mysql_root_password
├── htpasswd
├── influxdb_admin_token
├── influxdb_password
├── redis_password
├── telegraf
│   └── influx_token
├── traefik
│   └── influx_token
├── vl
│   └── vaultwarden_admin_token
└── wud_auth_hash
```

### Step 1: Core Services (Traefik + Socket Proxy + Portainer)

```bash
docker compose --profile core up -d
```

Dashboard: `http://localhost:8080/dashboard/`

### Step 2: Database Services

MariaDB auto-creates the `authelia` database and user.

```bash
docker compose --profile database up -d
```

### Step 3: Auth (Authelia)

```bash
docker compose --profile auth up -d
```

Generate a user password hash:
```bash
docker exec -it authelia authelia crypto hash generate argon2 \
  --password 'YOUR_SECURE_PASSWORD'
```

Add the hash to `appdata/authelia/users.yml` and restart Authelia:
```bash
docker compose --profile auth up -d --force-recreate authelia
```

### Step 4: Monitoring

Set up InfluxDB buckets and tokens after starting:
```bash
docker compose --profile monitoring up -d

# Create bucket and token for Telegraf
INFLUX_TOKEN=$(cat secrets/influxdb_admin_token)
docker exec influxdb influx bucket create \
  --name docker --org myorg --retention 30d \
  -t "$INFLUX_TOKEN"

BUCKET_ID=$(docker exec influxdb influx bucket list \
  -t "$INFLUX_TOKEN" --org myorg | grep docker | awk '{print $1}')

docker exec influxdb influx auth create \
  --org myorg --description "telegraf" \
  --write-bucket "$BUCKET_ID" \
  --read-bucket "$BUCKET_ID" \
  -t "$INFLUX_TOKEN"

# Save the generated token
docker exec influxdb influx auth list -t "$INFLUX_TOKEN" --org myorg
echo "TOKEN_HERE" > secrets/telegraf/influx_token
```

### Step 5: Applications

```bash
docker compose --profile apps up -d
```

---

## Security Architecture

### Socket Proxy Separation

| Proxy | Network | Permissions | Consumers |
|-------|---------|-------------|-----------|
| `socket-proxy` | `socket_proxy` | Read-only + POST (for WUD) | Traefik, Telegraf, Dozzle, WUD, Uptime Kuma |
| `socket-proxy-admin` | `socket_proxy_admin` (internal) | Full read-write | Portainer only |

### Middleware Chains

| Chain | Protection |
|-------|------------|
| `chain-internal` | Local IP + rate limit + secure headers |
| `chain-internal-authelia` | Local IP + rate limit + Authelia SSO + secure headers |
| `chain-authelia` | Rate limit + Authelia SSO + secure headers |
| `chain-public` | Rate limit + public secure headers |
| `chain-vaultwarden` | Rate limit + Vaultwarden-specific headers |
| `chain-internal-basic-auth` | Local IP + rate limit + basic auth + secure headers |

---

## Compose Profiles

| Profile | Services |
|---------|----------|
| `core` | traefik, socket-proxy, socket-proxy-admin, portainer |
| `database` | mariadb, redis, influxdb |
| `auth` | authelia |
| `monitoring` | uptime-kuma, telegraf |
| `apps` | vaultwarden, dozzle, whats-up-docker, navidrome |
| `adguard` | adguard, traefik-certs-dumper |
| `test` | whoami |
| `all` | everything |

## Networks

| Network | Subnet | Purpose |
|---------|--------|---------|
| `net_t2` | 172.16.90.0/24 | Traefik frontend |
| `socket_proxy` | 172.16.91.0/24 | Docker socket proxy (read-only) |
| `socket_proxy_admin` | auto (internal) | Docker socket proxy (admin) |
| `net_db` | auto | Database connections |
| `net_redis` | auto | Redis connections |

## Services

| Service | Subdomain | Port (local) | Purpose |
|---------|-----------|--------------|---------|
| **Traefik** | `traefik.*` | 8080 | Reverse proxy dashboard |
| **Authelia** | `auth.*` | - | SSO & 2FA |
| **Portainer** | `portainer.*` | - | Container management |
| **InfluxDB** | `influx.*` | - | Time-series metrics |
| **Vaultwarden** | `vault.*` | - | Password manager |
| **Uptime Kuma** | `status.*` | - | Uptime monitoring |
| **What's Up Docker** | `wud.*` | - | Update notifications |
| **Dozzle** | `dozz.*` | - | Container logs |
| **Navidrome** | `music.*` | - | Music streaming server |

---

## Production Checklist

- [ ] Switch from local certs to Cloudflare DNS challenge (see TLS modes above)
- [ ] Set Cloudflare API token in `secrets/cf/cf_dns_api_token`
- [ ] Set `DOMAINNAME` and `ACME_EMAIL` in `.env`
- [ ] Replace filesystem notifier with SMTP in Authelia
- [ ] Set up Authelia user accounts with strong passwords
- [ ] Generate proper Vaultwarden admin token
- [ ] Configure Cloudflare DNS records for all subdomains
- [ ] Enable CrowdSec bouncer plugin
- [ ] Set up regular backup for MariaDB and named volumes
- [ ] Review `socket-proxy-admin` permissions

---

## References

- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Authelia Documentation](https://www.authelia.com/docs/)
- [InfluxDB Templates](https://github.com/influxdata/community-templates)
- [Cloudflare API Tokens](https://developers.cloudflare.com/api/tokens/create/)
