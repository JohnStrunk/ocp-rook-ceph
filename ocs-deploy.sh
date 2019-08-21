#! /bin/bash

OC="$(realpath "${OC:-"$(command -v oc)"}")"

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
cd "$SCRIPT_DIR" || exit 1

# And machineset that only has 1 instance gets scaled to 2...
MACHINESETS=$("$OC" -n openshift-machine-api get machinesets -o custom-columns=name:metadata.name,replicas:spec.replicas --no-headers  | grep ' 1' | awk '{ print $1 }')
for ms in $MACHINESETS; do
        "$OC" -n openshift-machine-api scale --replicas=2 "machinesets/$ms"
done
"$OC" -n openshift-machine-api get machinesets

NAMESPACE="openshift-storage"
OCS_PATH="https://raw.githubusercontent.com/openshift/ocs-operator/master"
"$OC" apply -f "${OCS_PATH}/deploy/deploy-with-olm.yaml"

while [[ $("$OC" get -n "$NAMESPACE" deployment/ocs-operator -ocustom-columns=ready:status.readyReplicas --no-headers) != "1" ]]; do
        echo Waiting for ocs-operator to be ready
        sleep 10
done

MANIFESTS=(
        storagecluster.yaml
        replicapool.yaml
        mycephfs.yaml
        csi-cephfs.yaml
        csi-rbd.yaml
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
