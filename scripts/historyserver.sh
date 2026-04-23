#!/bin/bash
# historyserver.sh — Wait for HDFS then start MR History Server
set -e

/entrypoint/wait-for-port.sh namenode 9000 120

exec ${HADOOP_HOME}/bin/mapred historyserver
