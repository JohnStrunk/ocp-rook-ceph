#! /bin/bash

OC="$(realpath "${OC:-"$(command -v oc)"}")"

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
cd "$SCRIPT_DIR" || exit 1

# Label all worker nodes
"$OC" label no -lnode-role.kubernetes.io/worker cluster.ocs.openshift.io/openshift-storage=""

NAMESPACE="openshift-storage"
# Upstream deployment
#OCS_PATH="https://raw.githubusercontent.com/openshift/ocs-operator/master/deploy/deploy-with-olm.yaml"
# Downstream deployment
# See: https://github.com/red-hat-storage/ocs-ci/blob/master/conf/ocsci/downstream_config.yaml
OCS_PATH="http://pkgs.devel.redhat.com/cgit/containers/ocs-registry/plain/deploy-with-olm.yaml?h=ocs-4.2-rhel-8"

# What is the current DS version?
echo "Deploying:"
skopeo inspect docker://quay.io/rhceph-dev/ocs-registry:latest | jq .Created,.Labels.url || echo "No skopeo?"

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
