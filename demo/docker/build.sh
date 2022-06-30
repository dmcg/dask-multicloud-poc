#!/bin/bash
set -e

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}"; )" &> /dev/null && pwd 2> /dev/null; )";
cd ${SCRIPT_DIR}/xarray

cp ../../xarray-environment.yml .
docker build . -t dmcg/xarray
rm xarray-environment.yml
