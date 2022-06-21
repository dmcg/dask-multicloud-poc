#!/bin/bash
sudo ip addr show mo-aws-ec2
if [ $? -ne 0 ]; then
    wg-quick up mo-aws-ec2
fi