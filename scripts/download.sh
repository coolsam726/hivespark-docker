#!/bin/bash
# download.sh — Pre-download all large archives for offline/cached Docker builds.
# Run this once before `make build`. Files are saved to downloads/ at the repo root.
set -e

HADOOP_VERSION="${HADOOP_VERSION:-3.3.6}"
HIVE_VERSION="${HIVE_VERSION:-4.0.0}"
SPARK_VERSION="${SPARK_VERSION:-3.5.1}"
POSTGRES_JDBC_VERSION="${POSTGRES_JDBC_VERSION:-42.7.3}"

DOWNLOADS_DIR="$(cd "$(dirname "$0")/.." && pwd)/downloads"
mkdir -p "${DOWNLOADS_DIR}"

download_if_missing() {
    local url="$1"
    local dest="$2"
    if [ -f "${dest}" ]; then
        echo "  [skip] $(basename "${dest}") already exists."
    else
        echo "  [download] $(basename "${dest}")"
        wget --progress=dot:giga "${url}" -O "${dest}.tmp" && mv "${dest}.tmp" "${dest}"
    fi
}

echo "==> Downloading Hadoop ${HADOOP_VERSION} ..."
download_if_missing \
    "https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz" \
    "${DOWNLOADS_DIR}/hadoop-${HADOOP_VERSION}.tar.gz"

echo "==> Downloading Hive ${HIVE_VERSION} ..."
download_if_missing \
    "https://archive.apache.org/dist/hive/hive-${HIVE_VERSION}/apache-hive-${HIVE_VERSION}-bin.tar.gz" \
    "${DOWNLOADS_DIR}/apache-hive-${HIVE_VERSION}-bin.tar.gz"

echo "==> Downloading Spark ${SPARK_VERSION} ..."
download_if_missing \
    "https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop3.tgz" \
    "${DOWNLOADS_DIR}/spark-${SPARK_VERSION}-bin-hadoop3.tgz"

echo "==> Downloading PostgreSQL JDBC ${POSTGRES_JDBC_VERSION} ..."
download_if_missing \
    "https://jdbc.postgresql.org/download/postgresql-${POSTGRES_JDBC_VERSION}.jar" \
    "${DOWNLOADS_DIR}/postgresql-${POSTGRES_JDBC_VERSION}.jar"

echo ""
echo "==> All files ready in ${DOWNLOADS_DIR}/"
ls -lh "${DOWNLOADS_DIR}/"
