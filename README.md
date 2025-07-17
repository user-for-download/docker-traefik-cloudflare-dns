# `README.md` for Docker Traefik Cloudflare DNS Setup

> **System Requirements:**  
> Linux 5.15.0-97-generic #107-Ubuntu SMP  
> x86_64 GNU/Linux  
> Default user: ubuntu (UID 1000, GID 1000)  
>  
> ⚠️ **Note:** The latest versions of Docker services were used at the time of publication. Compatibility may vary over time.

---

## 🧩 Features

This Docker setup provides a comprehensive, secure, and self-hosted infrastructure with the following services:

| Service | Description |
|--------|-------------|
| **Traefik** | Reverse proxy with Let's Encrypt integration |
| **Authelia** | Single Sign-On (SSO) and 2FA authentication |
| **Crowdsec** | Intrusion detection and prevention system |
| **AdGuardHome** | Network-wide ad blocking via DNS |
| **Portainer** | Docker management UI |
| **Vaultwarden** | Bitwarden-compatible password manager |
| **InfluxDB & Glances** | System monitoring and metrics |
| **Uptime Kuma** | Uptime monitoring dashboard |
| **Dozzle** | Real-time Docker log viewer |
| **What's Up Docker** | Docker update notifier |
| **MariaDB, Redis** | Database backends |
| **Socket Proxy** | Secure Docker socket proxy |

---

## 📁 Directory Structure

- **`appdata/`** - Application-specific data
- **`secrets/`** - Sensitive credentials and keys
- **`compose/`** - Docker Compose service definitions
- **`logs/`** - Log files for services
- **`.env`** - Environment variables
- **`compose.yml`** - Main Docker Compose configuration
- **`README.md`** - This file

---

## 🚀 Quick Start Guide

### 1. Clone the Repository

```bash
mkdir git && cd git
git clone https://github.com/user-for-download/docker-traefik-cloudflare-dns.git
cd docker-traefik-cloudflare-dns
```

---

### 2. Create Secrets

```bash
cd secrets
cd authelia && for i in *; do openssl rand -hex 16 > $i; done && cd ..
cd db && for i in *; do openssl rand -hex 16 > $i; done && cd ..
```

---

### 3. Configure Environment Variables

Edit `.env` to match your system:

```bash
nano .env
```

Update the following:

```env
##### SYSTEM
PUID=1000
PGID=1000
TZ=Europe/Moscow
DOCKERDIR=/home/<USERS>/git/docker-traefik-cloudflare-dns
APPDIR=/home/<USERS>/git/docker-traefik-cloudflare-dns/appdata

##### DOMAIN
DOMAINNAME_CLOUD_SERVER=yourdomain.com
DOMAINNAME=yourdomain.com
```

---

### 4. Prepare Let's Encrypt Certificate Storage

```bash
touch appdata/traefik/acme/acme.json
chmod 600 secrets/* appdata/traefik/acme/acme.json
```

---

### 5. Create Docker Networks

```bash
docker network create -d bridge socket_proxy --subnet 172.16.80.0/24
docker network create -d bridge net_t2 --subnet 172.16.90.0/24
docker network create -d bridge net_db --subnet 172.16.82.0/23
docker network create -d bridge net_redis --subnet 172.16.84.0/23
```
### 6. Run core
```bash
docker-compose --profile core up -d
```
---

## 🛠️ Post-Install Setup

### 1. Set Up Log Rotation for Traefik

```bash
sudo nano /etc/logrotate.d/traefik
```

Add:

```bash
/<PATH-TO-LOGS>/logs/traefik/*.log {
    daily
    rotate 30
    missingok
    notifempty
    sharedscripts
    postrotate
      docker kill --signal="USR1" $(docker ps | grep traefik | awk '{print $1}') > /dev/null 2>&1 || true
    endscript
}
```

Test:

```bash
logrotate /etc/logrotate.conf --debug
```

---

### 2. Set Up Crowdsec Firewall Bouncer

```bash
sudo apt install crowdsec-firewall-bouncer-iptables
docker exec -t crowdsec cscli bouncers add host-firewall-bouncer-dshb
```

Edit config:

```bash
sudo nano /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml
```

Restart service:

```bash
sudo systemctl restart crowdsec-firewall-bouncer.service
```

Check logs:

```bash
cat /var/log/crowdsec-firewall-bouncer.log
```

---

### 3. Add Custom Whitelists to Crowdsec

```bash
nano appdata/crowdsec/parsers/s02-enrich/mywhitelists.yaml
```

Example:

```yaml
name: "my/whitelistlocal"
description: "Whitelist events from my ipv4 addresses"
filter: "1 == 1"
whitelist:
  reason: "my ipv4 ranges"
  ip:
    - "127.0.0.1"
  cidr:
    - "192.168.0.0/16"
```

---

## 🔐 Authelia Setup

### 1. Start the Database

```bash
docker-compose --profile db up -d
```

### 2. Create Authelia Database

```bash
docker exec -it <DB_CONTAINER_ID> mysql -u root -p -e "
CREATE USER 'authelia'@'%' IDENTIFIED BY 'your-secure-password';
GRANT USAGE ON *.* TO 'authelia'@'%';
CREATE DATABASE IF NOT EXISTS \`authelia\`;
GRANT ALL PRIVILEGES ON \`authelia\`.* TO 'authelia'@'%';
"
```

### 3. Generate Password Hash

```bash
docker run --rm authelia/authelia:latest authelia crypto hash generate argon2 --password 'your-secure-password'
```

---

## 📦 Services Overview

| Service | URL | Description |
|--------|-----|-------------|
| **Traefik Dashboard** | `https://traefik.<yourdomain>` | Traefik reverse proxy UI |
| **Authelia** | `https://auth.<yourdomain>` | Authentication gateway |
| **Portainer** | `https://portainer.<yourdomain>` | Docker management UI |
| **Vaultwarden** | `https://vltwrn.<yourdomain>` | Password manager |
| **Uptime Kuma** | `https://kuma.<yourdomain>` | Uptime monitoring |
| **Dozzle** | `https://dozz.<yourdomain>` | Docker logs viewer |
| **What's Up Docker** | `https://wud.<yourdomain>` | Docker update notifier |

---

## ✅ Best Practices

- **Security**: Use secrets management, read-only filesystems, and no-new-privileges policies.
- **Backups**: Regularly back up `appdata/`, `secrets/`, and databases.
- **Monitoring**: Use InfluxDB + Glances or Prometheus + Grafana for metrics.
- **Updates**: Keep containers updated using Watchtower or What's Up Docker.
- **Logs**: Use centralized logging and rotate logs regularly.

---

## 🧰 Maintenance Tips

- Use `docker-compose` profiles to control which services start
- Use `docker-compose config` to validate your configuration
- Regularly check logs for errors and suspicious activity
- Rotate secrets and credentials periodically

---

## 📞 Support

For questions, issues, or feature requests, please open an issue on the GitHub repository.

---

## 📄 License

This project is open-source and available under the MIT License.

---

> **Note:** Always verify the integrity and security of the configuration files and services before deploying to production. This setup is not a one-size-fits-all solution and may require adjustments based on your specific use case and infrastructure.