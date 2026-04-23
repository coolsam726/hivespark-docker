#!/bin/bash
# hiveserver2.sh — Wait for Metastore then start HiveServer2
set -e

/entrypoint/wait-for-port.sh hive-metastore 9083 180
/entrypoint/wait-for-port.sh namenode 9000 120

echo ">>> Starting HiveServer2 on port 10000 ..."
exec ${HIVE_HOME}/bin/hiveserver2
