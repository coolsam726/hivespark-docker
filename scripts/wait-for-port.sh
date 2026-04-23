#!/bin/bash
# wait-for-port.sh <host> <port> [timeout_seconds]
# Blocks until TCP port is open or timeout is reached.
set -e
HOST="$1"
PORT="$2"
TIMEOUT="${3:-120}"
ELAPSED=0

echo "Waiting for ${HOST}:${PORT} ..."
until nc -z "${HOST}" "${PORT}" 2>/dev/null; do
    if [ "${ELAPSED}" -ge "${TIMEOUT}" ]; then
        echo "ERROR: ${HOST}:${PORT} did not become available within ${TIMEOUT}s"
        exit 1
    fi
    sleep 2
    ELAPSED=$((ELAPSED + 2))
done
echo "${HOST}:${PORT} is available (${ELAPSED}s)"
