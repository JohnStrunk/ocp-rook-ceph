#! /bin/bash

set -e -o pipefail

OC="$(realpath "${OC:-"$(command -v oc)"}")"

# Label all worker nodes
"$OC" label no --overwrite -lnode-role.kubernetes.io/worker cluster.ocs.openshift.io/openshift-storage=""

# Add the upstream community operators
#"$OC" apply -f community-operators.yaml
"$OC" -n openshift-marketplace patch operatorsource/osd-curated-community-operators --type merge -p '{"spec":{"registryNamespace": "community-operators"}}'
# Add full RH operators (for OCS)
"$OC" -n openshift-marketplace patch operatorsource/osd-curated-redhat-operators --type merge -p '{"spec":{"registryNamespace": "redhat-operators"}}'
