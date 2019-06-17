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
../ocp4 delete namespace "$NAMESPACE-blocks"

# For some reason, we can only create privileged containers in the default
# namespace
../ocp4 create -f - <<CLEANERDS
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: ceph-cleaner
  namespace: default
  labels:
    k8s-app: ceph-cleaner
spec:
  selector:
    matchLabels:
      name: ceph-cleaner
  template:
    metadata:
      labels:
        name: ceph-cleaner
    spec:
      containers:
        - name: centos
          image: centos:7
          command: ["/bin/bash", "-c"]
          args: ["rm -rfv /host/var/lib/rook && touch /tmp/done && sleep infinity"]
          readinessProbe:
            exec:
              command: ["stat", "/tmp/done"]
            initialDelaySeconds: 1
            periodSeconds: 1
          securityContext:
            privileged: true
          volumeMounts:
            - name: host
              mountPath: /host
      terminationGracePeriodSeconds: 1
      volumes:
        - name: host
          hostPath:
            path: /
CLEANERDS

while [[ $(../ocp4 -n default get daemonset/ceph-cleaner -ojsonpath='{.status.numberReady}') != $(../ocp4 -n default get daemonset/ceph-cleaner -ojsonpath='{.status.desiredNumberScheduled}') ]]; do
        echo Waiting for hosts to be cleaned...
        sleep 5
done

../ocp4 -n default delete daemonset/ceph-cleaner
