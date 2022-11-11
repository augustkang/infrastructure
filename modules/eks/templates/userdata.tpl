#!/bin/bash
set -e

yum install -y amazon-ssm-agent\nsystemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

/etc/eks/bootstrap.sh ${cluster_name} --apiserver-endpoint ${cluster_endpoint} --b64-cluster-ca ${cluster_ca}
