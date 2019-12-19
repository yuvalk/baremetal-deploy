#!/bin/bash

export CLUSTER_NAME=fci1
export BASE_DOMAIN=kni.lab.eng.bos.redhat.com

export SSH_KEY=$(cat ~/.ssh/id_rsa.pub | tr -d '\n')

export EXTERNAL_BRIDGE="baremetal"
export PROVISIONING_BRIDGE="provisioning"

export MASTER_0_IPMI="10.19.232.3"
export WORKER_0_IPMI="10.19.232.4"
export WORKER_1_IPMI="10.19.232.5"
export IPMI_IPS=(${MASTER_0_IPMI} ${WORKER_0_IPMI} ${WORKER_1_IPMI})

export MASTER_0_MAC="98:03:9b:87:0b:5e"
export WORKER_0_MAC="98:03:9b:8e:8a:04"
export WORKER_1_MAC="98:03:9b:8e:89:ec"

export API_VIP="10.19.232.133"
export DNS_VIP="10.19.232.134"
export INGRESS_VIP="10.19.232.135"
export MACHINE_CIDR="10.19.232.128/25"

export INSTALLER_IP="10.19.232.132"
