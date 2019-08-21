#! /bin/bash

OC="$(realpath "${OC:-"$(command -v oc)"}")"

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
cd "$SCRIPT_DIR" || exit 1

NAMESPACE="openshift-storage"

"$OC" delete StorageClass/csi-cephfs
"$OC" delete StorageClass/csi-rbd

for kind in CephFilesystems CephBlockPools; do
        "$OC" -n "$NAMESPACE" delete "$kind" --all
done

"$OC" -n "NAMESPACE" delete -f storagecluster.yaml
"$OC" -n "$NAMESPACE" delete CephClusters --all

"$OC" delete namespace "$NAMESPACE"
