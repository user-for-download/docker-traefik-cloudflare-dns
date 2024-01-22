# docker-traefik-cloudflare-dns
> 20.04.5 LTS (Focal Fossa); default user ubuntu (1000,1000)

The latest versions of dockers were used on the publication mark. Now they may not be compatible! Be careful.

## Features
- traefik
- socket-proxy
- whoami
- portainer

## Create new secrets

```bash
mkdir secrets
openssl rand -hex 16 > secrets/pwd
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
docker network create -d bridge t2_proxy --subnet 172.16.90.0/24
```
