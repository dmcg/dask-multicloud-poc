#!/usr/bin/env python3
#
# Runs in a Docker container and manages a Dask scheduler and cluster.
#
# start scheduler and wireguard gateway
# connect to remote clouds and spawn gateways and workers there, connecting back
# to the scheduler and to each other
#
# See start-scheduler.sh for invocation
#

import subprocess
import sys
import time
import collections
import textwrap


# hard coded, universal IP for the scheduler
DASK_SCHEDULER_IP = "fda5:c0ff:eeee:0::1"

NUM_WORKERS_PER_SITE = 1 # TODO: make this an argument, ideally per site

CloudConfig = collections.namedtuple('CloudConfig',
                                     ['user_and_ip', 'privkey', 'pubkey', 'siteid', 'endpoint']
                                     )


# noinspection PyUnusedLocal
def wireguard_keypair(site_id):
    """return a wireguard key pair (private, public)"""
    privkey = subprocess.check_output(["wg", "genkey"], encoding="utf-8").strip()
    pubkey = subprocess.check_output(["wg", "pubkey"], input=privkey, encoding="utf-8").strip()
    return privkey, pubkey


def main(
        users_at_hosts,
        keypair_generator=wireguard_keypair,
        subprocess_module=subprocess,
        time_module=time,
        conf_file="/etc/wireguard/dasklocal.conf"
):
    """
    Starts a wireguard interface, a scheduler, and workers on remote machines
    """

    # TODO: make this a docker spawn instead, so many of these things are simplified

    def generate_configs(clouds):
        return [config_for(cloud, site_counter + 1) for site_counter, cloud in enumerate(clouds)]

    def config_for(cloud, site_id):
        priv, pub = keypair_generator(site_id)
        return CloudConfig(user_and_ip=cloud, privkey=priv, pubkey=pub, siteid=site_id, endpoint=cloud.split("@")[-1])

    def start_wg(sched_privkey, configs, conf_file):
        write_configs_to(conf_file, sched_privkey, configs)
        subprocess_module.check_call(["wg-quick", "up", "dasklocal"])
        time_module.sleep(1)
        # TODO: do we need to do this, as there shouldn't be anything behind the scheduler
        subprocess_module.check_call(["ip6tables", "-A", "FORWARD", "-i", "dasklocal", "--jump", "ACCEPT"])

    try:
        # detect our own IP (cheesy, might work 100%)
        my_ip = subprocess_module.check_output(["curl", "--silent", "ifconfig.co"]).decode("utf-8").strip()
        print(f"Detected public IP is {my_ip} but we have no easy way to check if this is NATted or not")
        
        sched_privkey, sched_pubkey = keypair_generator('scheduler')
        configs = generate_configs(users_at_hosts)

        start_wg(sched_privkey, configs, conf_file)

        print("Starting the scheduler (give me 5 secs)")
        scheduler = subprocess_module.Popen(["dask-scheduler"], stdout=sys.stdout, stderr=sys.stderr)
        time_module.sleep(5)  # wait for it to come up

        remotes = [SSHRemote(config, subprocess_module) for config in configs]

        print("Spawning worker gateways")
        for remote in remotes:
            remote.start_workers(configs, sched_pubkey, my_ip)

        # theoretically everything is now up, so hand over to the scheduler and wait for it to quit
        try:
            scheduler.communicate()
        except KeyboardInterrupt:
            pass  # don't die yet, do the shutdown instead
            # TODO: better catching mechanism needed, this only gets ctrl-c but not other ways of getting a sigINT

        print("Killing remote workers")
        for remote in remotes:
            remote.kill_workers()

    except subprocess_module.CalledProcessError as x:
        print(f"Subprocess output for {x} was {x.output}")
        raise x

    # and exit..


def write_configs_to(conf_file, sched_privkey, configs):
    with open(conf_file, "w") as wgconfig:
        print(textwrap.dedent(f"""
            [Interface]
            PrivateKey = {sched_privkey}
            Address = {DASK_SCHEDULER_IP}/64
            ListenPort = 51820"""),
              file=wgconfig)
        for config in configs:
            print(textwrap.dedent(f"""
                # config for cloud {config.user_and_ip}
                [Peer]
                PublicKey = {config.pubkey}
                AllowedIPs = fda5:c0ff:eeee:{config.siteid}::0/64
                PersistentKeepalive = 25
                Endpoint = {config.endpoint}:51820"""),
                  file=wgconfig)


class SSHRemote:
    def __init__(self, config: CloudConfig, subprocess_module):
        self.config = config
        self.subprocess_module = subprocess_module

    def start_workers(self, all_configs, sched_pubkey, sched_endpoint):
        """
        SSH to the remote control node and start up a gateway there.
        
        Nodes are pre-configured with passwordless ssh auth and sudo, Docker, WireGuard
        and the wg_cloud_gateway.sh script
        
        This could all be achieved with K8S
        """
        other_configs = [c for c in all_configs if c != self.config]
        cloud_confs = f"0:{sched_pubkey}:{sched_endpoint},"
        for other_config in other_configs:
            cloud_confs += f"{other_config.siteid}:{other_config.pubkey}:{other_config.endpoint},"

        self.subprocess_module.check_output(
            ["ssh", "-o", "StrictHostKeyChecking accept-new", self.config.user_and_ip,
             "sudo",
             "dask_wg/wg_cloud_gateway.sh", self.config.privkey, f"{self.config.siteid}", str(NUM_WORKERS_PER_SITE),
             cloud_confs[:-1]
             ],
            stderr=subprocess.STDOUT
        )

    def kill_workers(self):
        docker_kills = []
        for worker_id in range(1, NUM_WORKERS_PER_SITE+1):
            docker_kills += [";", "docker", "kill", "dask-worker-%d" % worker_id]
        self.subprocess_module.check_output(
            ["ssh", "-o", "StrictHostKeyChecking accept-new", self.config.user_and_ip,
                "sudo", "bash", "-c", "'", "wg-quick", "down", "dasklocal"] + docker_kills + ["'"]
        )


if __name__ == '__main__':
    # very dumb arguments check
    if len(sys.argv) < 2:
        print("args are ssh addresses for remote clouds, e.g. mgrant@64.225.129.36")
        sys.exit(1)

    main(sys.argv[1:], wireguard_keypair, subprocess)
