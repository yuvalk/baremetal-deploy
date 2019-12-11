#!/bin/bash

function retrieve_latest_ocp43 {
    echo 1. retrieving latest ocp43 binaries
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
}

retrieve_latest_ocp43
ipmi_shutdown
provision_cluster
run_tests
collect_results
teardown
