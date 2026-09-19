#!/usr/bin/env bash
# Publish an app repo's Grafana dashboards to the observability stack.
#
# Shared across every Komodo stack: this file lives in homelab-ci, which is
# cloned once onto the apps host as a Komodo Repo resource. Each stack calls it
# from its own repo root as a `post_deploy` hook, so SRC_DIR resolves against
# that stack's checkout.
#
#   path    = .
#   command = /etc/komodo/repos/homelab-ci/scripts/sync-grafana-dashboards.sh
#
# Destination is the observability stack checkout on CT 113 (Komodo-managed):
# Grafana bind-mounts that tree; file provider polls files/apps.
# Replaces the dashboard-sync half of the retired homelab-manager.
set -euo pipefail

SRC_DIR="${SRC_DIR:-grafana/dashboards}"
DEST_HOST="${DEST_HOST:-192.168.1.66}"
# Komodo repo clone on observability CT (not legacy /opt/homelab/observability).
DEST_DIR="${DEST_DIR:-/etc/komodo/repos/observability/grafana/provisioning/dashboards/files/apps}"

if [ ! -d "${SRC_DIR}" ]; then
  echo "No ${SRC_DIR} directory; nothing to publish."
  exit 0
fi

shopt -s nullglob
files=("${SRC_DIR}"/*.json)
if [ ${#files[@]} -eq 0 ]; then
  echo "No dashboards in ${SRC_DIR}; nothing to publish."
  exit 0
fi

echo "Publishing ${#files[@]} dashboard(s) from ${PWD}/${SRC_DIR} to ${DEST_HOST}:${DEST_DIR}"

for file in "${files[@]}"; do
  name="$(basename "${file}")"
  # Validate JSON before shipping; a malformed dashboard makes Grafana skip it.
  python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "${file}"
  scp -q -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
    "${file}" "root@${DEST_HOST}:${DEST_DIR}/${name}"
  echo "  -> ${name}"
done

echo "Published. Grafana picks these up on its next provisioning poll."
