FROM continuumio/miniconda3

SHELL ["/bin/bash", "-c"]

RUN apt-get update
RUN apt-get install -y wireguard iproute2 iputils-ping curl iptables tcpdump && \
    apt-get clean

RUN conda update -n base -c defaults conda

# we update the base environment in order not to have to conda activate in containers
COPY environment.yml .
RUN conda env update --name base -f ./environment.yml

# this is the private key, the public key is on the control nodes
COPY id_rsa /root/.ssh/
RUN chmod -R go-rwx /root/.ssh

# we can be both scheduler and worker
COPY spawn_multi_cloud_dask.py worker_with_wireguard.sh /usr/local/bin/
