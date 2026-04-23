# =============================================================================
# Spark 3.5.1 — supports Java 8, 11, 17  (using Java 11 here)
# Built on top of the shared hadoop-base image
# Includes PySpark + Hive metastore connectivity
# =============================================================================
FROM hivespark/hadoop-base:latest

ARG SPARK_VERSION=3.5.1

ENV SPARK_VERSION=${SPARK_VERSION}
ENV SPARK_HOME=/opt/spark
ENV SPARK_CONF_DIR=${SPARK_HOME}/conf
ENV PYSPARK_PYTHON=python3
ENV PATH=${PATH}:${SPARK_HOME}/bin:${SPARK_HOME}/sbin

# ─── Python 3 + PySpark runtime deps ─────────────────────────────────────────
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        python3 \
        python3-pip \
        python3-dev \
    && ln -sf /usr/bin/python3 /usr/bin/python \
    && rm -rf /var/lib/apt/lists/*

# ─── Apache Spark (pre-built with Hadoop 3 support) ──────────────────────────
COPY downloads/spark-${SPARK_VERSION}-bin-hadoop3.tgz /tmp/spark.tgz
RUN tar -xzf /tmp/spark.tgz -C /opt && \
    mv /opt/spark-${SPARK_VERSION}-bin-hadoop3 ${SPARK_HOME} && \
    rm /tmp/spark.tgz

# ─── Spark configuration ──────────────────────────────────────────────────────
COPY spark/conf/spark-defaults.conf ${SPARK_CONF_DIR}/spark-defaults.conf

# ─── Point Spark at the Hive metastore (copy hive-site.xml into Spark conf) ──
COPY hive/conf/hive-site.xml ${SPARK_CONF_DIR}/hive-site.xml

# Expose Spark Master UI, Worker UI, and History Server
EXPOSE 8080 8081 7077 18080
