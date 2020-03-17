#! /bin/bash

set -e -o pipefail

OC="$(realpath "${OC:-"$(command -v oc)"}")"

# Label all worker nodes
"$OC" label no --overwrite -lnode-role.kubernetes.io/worker cluster.ocs.openshift.io/openshift-storage=""

# Remove subscription validation webhook
"$OC" delete validatingwebhookconfigurations/sre-subscription-validation

# Add the upstream community operators
"$OC" apply -f community-operators.yaml
