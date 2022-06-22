# Dask Multicloud Proof of Concept

We have devised a technique for creating a Dask cluster where worker nodes are 
hosted in different data centres, connected by a mesh VPN that allows the
scheduler and workers to communicate and exchange results.

A novel (ab)use of Dask resources allows us to run data processing tasks on the
workers in the cluster closest to the source data, so that communication between
data centres is minimised. If combined with zarr to give access to huge
hyper-cube datasets in object storage, we believe that the technique could 
realise the potential to allow data-proximate distributed computing in the Cloud.

This repository documents a running proof-of-concept that addresses these problems.
It contains

## ./demo/

We show the working of the system in a Jupyter notebook

[dask-multi-cloud.ipynb](./demo/dask-multi-cloud.ipynb) 

and more details in 

[dask-multi-cloud-details.ipynb](./demo/dask-multi-cloud-details.ipynb).

## ./build.sh

Builds the Docker image used to host the scheduler and workers.

## ./docker/

Resources for the Docker image.

## ./ansible

An example Ansible playbook showing how to commission worker machines.

## ./start-cluster

A script to start a Dask scheduler and a distributed cluster.