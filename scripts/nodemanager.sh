#!/bin/bash
# nodemanager.sh — Wait for ResourceManager then start YARN NodeManager
set -e

/entrypoint/wait-for-port.sh resourcemanager 8032 120

exec ${HADOOP_HOME}/bin/yarn nodemanager
