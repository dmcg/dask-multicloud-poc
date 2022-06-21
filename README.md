# Dask Multicloud Proof of Concept

We have devised a technique for creating a Dask cluster where worker nodes are hosted in different data centres, connected by a mesh VPN that allows the scheduler and workers to communicate and exchange results. A novel Dask hack means that we can run data processing tasks on the workers in the cluster closest to the source data, so that communication between data centres is minimised. When combined with zarr to give access to huge hyper-cube datasets in object storage, we believe that the technique has the potential to allow data-proximate distributed computing in the Cloud.

It is very much proof of concept - designed to document what is possible rather
than to be a reuseable system.

We show the working of the system in a Jupyter notebook 
[dask-multi-cloud.ipynb](./demo/dask-multi-cloud.ipynb) and more details in 
[dask-multi-cloud-details.ipynb](./demo/dask-multi-cloud-details.ipynb).

