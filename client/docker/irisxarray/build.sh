#!/bin/bash
set -e

cp ../../irisxarray-environment.yml .
docker build . -t dmcg/irisxarray
rm irisxarray-environment.yml
