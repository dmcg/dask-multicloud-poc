FROM dmcg/wireguard_scheduler

COPY xarray-environment.yml .
RUN conda env update --name base -f ./xarray-environment.yml

# we don't actually need this ssh key
RUN rm /root/.ssh/id_rsa