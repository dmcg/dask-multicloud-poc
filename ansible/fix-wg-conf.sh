#!/bin/bash
awk ' { gsub("^DNS","#DNS"); gsub("0.0.0.0/0","10.8.0.0/24"); gsub("PersistentKeepalive = 0","PersistentKeepalive = 25"); print } ' $1 > $1