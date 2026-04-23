# =============================================================================
# Base Image: Java 11 + Hadoop 3.3.6
# Compatible with: Hive 4.0.0, Spark 3.5.1
# =============================================================================
FROM eclipse-temurin:11-jdk-jammy

ARG HADOOP_VERSION=3.3.6

# System dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        ssh \
        rsync \
        netcat-openbsd \
        procps \
        net-tools \
        dnsutils \
    && rm -rf /var/lib/apt/lists/*

# ─── SSH setup (required for Hadoop cluster daemons) ────────────────────────
RUN ssh-keygen -t rsa -P '' -f /root/.ssh/id_rsa && \
    cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys && \
    chmod 0600 /root/.ssh/authorized_keys && \
    printf "Host *\n\tStrictHostKeyChecking no\n\tUserKnownHostsFile /dev/null\n" \
        > /root/.ssh/config

# ─── Hadoop ─────────────────────────────────────────────────────────────────
ENV HADOOP_VERSION=${HADOOP_VERSION}
ENV HADOOP_HOME=/opt/hadoop
ENV HADOOP_CONF_DIR=${HADOOP_HOME}/etc/hadoop
ENV HADOOP_LOG_DIR=/var/log/hadoop
ENV PATH=${PATH}:${HADOOP_HOME}/bin:${HADOOP_HOME}/sbin

# Run Hadoop daemons as root (simplifies single-node dev setup)
ENV HDFS_NAMENODE_USER=root
ENV HDFS_DATANODE_USER=root
ENV HDFS_SECONDARYNAMENODE_USER=root
ENV YARN_RESOURCEMANAGER_USER=root
ENV YARN_NODEMANAGER_USER=root

COPY downloads/hadoop-${HADOOP_VERSION}.tar.gz /tmp/hadoop.tar.gz
RUN tar -xzf /tmp/hadoop.tar.gz -C /opt && \
    mv /opt/hadoop-${HADOOP_VERSION} ${HADOOP_HOME} && \
    rm /tmp/hadoop.tar.gz && \
    mkdir -p ${HADOOP_LOG_DIR} \
             ${HADOOP_HOME}/data/nameNode \
             ${HADOOP_HOME}/data/dataNode

# Wire Hadoop to the JDK already in PATH
RUN echo "export JAVA_HOME=${JAVA_HOME}" >> ${HADOOP_CONF_DIR}/hadoop-env.sh && \
    echo "export HADOOP_LOG_DIR=${HADOOP_LOG_DIR}" >> ${HADOOP_CONF_DIR}/hadoop-env.sh

# Copy cluster configuration (core-site, hdfs-site, yarn-site, mapred-site)
COPY hadoop/conf/ ${HADOOP_CONF_DIR}/

# Copy shared entrypoint helpers
COPY scripts/ /entrypoint/
RUN chmod +x /entrypoint/*.sh
