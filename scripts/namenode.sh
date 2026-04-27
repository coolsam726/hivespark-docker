#!/bin/bash
# namenode.sh — Format (once) and start the HDFS NameNode
set -e

FORMAT_MARKER="${HADOOP_HOME}/data/nameNode/formatted"

if [ ! -f "${FORMAT_MARKER}" ]; then
    echo ">>> First run: formatting HDFS NameNode ..."
    ${HADOOP_HOME}/bin/hdfs namenode -format -force -nonInteractive
    touch "${FORMAT_MARKER}"
    echo ">>> Format complete."
else
    echo ">>> NameNode already formatted; skipping."
fi

# Create expected HDFS directories after the NameNode is up
(
    sleep 20
    echo ">>> Creating HDFS base directories ..."
    hdfs dfs -mkdir -p /user/hive/warehouse
    hdfs dfs -mkdir -p /user/root
    hdfs dfs -mkdir -p /spark-logs
    hdfs dfs -mkdir -p /tmp
    hdfs dfs -mkdir -p /tmp/hadoop-yarn/staging
    hdfs dfs -chmod 1777  /tmp
    hdfs dfs -chmod 1777  /tmp/hadoop-yarn
    hdfs dfs -chmod 1777  /tmp/hadoop-yarn/staging
    hdfs dfs -chmod 777   /user/hive/warehouse
    hdfs dfs -mkdir -p /apps/tez
    hdfs dfs -chmod 755   /apps/tez
    hdfs dfs -mkdir -p /tmp/tez/staging
    hdfs dfs -chmod 1777  /tmp/tez/staging
    echo ">>> HDFS directories ready."
) &

exec ${HADOOP_HOME}/bin/hdfs namenode
