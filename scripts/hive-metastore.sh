#!/bin/bash
# hive-metastore.sh — Initialize schema (once) and start Hive Metastore
set -e

# 1. Wait for PostgreSQL
/entrypoint/wait-for-port.sh postgres 5432 120

# 2. Wait for HDFS NameNode
/entrypoint/wait-for-port.sh namenode 9000 120

# 3. Initialize schema if not already done
# SCHEMA_FLAG is a file inside the persistent volume directory
SCHEMA_FLAG="${HIVE_HOME}/.schema_data/initialized"
mkdir -p "${HIVE_HOME}/.schema_data"

if [ ! -f "${SCHEMA_FLAG}" ]; then
    echo ">>> Checking Hive Metastore schema in PostgreSQL ..."
    # Check by inspecting schematool -info output text, not just exit code
    # (exit code is unreliable when schema version != Hive version)
    SCHEMA_INFO=$(${HIVE_HOME}/bin/schematool -dbType postgres -info 2>&1 || true)
    if echo "${SCHEMA_INFO}" | grep -qE "Metastore schema version|Hive distribution version"; then
        echo ">>> Schema already exists; skipping initialization."
    else
        echo ">>> Initializing Hive Metastore schema ..."
        ${HIVE_HOME}/bin/schematool \
            -dbType postgres \
            -initSchema \
            --verbose
    fi
    touch "${SCHEMA_FLAG}"
    echo ">>> Schema initialization complete."
else
    echo ">>> Metastore schema already initialized; skipping."
fi

# 4. Start the Thrift Metastore service
echo ">>> Starting Hive Metastore on port 9083 ..."
exec ${HIVE_HOME}/bin/hive --service metastore
