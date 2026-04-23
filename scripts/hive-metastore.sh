#!/bin/bash
# hive-metastore.sh — Initialize schema (once) and start Hive Metastore
set -e

# 1. Wait for PostgreSQL
/entrypoint/wait-for-port.sh postgres 5432 120

# 2. Wait for HDFS NameNode
/entrypoint/wait-for-port.sh namenode 9000 120

# 3. Initialize schema if not already done
SCHEMA_FLAG="${HIVE_HOME}/.schema_initialized"
if [ ! -f "${SCHEMA_FLAG}" ]; then
    echo ">>> Initializing Hive Metastore schema in PostgreSQL ..."
    ${HIVE_HOME}/bin/schematool \
        -dbType postgres \
        -initSchema \
        --verbose && \
    touch "${SCHEMA_FLAG}"
    echo ">>> Schema initialization complete."
else
    echo ">>> Metastore schema already initialized; skipping."
fi

# 4. Start the Thrift Metastore service
echo ">>> Starting Hive Metastore on port 9083 ..."
exec ${HIVE_HOME}/bin/hive --service metastore
