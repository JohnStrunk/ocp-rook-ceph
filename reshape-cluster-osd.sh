#! /bin/bash

set -e -o pipefail

OC="$(realpath "${OC:-"$(command -v oc)"}")"

# Label all worker nodes
"$OC" label no --overwrite -lnode-role.kubernetes.io/worker cluster.ocs.openshift.io/openshift-storage=""
