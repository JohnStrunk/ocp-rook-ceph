#! /bin/bash

OC="$(realpath "${OC:-"$(command -v oc)"}")"

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
cd "$SCRIPT_DIR" || exit 1

NAMESPACE="openshift-storage"

"$OC" delete ns "sanity-$NAMESPACE"
"$OC" -n "$NAMESPACE" delete --wait=true -f storagecluster.yaml

#-- Remove the finalizer so that the NS delete succeeds
#"$OC" -n "$NAMESPACE" patch cephclusters/openshift-storage-cephcluster --type merge -p '{"metadata":{"finalizers": [null]}}'

"$OC" delete --wait=true namespace "$NAMESPACE"
"$OC" delete -f catalog-source.yaml

"$OC" delete StorageClass/openshift-storage-ceph-rbd
"$OC" delete StorageClass/openshift-storage-cephfs

"$OC" delete -n openshift-marketplace CatalogSource/local-storage-manifests
"$OC" delete -n openshift-marketplace CatalogSource/ocs-catalogsource
