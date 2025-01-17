#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_NAME=$(basename "$0")

NAMESPACE=$(kubectl config view --minify --output 'jsonpath={..namespace}')
OBJECTS=""
BACKUP_PATH=""

usage() {
  cat <<EOF
Usage: ${SCRIPT_NAME} --objects=<object-type,object-type,...> [--namespace=<namespace>] [--path=<backup-directory>]
Example: ${SCRIPT_NAME} --objects=deployments,statefulsets --namespace=sentry --path=/backups

Options:
    --objects    Types of Kubernetes objects to backup (required)
    --namespace  Kubernetes namespace (default: current namespace)
    --path       Backup directory (default: kubernetes-backup-TIMESTAMP)
EOF
  exit 1
}

for ARG in "$@"; do
  case $ARG in
  --namespace=*)
    NAMESPACE="${ARG#*=}"
    ;;
  --objects=*)
    OBJECTS="${ARG#*=}"
    ;;
  --path=*)
    BACKUP_PATH="${ARG#*=}"
    ;;
  --help)
    usage
    ;;
  *)
    usage
    ;;
  esac
done

if [ -z "$OBJECTS" ]; then
  echo "No object type specified. Use --objects to specify object types."
  exit 1
fi

if [ -z "$BACKUP_PATH" ]; then
  BACKUP_DIR="kubernetes-backup-$(date +%Y%m%d%H%M%S)"
else
  BACKUP_DIR="$BACKUP_PATH"
fi

mkdir -p "$BACKUP_DIR"

IFS=',' read -r -a OBJECT_TYPES <<<"$OBJECTS"

for OBJECT_TYPE in "${OBJECT_TYPES[@]}"; do
  echo -e "\n Backing up objects of type: $OBJECT_TYPE in namespace: $NAMESPACE"

  for OBJECT_NAME in $(kubectl get "$OBJECT_TYPE" -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name} {end}'); do
    NAMESPACE_DIR="$BACKUP_DIR/$NAMESPACE"
    mkdir -p "$NAMESPACE_DIR"

    OUTPUT_FILE="$NAMESPACE_DIR/$OBJECT_NAME.$OBJECT_TYPE.yaml"
    echo -e "  ➡️  Backing up $OBJECT_NAME ($OBJECT_TYPE) to $OUTPUT_FILE"
    kubectl get "$OBJECT_TYPE" "$OBJECT_NAME" -n "$NAMESPACE" -o yaml >"$OUTPUT_FILE"
  done
done

echo -e "\n✅ Backup completed in directory: $BACKUP_DIR"
