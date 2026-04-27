# hive-env.sh — sourced by hiveserver2/beeline/metastore at startup
# Add Tez jars (top-level AND lib/) to HADOOP_CLASSPATH so HiveServer2
# can locate Tez classes and honour hive.execution.engine=tez.
# Without this, Hive silently falls back to MapReduce even when tez is configured.
export HADOOP_CLASSPATH=${HADOOP_CLASSPATH}:${TEZ_HOME}/*:${TEZ_HOME}/lib/*
