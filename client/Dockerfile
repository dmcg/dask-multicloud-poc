FROM dmcg/wireguard_scheduler

COPY irisxarray-environment.yml .
RUN conda env update --name base -f ./irisxarray-environment.yml

# we don't actually need this ssh key
RUN rm /root/.ssh/id_rsa