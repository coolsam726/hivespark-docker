#!/bin/bash
# spark-master.sh — Start the Spark Standalone Master
set -e

echo ">>> Starting Spark Master ..."
exec ${SPARK_HOME}/bin/spark-class org.apache.spark.deploy.master.Master \
    --host spark-master \
    --port 7077 \
    --webui-port 8080
