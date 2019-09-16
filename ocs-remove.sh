#! /bin/bash

OC="$(realpath "${OC:-"$(command -v oc)"}")"

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
cd "$SCRIPT_DIR" || exit 1

NAMESPACE="openshift-storage"

"$OC" -n "$NAMESPACE" delete -f storagecluster.yaml

"$OC" delete StorageClass/openshift-storage-ceph-rbd
"$OC" delete StorageClass/openshift-storage-cephfs

# Still needed?
"$OC" -n "$NAMESPACE" delete CephClusters --all

"$OC" delete namespace "$NAMESPACE"

MACHINESETS="$("$OC" -n openshift-machine-api get machinesets -o custom-columns=name:metadata.name --no-headers | grep ocs)"
for ms in $MACHINESETS; do
        "$OC" -n openshift-machine-api delete "machinesets/$ms"
done
