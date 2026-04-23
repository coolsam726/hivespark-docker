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
    hdfs dfs -chmod g+w   /tmp
    hdfs dfs -chmod 777   /user/hive/warehouse
    echo ">>> HDFS directories ready."
) &

exec ${HADOOP_HOME}/bin/hdfs namenode
