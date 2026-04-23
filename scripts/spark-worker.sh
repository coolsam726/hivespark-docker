#!/bin/bash
# spark-worker.sh — Wait for Spark Master then start a Spark Worker
set -e

/entrypoint/wait-for-port.sh spark-master 7077 120

echo ">>> Starting Spark Worker ..."
exec ${SPARK_HOME}/bin/spark-class org.apache.spark.deploy.worker.Worker \
    spark://spark-master:7077 \
    --webui-port 8081
