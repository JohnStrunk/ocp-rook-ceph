#! /bin/bash

OC="$(realpath "${OC:-"$(command -v oc)"}")"

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
cd "$SCRIPT_DIR" || exit 1

NAMESPACE="rook-ceph"

../ocp4 delete StorageClass/csi-cephfs
../ocp4 delete StorageClass/csi-rbd

for kind in CephFilesystems CephBlockPools CephClusters; do
        ../ocp4 -n "$NAMESPACE" delete "$kind" --all
done

../ocp4 delete namespace "$NAMESPACE"
