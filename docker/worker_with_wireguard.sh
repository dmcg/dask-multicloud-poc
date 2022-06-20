#!/bin/sh
#
# set up a wireguard VPN back to the mother process, then spawn a dask worker
# this should be passed relevant info via env vars
# e.g.
# export WG_SITE_ID=7
# export WG_GATEWAY_PUB_KEY=yrOBmjwJ8W3S0EBijlYZ0FYVfLUONUSv4Z+FGpCUFWo=
# export WG_GATEWAY_ENDPOINT=10.0.0.101
# export DASK_SCHEDULER=x.x.x.x:8786
# export DASK_WORKER_ID=42
# export WORKER_WG_PRIV_KEY=KBLru+p/Je6bAdIlKS8opuon//AWlJ38OyoTX2aCjWU=
# not passed but handy for testing
# export WG_GATEWAY_PRIV_KEY=WGAxzttj8jS8vz0acgfv9MCeCtv2IY+IVpgOHAapLGk=

: "${WG_SITE_ID:?Need to provide WG_SITE_ID}"
: "${WG_GATEWAY_PUB_KEY:?Need to provide WG_GATEWAY_PUB_KEY}"
: "${WG_GATEWAY_ENDPOINT:?Need to provide WG_GATEWAY_ENDPOINT}"
: "${DASK_SCHEDULER:?Need to provide DASK_SCHEDULER}"
: "${DASK_WORKER_ID:?Need to provide DASK_WORKER_ID}"
: "${WORKER_WG_PRIV_KEY:?Need to provide WORKER_WG_PRIV_KEY}"
: "${POOL_NAME:?Need to provide POOL_NAME}"

WORKER_WG_ADDRESS=fda5:c0ff:eeee:${WG_SITE_ID}::$(( ${DASK_WORKER_ID} + 10 ))

cat > /etc/wireguard/dasklocal.conf << EOF
[Interface]
PrivateKey = ${WORKER_WG_PRIV_KEY}
Address = ${WORKER_WG_ADDRESS}/64
ListenPort = 51820

[Peer]
PublicKey = ${WG_GATEWAY_PUB_KEY}
AllowedIPs = fda5:c0ff:eeee::/48
PersistentKeepalive = 0
Endpoint = ${WG_GATEWAY_ENDPOINT}:51820
EOF

wg-quick up dasklocal
sleep 3
ping -c 10 -6 fda5:c0ff:eeee:${WG_SITE_ID}::1
if [ $? -ne 0 ] ; then
    echo ping to mummy failed - bad
else
    dask-worker --host [${WORKER_WG_ADDRESS}] ${DASK_SCHEDULER} \
        --nworkers auto \
        --resources pool-${POOL_NAME}=1 \
        --name ${POOL_NAME}-${WG_SITE_ID}
fi

