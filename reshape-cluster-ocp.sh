#! /bin/bash

set -e -o pipefail

OC="$(realpath "${OC:-"$(command -v oc)"}")"

OCS_INSTANCE_TYPE="m5.4xlarge"
OCS_PER_AZ=1
MACHINESETS=$("$OC" -n openshift-machine-api get machinesets -o custom-columns=name:metadata.name,replicas:spec.replicas --no-headers  | grep ' 1' | grep -v ocs | awk '{ print $1 }')
for ms in $MACHINESETS; do
        "$OC" -n openshift-machine-api get "machinesets/$ms" -ojson |\
        jq --arg inst "$OCS_INSTANCE_TYPE" --arg rep $OCS_PER_AZ '.metadata.name=.metadata.name+"-ocs"|.spec.selector.matchLabels."machine.openshift.io/cluster-api-machineset"=.metadata.name|.spec.template.metadata.labels."machine.openshift.io/cluster-api-machineset"=.metadata.name|.spec.template.metadata.labels."cluster.ocs.openshift.io/openshift-storage" = ""|.spec.template.spec.providerSpec.value.instanceType=$inst|.spec.replicas=($rep|tonumber)|.spec.template.spec.metadata.labels."cluster.ocs.openshift.io/openshift-storage" = ""' |\
        "$OC" -n openshift-machine-api apply -f -
done
"$OC" -n openshift-machine-api get machinesets
