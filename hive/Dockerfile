# =============================================================================
# Hive 4.0.0 — requires Java 11+ (official)
# Built on top of the shared hadoop-base image
# =============================================================================
FROM hivespark/hadoop-base:latest

ARG HIVE_VERSION=4.0.0
ARG POSTGRES_JDBC_VERSION=42.7.3
ARG TEZ_VERSION=0.10.4

ENV HIVE_VERSION=${HIVE_VERSION}
ENV HIVE_HOME=/opt/hive
ENV HIVE_CONF_DIR=${HIVE_HOME}/conf
ENV TEZ_HOME=/opt/tez
ENV TEZ_VERSION=${TEZ_VERSION}
ENV HIVE_AUX_JARS_PATH=${TEZ_HOME}
ENV PATH=${PATH}:${HIVE_HOME}/bin

# ─── Apache Hive ─────────────────────────────────────────────────────────────
COPY downloads/apache-hive-${HIVE_VERSION}-bin.tar.gz /tmp/hive.tar.gz
RUN tar -xzf /tmp/hive.tar.gz -C /opt && \
    mv /opt/apache-hive-${HIVE_VERSION}-bin ${HIVE_HOME} && \
    rm /tmp/hive.tar.gz

# ─── Apache Tez (execution engine for Hive queries on YARN) ──────────────────
COPY downloads/apache-tez-${TEZ_VERSION}-bin.tar.gz /tmp/tez.tar.gz
RUN tar -xzf /tmp/tez.tar.gz -C /opt && \
    mv /opt/apache-tez-${TEZ_VERSION}-bin ${TEZ_HOME} && \
    # Keep the tarball at a known path so hiveserver2.sh can upload it to HDFS
    cp /tmp/tez.tar.gz /opt/tez.tar.gz && \
    rm /tmp/tez.tar.gz && \
    # Remove Hive-bundled Tez jars to avoid version conflicts with our Tez install
    find ${HIVE_HOME}/lib -name "tez-*.jar" -delete 2>/dev/null || true

# ─── PostgreSQL JDBC driver (for Hive Metastore backend) ─────────────────────
COPY downloads/postgresql-${POSTGRES_JDBC_VERSION}.jar ${HIVE_HOME}/lib/postgresql-${POSTGRES_JDBC_VERSION}.jar

# ─── Fix guava version conflict (Hive ships older guava; use Hadoop's) ────────
# Hive 4.x bundles guava-22; Hadoop 3.3.x ships guava-27 — keep Hadoop's version
RUN GUAVA_JAR=$(ls ${HADOOP_HOME}/share/hadoop/common/lib/guava-*.jar | head -1) && \
    find ${HIVE_HOME}/lib -name "guava-*.jar" -delete && \
    cp "${GUAVA_JAR}" ${HIVE_HOME}/lib/

# ─── Remove conflicting log4j-slf4j binding if present ───────────────────────
RUN find ${HIVE_HOME}/lib -name "log4j-slf4j-impl-*.jar" -delete 2>/dev/null || true

# ─── Hive configuration ───────────────────────────────────────────────────────
COPY hive/conf/ ${HIVE_CONF_DIR}/

# Expose Metastore Thrift and HiveServer2 ports
EXPOSE 9083 10000 10002
