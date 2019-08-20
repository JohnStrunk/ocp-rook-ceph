#! /bin/bash

#--
# See: https://rook.io/docs/rook/master/ceph-csi-drivers.html
#--

OC="$(realpath "${OC:-"$(command -v oc)"}")"

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
cd "$SCRIPT_DIR" || exit 1

# And machineset that only has 1 instance gets scaled to 2...
MACHINESETS=$("$OC" -n openshift-machine-api get machinesets -o custom-columns=name:metadata.name,replicas:spec.replicas --no-headers  | grep ' 1' | awk '{ print $1 }')
for ms in $MACHINESETS; do
        "$OC" -n openshift-machine-api scale --replicas=2 "machinesets/$ms"
done
"$OC" -n openshift-machine-api get machinesets

#-- pull straight from GH. Could also set this to a local copy
ROOK_PATH="https://raw.githubusercontent.com/rook/rook/master"
NAMESPACE="rook-ceph"
MANIFESTS=(
            "${ROOK_PATH}/cluster/examples/kubernetes/ceph/common.yaml"
            "${ROOK_PATH}/cluster/examples/kubernetes/ceph/operator-openshift.yaml"
            "cluster.yaml"
            "replicapool.yaml"
            "mycephfs.yaml"
            "csi-rbd.yaml"
            "csi-cephfs.yaml"
          )

"$OC" create namespace "$NAMESPACE"

for m in ${MANIFESTS[*]}; do
        "$OC" -n "$NAMESPACE" apply -f "$m"
done

while [[ $(../ocp4 get -n "$NAMESPACE" cephcluster/rook-ceph -ocustom-columns=health:status.ceph.health --no-headers) != "HEALTH_OK" ]]; do
        echo Waiting for cluster to be healthy
        sleep 10
done

echo Deployment of rook/ceph completed:
"$OC" -n "$NAMESPACE" get po -oyaml | grep -E '(image:|imageID:)' | sort -u
