#!/bin/bash
set -e

# Pass varargs of user@workerhost to start scheduler and clients
# You can connect to the scheduler with 
# client = dask.distributed.Client("localhost:8786")

docker run \
    --user root \
    --rm \
    -p 8786:8786 \
    -p 8787:8787 \
    --cap-add=NET_ADMIN \
    --cap-add=SYS_MODULE \
    --sysctl net.ipv6.conf.all.disable_ipv6=0 \
    --sysctl net.ipv6.conf.default.forwarding=1 \
    --name dask-scheduler \
    -i \
    dmcg/wireguard_scheduler spawn_multi_cloud_dask.py "$@"
