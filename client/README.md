# Data Proximate Dask

A repository looking at how to use Dask for data-proximate compute.

## Installation

[Install miniconda](https://docs.conda.io/en/latest/miniconda.html), then (in a shell with the extensions installed)

```bash
./setup-conda.sh
sudo ./setup-other.sh
```

The Docker container that we use is available on [Docker Hub](https://hub.docker.com/repository/docker/dmcg/irisxarray), but can be built with 

```bash
(cd docker/irisxarray; ./build.sh)
```

and published with

```bash
(cd docker; ./publish.sh)
```

We also use WireGuard for networking into ECMWF and EUMETSAT (the control plane network).

```bash
sudo curl -L -o /etc/yum.repos.d/wireguard.repo https://copr.fedorainfracloud.org/coprs/jdoss/wireguard/repo/epel-7/jdoss-wireguard-epel-7.repo
sudo yum install wireguard-dkms wireguard-tools
```

Download config from https://64.225.130.24/ (mo-ecm-dw) and put it in /etc/wireguard
after `awk ' { gsub("^DNS","#DNS"); gsub("0.0.0.0/0","10.8.0.0/24"); gsub("PersistentKeepalive = 0","PersistentKeepalive = 25"); print } ' YOUR.conf`


## Running

Run JupyterLab with 

```bash
conda activate jupyter
jupyter-lab
```

You can then connect a browser to localhost:8888 to us the workspace.

If running in Cloud9, this presents problems unless you set up ingress in AWS.
Instead I tunnel through ssh from my laptop with something like

```bash
ssh -L 8888:127.0.0.1:8888 dask-play -t 'conda activate jupyter && cd environment && jupyter-lab --no-browser'
```

