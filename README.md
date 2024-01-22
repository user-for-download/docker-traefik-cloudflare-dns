# docker-traefik-cloudflare-dns
 docker-traefik-cloudflare-dns

mkdir secrets

touch $DOCKERDIR/appdata/traefik2/acme/acme.json
chmod 600 $DOCKERDIR/appdata/traefik2/acme/acme.json

docker network create -d bridge socket_proxy --subnet 172.16.80.0/24
docker network create -d bridge t2_proxy --subnet 172.16.90.0/24
docker network create -d bridge t2_mntr --subnet 172.16.100.0/28


  net_mntr:
    name: net_mntr
    driver: bridge
    ipam:
      config:
        - subnet: 172.16.100.0/28