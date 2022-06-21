#!/bin/bash

# Stops all running containers then removes all stopped containers
running=`docker ps -a -q`
if [ -n "$running" ]; then
    docker stop $running
    docker container prune --force
else
    echo nothing active
fi
