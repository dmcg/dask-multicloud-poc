#!/bin/bash
set -e

conda create --name ansible -y
conda activate ansible
conda install -c conda-forge ansible -y