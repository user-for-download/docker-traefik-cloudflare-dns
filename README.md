# docker-traefik-cloudflare-dns
> Linux 5.15.0-97-generic #107-Ubuntu SMP Wed Feb 7 13:26:48 UTC 2024 x86_64 x86_64 x86_64 GNU/Linux; default user ubuntu (1000,1000)

The latest versions of dockers were used on the publication mark. Now they may not be compatible! Be careful.

## Features
- adquard.yml
- authelia.yml
- crowdsec-db.yml
- crowdsec.yml
- dozzle.yml
- filebr.yml
- glances.yml
- influxdb.yml
- it-tools.yml
- mariadb.yml
- owncloud.yml
- phpmyadmin.yml
- portainer.yml
- redis.yml
- socket-proxy.yml
- syncthing.yml
- traefik-certs-dumper.yml
- traefik.yml
- uptime-kuma.yml
- vaultwarden.yml
- whoami.yml

## Note
> default work path /home/<USERS>

# Clone git
```bash
mkdir git && cd git
git clone https://github.com/user-for-download/docker-traefik-cloudflare-dns.git
```

## Create new secrets for db and authelia
```bash
cd secrets
cd authelia && for i in *; do openssl rand -hex 16 > $i; done && cd ..
cd db && for i in *; do openssl rand -hex 16 > $i; done && cd ..
```
### Change .env
```bash
nano .env
```
```env
##### SYSTEM
PUID=
PGID=
TZ=
DOCKERDIR=/home/<USERS>/git/docker-traefik-cloudflare-dns
APPDIR=/home/<USERS>/git/docker-traefik-cloudflare-dns/appdata

##### DOMAIN
DOMAINNAME_CLOUD_SERVER=<SITE.COM>
TRAEFIK_DOMAINNAME=traefik.<SITE.COM>
------
------
SYNC_DOMAINNAME=sync.<SITE.COM>
```
## Create new acme.json
```bash
touch appdata/traefik/acme/acme.json
chmod 600 appdata/traefik/acme/acme.json
```
## Create networks docker
```bash
docker network create -d bridge socket_proxy --subnet 172.16.80.0/24
docker network create -d bridge net_t2 --subnet 172.16.90.0/24
docker network create -d bridge net_db --subnet 172.16.82.0/23
docker network create -d bridge net_redis --subnet 172.16.84.0/23
```
# After install
## Create logrotate
```bash
nano /etc/logrotate.d/traefik  
```
```bash
/home/<USERS>/git/docker-traefik-cloudflare-dns/logs/traefik/*.log {
  daily
  rotate 30
  missingok
  notifempty
  dateext
  dateformat .%Y-%m-%d
  create 0644 root root
  postrotate
  docker kill --signal="USR1" $(docker ps | grep traefik | awk '{print $1}')
  endscript
}

```
```bash
logrotate /etc/logrotate.conf --debug  
```
## Crowdsec firewall bouncer iptables
```bash
sudo apt install crowdsec-firewall-bouncer-iptables
```
```bash
docker exec -t crowdsec cscli bouncers add host-firewall-bouncer-dshb
```
> pS4zcase9EEyCJQ/IaHDiYYOddutA8HZSsRFGIR8Epg
```bash
sudo nano /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml
```
settings:
> https://www.smarthomebeginner.com/crowdsec-docker-compose-1-fw-bouncer/

```bash	
sudo systemctl restart crowdsec-firewall-bouncer.service
```
```bash	
cat /var/log/crowdsec-firewall-bouncer.log
```