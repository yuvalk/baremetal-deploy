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
}

function provision_cluster {
    echo "3. do the heavy lifting of bringing the cluster up"
    echo "   this include the needed metal configmap"
}

function run_tests {
    echo 4. clone the repo and run the tests
}

function collect_results {
    echo 5. collect test results as well as any other useful info
}

function teardown {
    echo 6. tear down the cluster to make way for a new run
    rm oc
    rm openshift-baremetal-install
}

retrieve_latest_ocp43
ipmi_shutdown
provision_cluster
run_tests
collect_results
teardown
