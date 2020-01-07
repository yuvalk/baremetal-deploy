#!/bin/bash -e

if [ -z ${PULL_SECRET_FILE+x} ]; then
    PULL_SECRET_FILE=`pwd`/pull-secert.txt
fi
echo pull secert file: ${PULL_SECRET_FILE}

if [ -z ${KNI_SECRET_FILE+x} ]; then
    KNI_SECRET_FILE=`pwd`/kni-secret.txt
fi
echo kni secret file: S{KNI_SECRET_FILE}

if [ -z ${OCP_RELEASE+x} ]; then
    OCP_RELEASE=latest-4.3
fi
echo installing ocp-dev-preview ${OCP_RELEASE}

function retrieve_ocp43 {
    echo 1. retrieving ocp binaries from ${OCP_RELEASE}
    VERSION=$(curl -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp-dev-preview/${OCP_RELEASE}/release.txt | grep 'Name:' | awk -F: '{print $2}' | xargs)
    RELEASE_IMAGE=$(curl -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp-dev-preview/${OCP_RELEASE}/release.txt | grep 'Pull From: quay.io' | awk -F ' ' '{print $3}' | xargs)

    cmd=openshift-baremetal-install
    extract_dir=$(pwd)

    curl -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp-dev-preview/${OCP_RELEASE}/openshift-client-linux-$VERSION.tar.gz | tar zxvf - oc

    ./oc adm release extract --registry-config "${PULL_SECRET_FILE}" --command=$cmd --to "${extract_dir}" ${RELEASE_IMAGE}

    #sudo cp openshift-baremetal-install /usr/local/bin/openshift-baremetal-install

    # print versions
    ./oc version
    ./openshift-baremetal-install version
}

function ipmi_shutdown {
    echo 2. use ipmi to make sure servers are down
    set +e
    for host_ip in ${IPMI_IPS[@]}; do
        ipmitool -I lanplus -H ${host_ip} -U root -P calvin chassis power off &
    done
    wait
    set -e
}

function prepare_config {
    echo "3.1 prepare install-config.yaml"
    echo "    mainly by appending ssh-key and pull secret"
    echo "    the pull secret need also add kni registry"

    export PULL_SECRET=`jq --argjson registry "$(cat ${KNI_SECRET_FILE} | jq '.')" '.auths += $registry' ${PULL_SECRET_FILE} | tr -d '\n'`
    envsubst < ../install-config.yaml.template > install-config.yaml

    cp ../metal3-config.yaml metal3-config.yaml.sample
    export COMMIT_ID=$(./openshift-baremetal-install version | grep '^built from commit' | awk '{print $4}')
    export RHCOS_URI=$(curl -s -S https://raw.githubusercontent.com/openshift/installer/$COMMIT_ID/data/data/rhcos.json | jq .images.openstack.path | sed 's/"//g')
    export RHCOS_PATH=$(curl -s -S https://raw.githubusercontent.com/openshift/installer/$COMMIT_ID/data/data/rhcos.json | jq .baseURI | sed 's/"//g')
    envsubst < metal3-config.yaml.sample > metal3-config.yaml
}

function provision_cluster {
    echo "3. do the heavy lifting of bringing the cluster up"
    echo "   this include the needed metal configmap"
    prepare_config

    mkdir testcluster
    cp install-config.yaml testcluster/
    ./openshift-baremetal-install --dir=testcluster create manifests
    cp install-config.yaml testcluster/

    mv metal3-config.yaml testcluster/openshift/99_metal3-config.yaml

    set +e
    ./openshift-baremetal-install --dir=testcluster --log-level debug create cluster
    set -e
    ./openshift-baremetal-install --dir=testcluster --log-level debug wait-for bootstrap-complete
    ./openshift-baremetal-install --dir=testcluster --log-level debug wait-for install-complete

    export KUBECONFIG=`pwd`/testcluster/auth/kubeconfig
}

function configure_cluster {
	# This is specialized configuration for the test env.
	# in our case, 1 master
	
	# disable CVO
	oc scale --replicas 0 -n openshift-cluster-version deployments/cluster-version-operator
	# keep only a single etcd-quorum-guard
	oc scale --replicas 1 -n openshift-machine-config-operator deployments/etcd-quorum-guard
}

function deploy_cnf {
    echo 4. deploy cnf
    # label workers
    ./oc label node/master-1.fci1.kni.lab.eng.bos.redhat.com node-role.kubernetes.io/worker-rt=""
    ./oc label node/master-2.fci1.kni.lab.eng.bos.redhat.com node-role.kubernetes.io/worker-rt=""

    pushd `pwd`
    cd ../../features
    . hack/test_env.sh
    . hack/common.sh

    make deploy

    popd
}

function run_ose_tests {
    echo 5. run the tests
    git clone https://github.com/openshift/origin
    pushd `pwd`
    cd origin
    make build WHAT=cmd/openshift-tests
    _output/local/bin/linux/amd64/openshift-tests run conformance/serial --dry-run | grep -v -E "API data in etcd|Managed cluster should grow" | _output/local/bin/linux/amd64/openshift-tests run -f -
    popd
}

function collect_results {
    echo 5. collect test results as well as any other useful info
}

function teardown {
    echo 6. tear down the cluster to make way for a new run
    #ipmi_shutdown
    rm oc
    rm openshift-baremetal-install

    cd ..
    rm -fr discardable_run
}

source env.sh
cd "$(dirname "$0")"
mkdir discardable_run
cd discardable_run

retrieve_ocp43
ipmi_shutdown
provision_cluster
configure_cluster
run_ose_tests
deploy_cnf
run_ose_tests
run_tests
collect_results

#teardown
