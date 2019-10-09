#! /bin/bash

OC="$(realpath "${OC:-"$(command -v oc)"}")"

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
cd "$SCRIPT_DIR" || exit 1

NAMESPACE="openshift-storage"

"$OC" -n "$NAMESPACE" delete -f storagecluster.yaml

#-- Remove the finalizer so that the NS delete succeeds
"$OC" -n "$NAMESPACE" patch cephclusters/openshift-storage --type merge -p '{"metadata":{"finalizers": [null]}}'

"$OC" delete namespace "$NAMESPACE"

MACHINESETS="$("$OC" -n openshift-machine-api get machinesets -o custom-columns=name:metadata.name --no-headers | grep ocs)"
for ms in $MACHINESETS; do
        "$OC" -n openshift-machine-api delete "machinesets/$ms"
done

"$OC" delete StorageClass/openshift-storage-ceph-rbd
"$OC" delete StorageClass/openshift-storage-cephfs

"$OC" delete -n openshift-marketplace CatalogSource/local-storage-manifests
"$OC" delete -n openshift-marketplace CatalogSource/ocs-catalogsource
