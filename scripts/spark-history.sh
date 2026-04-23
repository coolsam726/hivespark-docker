#!/bin/bash
# spark-history.sh — Wait for HDFS then start Spark History Server
set -e

/entrypoint/wait-for-port.sh namenode 9000 120

# Ensure the event log directory exists in HDFS
hdfs dfs -mkdir -p /spark-logs 2>/dev/null || true

echo ">>> Starting Spark History Server on port 18080 ..."
exec ${SPARK_HOME}/bin/spark-class org.apache.spark.deploy.history.HistoryServer
