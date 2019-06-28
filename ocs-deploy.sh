#! /bin/bash

#--
# See: https://rook.io/docs/rook/master/ceph-csi-drivers.html
#--

OC="$(realpath "${OC:-"$(command -v oc)"}")"
DEPLOY_BLOCK="${DEPLOY_BLOCK:-1}"

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
cd "$SCRIPT_DIR" || exit 1

#-- pull straight from GH. Could also set this to a local copy
ROOK_PATH="https://raw.githubusercontent.com/rook/rook/master"
NAMESPACE="rook-ceph"
#-- for now, every worker becomes a ceph osd
REPLICAS="$("$OC" get no -lnode-role.kubernetes.io/worker --no-headers | wc -l)"
MANIFESTS=(
            "${ROOK_PATH}/cluster/examples/kubernetes/ceph/common.yaml"
            "${ROOK_PATH}/cluster/examples/kubernetes/ceph/csi/rbac/cephfs/csi-nodeplugin-rbac.yaml"
            "${ROOK_PATH}/cluster/examples/kubernetes/ceph/csi/rbac/cephfs/csi-provisioner-rbac.yaml"
            "${ROOK_PATH}/cluster/examples/kubernetes/ceph/csi/rbac/rbd/csi-nodeplugin-rbac.yaml"
            "${ROOK_PATH}/cluster/examples/kubernetes/ceph/csi/rbac/rbd/csi-provisioner-rbac.yaml"
            "${ROOK_PATH}/cluster/examples/kubernetes/ceph/operator-openshift-with-csi.yaml"
            "cluster.yaml"
            "replicapool.yaml"
            "mycephfs.yaml"
            "csi-rbd.yaml"
            "csi-cephfs.yaml"
          )

echo "Deploying to $REPLICAS workers..."

if [[ "$DEPLOY_BLOCK" -gt 0 ]]; then
        echo Obtaining block devices...
        "$OC" create namespace "$NAMESPACE-blocks"
        "$OC" -n "$NAMESPACE-blocks" apply -f block-pv.yml
        "$OC" -n "$NAMESPACE-blocks" apply -f block-pv.yml
        "$OC" -n "$NAMESPACE-blocks" scale "--replicas=$REPLICAS" statefulset/block-devs
        while [[ $("$OC" -n "$NAMESPACE-blocks" get statefulset/block-devs -ojsonpath='{.status.readyReplicas}') != "$REPLICAS" ]]; do
                echo Waiting for replicas to be ready...
                sleep 5
        done
fi

"$OC" create namespace "$NAMESPACE"

for m in ${MANIFESTS[*]}; do
        "$OC" -n "$NAMESPACE" apply -f "$m"
done

while [[ $("$OC" -n "$NAMESPACE" get po --field-selector='status.phase==Running' | grep rook-ceph-osd | grep -cv prepare) -lt "$REPLICAS" ]]; do
        echo Waiting for OSDs to be running...
        sleep 10
done

#-- retrieve admin key
OPERATOR_POD="$("$OC" -n "$NAMESPACE" get po | grep rook-ceph-operator | awk '{print $1}')"
ADMIN_KEY="$("$OC" -n "$NAMESPACE" exec -it "$OPERATOR_POD" -- ceph auth get-key client.admin)"

#-- Create CSI RBD secret
"$OC" -n "$NAMESPACE" create secret generic csi-rbd-secret "--from-literal=userID=admin" "--from-literal=userKey=$ADMIN_KEY" "--from-literal=adminID=admin" "--from-literal=adminKey=$ADMIN_KEY"

#-- Create CSI CephFS secret
"$OC" -n "$NAMESPACE" create secret generic csi-cephfs-secret "--from-literal=userID=admin" "--from-literal=userKey=$ADMIN_KEY" "--from-literal=adminID=admin" "--from-literal=adminKey=$ADMIN_KEY"
