#!/bin/bash
# hiveserver2.sh — Wait for Metastore then start HiveServer2
set -e

/entrypoint/wait-for-port.sh hive-metastore 9083 180
/entrypoint/wait-for-port.sh namenode 9000 120

echo ">>> Starting HiveServer2 on port 10000 ..."

# Remove any stale PID file left from a previous container run.
# Hive's wrapper script writes ${HIVE_PID_DIR:-/tmp}/hive-<user>-HiveServer2.pid
# and refuses to start if it already exists, even after a container restart.
rm -f "${HIVE_PID_DIR:-/tmp}"/hive-*-HiveServer2.pid

exec ${HIVE_HOME}/bin/hiveserver2
