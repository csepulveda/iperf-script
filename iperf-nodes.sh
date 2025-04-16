#!/bin/bash

set -euo pipefail

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  echo "Usage: $0 <server-node-name> <client-node-name> [--use-service=ClusterIP|NodePort]"
  exit 1
fi

SERVER_NODE="$1"
CLIENT_NODE="$2"
USE_SERVICE="${3:-}"
SERVICE_ENABLED=false
SERVICE_TYPE="ClusterIP"

if [[ "$USE_SERVICE" == --use-service=* ]]; then
  SERVICE_ENABLED=true
  SERVICE_TYPE="${USE_SERVICE#*=}"
  if [[ "$SERVICE_TYPE" != "ClusterIP" && "$SERVICE_TYPE" != "NodePort" ]]; then
    echo "Invalid service type: $SERVICE_TYPE. Defaulting to ClusterIP."
    SERVICE_TYPE="ClusterIP"
  fi
fi

NAMESPACE="iperf-test"
SERVER_DEPLOYMENT="iperf3-server"
CLIENT_JOB="iperf3-client"
SERVER_SERVICE="iperf3-service"

cleanup() {
  echo "Cleaning up resources..."
  kubectl delete job "$CLIENT_JOB" -n "$NAMESPACE" --ignore-not-found
  kubectl delete deployment "$SERVER_DEPLOYMENT" -n "$NAMESPACE" --ignore-not-found
  if [ "$SERVICE_ENABLED" = true ]; then
    kubectl delete service "$SERVER_SERVICE" -n "$NAMESPACE" --ignore-not-found
  fi
}
trap cleanup EXIT

echo "Creating namespace '$NAMESPACE' (if not exists)..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo "Deploying iperf3 server on node $SERVER_NODE..."
cat <<EOF | kubectl apply -n "$NAMESPACE" -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $SERVER_DEPLOYMENT
spec:
  replicas: 1
  selector:
    matchLabels:
      app: iperf3-server
  template:
    metadata:
      labels:
        app: iperf3-server
    spec:
      nodeSelector:
        kubernetes.io/hostname: "$SERVER_NODE"
      containers:
      - name: iperf3
        image: networkstatic/iperf3
        command: ["iperf3", "-s"]
        ports:
        - containerPort: 5201
EOF

if [ "$SERVICE_ENABLED" = true ]; then
  echo "Creating $SERVICE_TYPE service to expose iperf3 server..."
  cat <<EOF | kubectl apply -n "$NAMESPACE" -f -
apiVersion: v1
kind: Service
metadata:
  name: $SERVER_SERVICE
spec:
  type: $SERVICE_TYPE
  selector:
    app: iperf3-server
  ports:
    - protocol: TCP
      port: 5201
      targetPort: 5201
EOF
fi

echo "Waiting for iperf3 server pod to be ready..."
kubectl wait --namespace "$NAMESPACE" --for=condition=Ready pod -l app=iperf3-server --timeout=90s

if [ "$SERVICE_ENABLED" = true ]; then
  TARGET="$SERVER_SERVICE.$NAMESPACE.svc.cluster.local"
  echo "Using service address: $TARGET"
else
  SERVER_IP=$(kubectl get pod -n "$NAMESPACE" -l app=iperf3-server -o jsonpath="{.items[0].status.podIP}")
  TARGET="$SERVER_IP"
  echo "Using pod IP address: $TARGET"
fi

echo "Launching iperf3 client job from node $CLIENT_NODE..."
cat <<EOF | kubectl apply -n "$NAMESPACE" -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: $CLIENT_JOB
spec:
  template:
    spec:
      nodeSelector:
        kubernetes.io/hostname: "$CLIENT_NODE"
      restartPolicy: Never
      containers:
      - name: iperf3
        image: networkstatic/iperf3
        command: ["iperf3", "-c", "$TARGET"]
EOF

echo "Waiting for client job to complete..."
kubectl wait --for=condition=complete job/$CLIENT_JOB -n "$NAMESPACE" --timeout=90s

echo "Client job completed. Fetching logs:"
kubectl logs job/$CLIENT_JOB -n "$NAMESPACE"