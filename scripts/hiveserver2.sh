#!/bin/bash
# hiveserver2.sh — Wait for Metastore then start HiveServer2
set -e

/entrypoint/wait-for-port.sh hive-metastore 9083 180
/entrypoint/wait-for-port.sh namenode 9000 120

echo ">>> Waiting for HDFS to leave safe mode ..."
for attempt in $(seq 1 60); do
    if hdfs dfsadmin -safemode get 2>/dev/null | grep -q "OFF"; then
        echo ">>> HDFS safe mode is OFF."
        break
    fi
    if [ "$attempt" -eq 60 ]; then
        echo ">>> Timed out waiting for HDFS safe mode to turn OFF."
        exit 1
    fi
    sleep 5
done

# Ensure Tez HDFS directories exist even on already-initialized clusters.
hdfs dfs -mkdir -p /apps/tez
hdfs dfs -mkdir -p /tmp/tez/staging
hdfs dfs -chmod 755 /apps/tez
hdfs dfs -chmod 1777 /tmp/tez/staging

# Repack and upload Tez tarball to HDFS on every start.
# The original apache-tez-*-bin.tar.gz has a top-level subdir; we strip it so
# YARN containers can resolve jars as ./tez.tar.gz/* and ./tez.tar.gz/lib/*.
echo ">>> Repacking Tez tarball (stripping top-level directory) ..."
mkdir -p /tmp/tez-repack
tar -xzf /opt/tez.tar.gz -C /tmp/tez-repack --strip-components=1
tar -czf /tmp/tez-flat.tar.gz -C /tmp/tez-repack .
rm -rf /tmp/tez-repack
echo ">>> Uploading repacked Tez tarball to HDFS /apps/tez/ ..."
hdfs dfs -rm -f /apps/tez/tez.tar.gz
hdfs dfs -put /tmp/tez-flat.tar.gz /apps/tez/tez.tar.gz
rm -f /tmp/tez-flat.tar.gz
echo ">>> Tez tarball uploaded."

echo ">>> Starting HiveServer2 on port 10000 ..."

# Remove any stale PID file left from a previous container run.
# Hive's wrapper script writes ${HIVE_PID_DIR:-/tmp}/hive-<user>-HiveServer2.pid
# and refuses to start if it already exists, even after a container restart.
rm -f "${HIVE_PID_DIR:-/tmp}"/hive-*-HiveServer2.pid

exec ${HIVE_HOME}/bin/hiveserver2
