#!/bin/bash
set -e

conda env create -f irisxarray-environment.yml
conda create --name jupyter --clone irisxarray -y
conda env update -f jupyter-environment.yml