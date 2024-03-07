# docker-traefik-cloudflare-dns
> Ubuntu 22.04.3 LTS (Focal Fossa); default user ubuntu (1000,1000)

The latest versions of dockers were used on the publication mark. Now they may not be compatible! Be careful.

## Features
- traefik
- socket-proxy
- whoami
- portainer

## Create new secrets

```bash
cd secrets
cd authelia && for i in *; do openssl rand -hex 16 > $i; done && cd ..
cd db && for i in *; do openssl rand -hex 16 > $i; done && cd ..
```
## Create new .env
```bash
cp .env.example .env
```
```bash
nano .env
```
## Create new acme.json
```bash
touch appdata/traefik/acme/acme.json
chmod 600 appdata/traefik/acme/acme.json
```
## Create new network
```bash
docker network create -d bridge socket_proxy --subnet 172.16.80.0/24
docker network create -d bridge net_t2 --subnet 172.16.90.0/24
docker network create -d bridge net_db --subnet 172.16.82.0/23
docker network create -d bridge net_redis --subnet 172.16.84.0/23
```

## Create logrotate
```bash
nano /etc/logrotate.d/traefik  
```
```bash
compress
/home/<USERS>/git/docker-traefik-cloudflare-dns/logs/traefik/*.log {
  daily
  rotate 30
  missingok
  notifempty
  compress
  dateext
  dateformat .%Y-%m-%d
  create 0644 root root
  postrotate
  docker kill --signal="USR1" $(docker ps | grep traefik | awk '{print $1}')
  endscript
}

logrotate /etc/logrotate.conf --debug 
```
