#!/bin/bash -e

if [ -z ${PULL_SECRET_FILE+x} ]; then
    PULL_SECRET_FILE=`pwd`/pull-secert.txt
fi
echo pull secert file: ${PULL_SECRET_FILE}

function retrieve_latest_ocp43 {
    echo 1. retrieving latest ocp43 binaries
    VERSION=$(curl -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp-dev-preview/latest-4.3/release.txt | grep 'Name:' | awk -F: '{print $2}' | xargs)
    RELEASE_IMAGE=$(curl -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp-dev-preview/latest-4.3/release.txt | grep 'Pull From: quay.io' | awk -F ' ' '{print $3}' | xargs)

    cmd=openshift-baremetal-install
    extract_dir=$(pwd)

    curl -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp-dev-preview/latest-4.3/openshift-client-linux-$VERSION.tar.gz | tar zxvf - oc

    ./oc adm release extract --registry-config "${PULL_SECRET_FILE}" --command=$cmd --to "${extract_dir}" ${RELEASE_IMAGE}

    #sudo cp openshift-baremetal-install /usr/local/bin/openshift-baremetal-install

    # print versions
    ./oc version
    ./openshift-baremetal-install version
}

function ipmi_shutdown {
    echo 2. use ipmi to make sure servers are down
    set +e
    ipmitool -I lanplus -H 10.19.232.3 -U root -P calvin chassis power off
    ipmitool -I lanplus -H 10.19.232.4 -U root -P calvin chassis power off
    ipmitool -I lanplus -H 10.19.232.5 -U root -P calvin chassis power off
    set -e
}

function prepare_config {
    echo "3.1 prepare install-config.yaml"
    echo "    mainly by appending ssh-key and pull secret"
    echo "    the pull secret need also add kni registry"

    cp ../install-config.yaml.template install-config.yaml
    
    sed -i -e 's/${IPMI_USER}/'"${IPMI_USER}"'/g' install-config.yaml
    sed -i -e 's/${IPMI_PASSWORD}/'"${IPMI_PASSWORD}"'/g' install-config.yaml

    sed -i -e 's#${SSH_KEY}#'"$(cat ~/.ssh/id_rsa.pub | tr -d '\n')"'#g' install-config.yaml

    PULL_SECRET=`jq --argjson registry "$(cat ${KNI_SECRET_FILE} | jq '.')" '.auths += $registry' ${PULL_SECRET_FILE} | tr -d '\n'`
    sed -i -e 's/${PULL_SECRET}/'"$PULL_SECRET"'/g' install-config.yaml
}

function provision_cluster {
    echo "3. do the heavy lifting of bringing the cluster up"
    echo "   this include the needed metal configmap"
    prepare_config

    mkdir testcluster
    cp install-config.yaml testcluster/
    ./openshift-baremetal-install --dir=testcluster create manifests
    cp install-config.yaml testcluster/
    cp ../metal3-config.yaml testcluster/openshift/99_metal3-config.yaml
    ./openshift-baremetal-install --dir=testcluster --log-level debug create cluster
}

function run_tests {
    echo 4. clone the repo and run the tests
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

mkdir discardable_run
cd discardable_run

retrieve_latest_ocp43
ipmi_shutdown
provision_cluster
run_tests
collect_results

#teardown
