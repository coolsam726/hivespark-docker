#!/bin/bash
# resourcemanager.sh — Start the YARN ResourceManager
set -e

/entrypoint/wait-for-port.sh namenode 9000 120

exec ${HADOOP_HOME}/bin/yarn resourcemanager
