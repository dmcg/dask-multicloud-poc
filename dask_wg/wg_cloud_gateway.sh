#!/bin/bash
#
# This script is triggered by the scheduler, once per site.
# It sets up a wireguard router that talks back to the scheduler but also to
# all other sites in a mesh network.
# It then spawns workers as docker containers, which bind back to this router
# via wireguard.
# The result is a mesh network of sites (via these routers), with each router
# having a series of workers hanging off it.
#
# The router must be reachable by all sites on the wireguard port, meaning it
# needs a public IP or at least an exposed/forwarded UDP port
#
# Internally, the wireguard network uses a private IPv6 network for
# intercommunication between schedulers and workers.  This allows us to avoid
# any clashes with IPv4 private ranges, which are mostly all committed.  It also
# permits a very simple and fixed address structure:
#  <static_private_component>:<site_id>:<node id>
# static = fda5:c0ff:eeee
# site id: 0=scheduler, 1=site 1, 2=site 2, etc
# node id: 1 = router or scheduler, 11 = worker 1, 12 = worker 2, etc
#
# examples:
#  fda5:c0ff:eeee:0::1  = always the scheduler IP
#  fda5:c0ff:eeee:1::1  = router on site 1
#  fda5:c0ff:eeee:3::12 = worker 2 on site 3
#
# Currently this receives necessary info via command line (typically over ssh)
# but it could be easily changed to K8S


echo
echo Starting up workers on host $(hostname)

if [ $# != 4 ] ; then
    echo "$0 myPrivKey site_id num_workers cloudconf_string"
    exit 1
fi

DOCKER_IMAGE=dmcg/irisxarray
WG_GATEWAY_PRIV_KEY=$1
WG_SITE_ID=$2
# TODO format description
NUM_WORKERS=$3
CLOUD_CONFIGS=$4
POOL_NAME=${DASK_POOL_NAME?"Needs DASK_POOL_NAME in environment"}


# work out our public key from the private key
WG_GATEWAY_PUB_KEY=$(echo ${WG_GATEWAY_PRIV_KEY} | wg pubkey)

# permanently hard coded scheduler IP and port
DASK_SCHEDULER=[fda5:c0ff:eeee:0::1]:8786

# this should be the IP of this wireguard server as seen by the workers-to-be
# TODO: this needs to be detected, but is basically the docker interface IP on a plain machine.  Not sure on k8s.
WG_GATEWAY_ENDPOINT=172.17.0.1

# Set up wireguard config, first the local config
cat > /etc/wireguard/dasklocal.conf << EOF
[Interface]
PrivateKey = ${WG_GATEWAY_PRIV_KEY}
Address = fda5:c0ff:eeee:${WG_SITE_ID}::1/64
ListenPort = 51820

EOF

# now add peer configs for each of the other routers
# based on what the scheduler told us
for othercloud in $(echo $CLOUD_CONFIGS | tr , \\n) ; do
    other_siteid=$(echo $othercloud | cut -f1 -d:)
    other_pubkey=$(echo $othercloud | cut -f2 -d:)
    other_endpoint=$(echo $othercloud | cut -f3 -d:)
    
cat >> /etc/wireguard/dasklocal.conf << EOF
# config for cloud ${othercloud}
[Peer]
PublicKey = ${other_pubkey}
AllowedIPs = fda5:c0ff:eeee:${other_siteid}::0/64
PersistentKeepalive = 25
Endpoint = ${other_endpoint}:51820

EOF
done

# bring up the wireguard interface
wg-quick up dasklocal

# switch on forwarding
# we have to enable forwarding in general for the kernel to ship packets.
sysctl net.ipv6.conf.all.forwarding=1
# I wanted to just enable it on the dask wireguard interface, but
# no packets move :(  Leaving it here in case someone is smarter than me.
#sysctl net.ipv6.conf.dasklocal.forwarding=1
ip6tables -A FORWARD -i dasklocal --jump ACCEPT


# Create workers
DASK_WORKER_ID=1
for (( ; DASK_WORKER_ID <= ${NUM_WORKERS}; DASK_WORKER_ID++)) ; do

    echo Spawning worker ${DASK_WORKER_ID} on site ${WG_SITE_ID}

    # generate keys for this new worker
    WORKER_WG_PRIV_KEY=$(wg genkey)
    WORKER_WG_PUB_KEY=$(echo ${WORKER_WG_PRIV_KEY} | wg pubkey)

    # spawn the worker
    # TODO: change this to k8s.  Optionally add a healthcheck and wait.
    DASK_WORKER_CONTAINER_ID=$(docker run --rm -d \
        --name dask-worker-${DASK_WORKER_ID} \
        --user root \
        --cap-add=NET_ADMIN --cap-add=SYS_MODULE \
        --sysctl net.ipv6.conf.all.disable_ipv6=0 \
         --mount type=bind,source=/data/${POOL_NAME},target=/data/${POOL_NAME} \
        -e DASK_SCHEDULER=${DASK_SCHEDULER} \
        -e DASK_WORKER_ID=${DASK_WORKER_ID} \
        -e WG_GATEWAY_PUB_KEY=${WG_GATEWAY_PUB_KEY} \
        -e WG_GATEWAY_ENDPOINT=${WG_GATEWAY_ENDPOINT} \
        -e WG_SITE_ID=${WG_SITE_ID} \
        -e WORKER_WG_PRIV_KEY=${WORKER_WG_PRIV_KEY} \
        -e POOL_NAME=${POOL_NAME} \
        ${DOCKER_IMAGE} \
        worker_with_wireguard.sh )

    # get this container's IP
    sleep 5
    WORKER_WG_ENDPOINT=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${DASK_WORKER_CONTAINER_ID})

    # set up peer config for new worker
    cat >> /etc/wireguard/dasklocal.conf << EOF

# config for worker ${DASK_WORKER_ID}
[Peer]
PublicKey = ${WORKER_WG_PUB_KEY}
AllowedIPs = fda5:c0ff:eeee:${WG_SITE_ID}::$(( ${DASK_WORKER_ID} + 10 ))/128
PersistentKeepalive = 25
Endpoint = ${WORKER_WG_ENDPOINT}:51820
EOF

    # update the running wireguard
    wg syncconf dasklocal <(wg-quick strip dasklocal)

done

