#!/bin/bash
# datanode.sh — Wait for NameNode then start a DataNode
set -e

/entrypoint/wait-for-port.sh namenode 9000 120

exec ${HADOOP_HOME}/bin/hdfs datanode
