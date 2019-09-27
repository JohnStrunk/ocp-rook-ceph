#! /bin/bash

OC="$(realpath "${OC:-"$(command -v oc)"}")"

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
cd "$SCRIPT_DIR" || exit 1

# And machinesets for OCS
OCS_INSTANCE_TYPE="m5.4xlarge"
OCS_PER_AZ=1
MACHINESETS=$("$OC" -n openshift-machine-api get machinesets -o custom-columns=name:metadata.name,replicas:spec.replicas --no-headers  | grep ' 1' | grep -v ocs | awk '{ print $1 }')
for ms in $MACHINESETS; do
        "$OC" -n openshift-machine-api get "machinesets/$ms" -ojson |\
        jq --arg inst "$OCS_INSTANCE_TYPE" --arg rep $OCS_PER_AZ '.metadata.name=.metadata.name+"-ocs"|.spec.selector.matchLabels."machine.openshift.io/cluster-api-machineset"=.metadata.name|.spec.template.metadata.labels."machine.openshift.io/cluster-api-machineset"=.metadata.name|.spec.template.metadata.labels."cluster.ocs.openshift.io/openshift-storage" = ""|.spec.template.spec.providerSpec.value.instanceType=$inst|.spec.replicas=($rep|tonumber)|.spec.template.spec.metadata.labels."cluster.ocs.openshift.io/openshift-storage" = ""' |\
        "$OC" -n openshift-machine-api apply -f -
done
"$OC" -n openshift-machine-api get machinesets

NAMESPACE="openshift-storage"
# Upstream deployment
OCS_PATH="https://raw.githubusercontent.com/openshift/ocs-operator/master/deploy/deploy-with-olm.yaml"
# Downstream deployment
#OCS_PATH="http://pkgs.devel.redhat.com/cgit/containers/ocs-registry/plain/deploy-with-olm.yaml?h=ocs-4.2-rhel-8"
"$OC" apply -f "${OCS_PATH}"

while [[ $("$OC" get -n "$NAMESPACE" deployment/ocs-operator -ocustom-columns=ready:status.readyReplicas --no-headers) != "1" ]]; do
        echo Waiting for ocs-operator to be ready
        sleep 10
done

MANIFESTS=(
        storagecluster.yaml
        )
for m in ${MANIFESTS[*]}; do
        "$OC" -n "$NAMESPACE" apply -f "$m"
done

while [[ $("$OC" get -n "$NAMESPACE" cephcluster/openshift-storage -ocustom-columns=health:status.ceph.health --no-headers) != "HEALTH_OK" ]]; do
        echo Waiting for cluster to be healthy
        sleep 10
done

echo Deployment of rook/ceph completed:
"$OC" -n "$NAMESPACE" get po -oyaml | grep -E '(image:|imageID:)' | sort -u

echo Tainting nodes
"$OC" adm taint node -lcluster.ocs.openshift.io/openshift-storage="" node.ocs.openshift.io/storage=true:NoSchedule
