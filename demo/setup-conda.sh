#!/bin/bash
set -e

conda env create -f xarray-environment.yml
conda create --name jupyter --clone xarray -y
conda env update -f jupyter-environment.yml