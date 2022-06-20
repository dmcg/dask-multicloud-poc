#!/bin/bash
set -e

yum install tree -y
curl -o plantuml.jar -L http://sourceforge.net/projects/plantuml/files/plantuml.jar/download
mv plantuml.jar /usr/local/bin/

./fetch-data.sh
sh -c 'mkdir -p /data && chmod a+rwx /data'