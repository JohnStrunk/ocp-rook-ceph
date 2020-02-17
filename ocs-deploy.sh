#! /bin/bash

OC="$(realpath "${OC:-"$(command -v oc)"}")"

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
cd "$SCRIPT_DIR" || exit 1

NAMESPACE="openshift-storage"

"$OC" apply -n openshift-marketplace -f catalog-source.yaml
"$OC" create ns "$NAMESPACE"
"$OC" apply -n "$NAMESPACE" -f operator-group.yaml
"$OC" apply -n "$NAMESPACE" -f subscription.yaml

while [[ $("$OC" get -n "$NAMESPACE" deployment/ocs-operator -ocustom-columns=ready:status.readyReplicas --no-headers) != "1" ]]; do
        echo Waiting for ocs-operator to be ready
        sleep 10
done

"$OC" -n "$NAMESPACE" apply -f storagecluster.yaml

while [[ $("$OC" get -n "$NAMESPACE" cephcluster/openshift-storage-cephcluster -ocustom-columns=health:status.ceph.health --no-headers) != "HEALTH_OK" ]]; do
        echo Waiting for cluster to be healthy
        sleep 10
done

echo Running sanity check
SANITYNS="sanity-$NAMESPACE"
"$OC" create ns "$SANITYNS"
"$OC" -n "$SANITYNS" apply -f sanity.yaml
while [[ $("$OC" -n "$SANITYNS" get job/rbd -ocustom-columns=ready:status.succeeded --no-headers) != "1" ]]; do
        "$OC" -n "$SANITYNS" get pvc/rbd
        sleep 10
done
while [[ $("$OC" -n "$SANITYNS" get job/cephfs -ocustom-columns=ready:status.succeeded --no-headers) != "1" ]]; do
        "$OC" -n "$SANITYNS" get pvc/cephfs
        sleep 10
done
"$OC" delete ns "$SANITYNS"

echo Deployment of rook/ceph completed:
"$OC" -n "$NAMESPACE" get po -oyaml | grep -E '(image:|imageID:)' | sort -u
