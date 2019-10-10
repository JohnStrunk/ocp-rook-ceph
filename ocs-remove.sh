#! /bin/bash

OC="$(realpath "${OC:-"$(command -v oc)"}")"

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
cd "$SCRIPT_DIR" || exit 1

NAMESPACE="rook-ceph"

"$OC" delete StorageClass/csi-cephfs
"$OC" delete StorageClass/csi-rbd

for kind in CephFilesystems CephBlockPools CephClusters; do
        "$OC" -n "$NAMESPACE" delete "$kind" --all
done

"$OC" delete namespace "$NAMESPACE"
