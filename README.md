# Hadoop + Hive + Spark (PySpark) + PostgreSQL — Docker Bundle

## Version Matrix

| Component       | Version  | Java Requirement |
|-----------------|----------|-----------------|
| **Java**        | 11 (LTS) | —               |
| **Hadoop**      | 3.3.6    | 8 or 11         |
| **Hive**        | 4.0.0    | 11+ (required)  |
| **Spark**       | 3.5.1    | 8, 11, or 17    |
| **PostgreSQL**  | 15       | N/A             |
| **PySpark**     | 3.5.1    | (via Spark)     |

> **Why Java 11?** Hive 4.0.0 officially requires Java 11 as minimum. Hadoop 3.3.x and Spark 3.5.x both support Java 11 — making it the safe common baseline.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  Docker Network: hadoop-net                                     │
│                                                                 │
│  ┌──────────┐    ┌──────────┐    ┌───────────────────────┐     │
│  │ namenode │    │ datanode │    │  resourcemanager      │     │
│  │  :9870   │    │  :9864   │    │  :8088                │     │
│  └──────────┘    └──────────┘    └───────────────────────┘     │
│       ▲               ▲                    ▲                    │
│       └───────────────┴────────────────────┘                   │
│                   HDFS / YARN                                   │
│                                                                 │
│  ┌────────────────┐    ┌─────────────┐    ┌───────────────┐    │
│  │ hive-metastore │    │ hiveserver2 │    │   postgres    │    │
│  │  :9083         │◄───│  :10000     │    │   :5432       │    │
│  └───────┬────────┘    └─────────────┘    └───────┬───────┘    │
│          └──────────────────────────────────────►─┘            │
│                      Metastore DB                               │
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌───────────────┐    │
│  │ spark-master │    │ spark-worker │    │ spark-history │    │
│  │  :8080/:7077 │◄───│  :8081       │    │  :18080       │    │
│  └──────────────┘    └──────────────┘    └───────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

---

## Quick Start

```bash
# 1. Build all images (downloads ~1.5 GB of tarballs on first run)
make build

# 2. Start all services
make up

# 3. Watch logs
make logs
```

Full startup takes **~2 minutes**. Services start in this order:
`postgres` → `namenode` → `datanode` + `resourcemanager` → `nodemanager` + `hive-metastore` → `hiveserver2` + `spark-master` → `spark-worker`

---

## Web UIs

| Service             | URL                        |
|---------------------|---------------------------|
| HDFS NameNode       | http://localhost:9870      |
| YARN ResourceManager| http://localhost:8088      |
| HiveServer2         | http://localhost:10002     |
| Spark Master        | http://localhost:8080      |
| Spark History Server| http://localhost:18080     |
| MR History Server   | http://localhost:19888     |

---

## Connecting

### Beeline (HiveServer2)
```bash
make beeline
# or
docker exec -it hiveserver2 /opt/hive/bin/beeline -u "jdbc:hive2://hiveserver2:10000"
```

### PySpark shell
```bash
make pyspark
# Inside the shell:
# spark.sql("SHOW DATABASES").show()
```

### PySpark with Hive metastore (Python snippet)
```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("example") \
    .master("spark://spark-master:7077") \
    .config("spark.hadoop.fs.defaultFS", "hdfs://namenode:9000") \
    .config("spark.sql.catalogImplementation", "hive") \
    .enableHiveSupport() \
    .getOrCreate()

spark.sql("CREATE DATABASE IF NOT EXISTS test")
spark.sql("USE test")
spark.sql("CREATE TABLE IF NOT EXISTS nums (n INT)")
spark.sql("INSERT INTO nums VALUES (1),(2),(3)")
spark.sql("SELECT * FROM nums").show()
```

### JDBC (from host machine)
```
JDBC URL : jdbc:hive2://localhost:10000
Driver   : org.apache.hive.jdbc.HiveDriver (Hive JDBC jar)
User     : (any)
Password : (leave blank)
```

---

## Directory Structure

```
hivespark/
├── Makefile
├── docker-compose.yml
├── README.md
├── base/
│   └── Dockerfile              # Java 11 + Hadoop 3.3.6 base image
├── hadoop/
│   └── conf/
│       ├── core-site.xml
│       ├── hdfs-site.xml
│       ├── mapred-site.xml
│       ├── yarn-site.xml
│       └── workers
├── hive/
│   ├── Dockerfile              # FROM hadoop-base + Hive 4.0.0
│   └── conf/
│       └── hive-site.xml
├── spark/
│   ├── Dockerfile              # FROM hadoop-base + Spark 3.5.1 (PySpark)
│   └── conf/
│       └── spark-defaults.conf
└── scripts/
    ├── wait-for-port.sh
    ├── namenode.sh
    ├── datanode.sh
    ├── resourcemanager.sh
    ├── nodemanager.sh
    ├── historyserver.sh
    ├── hive-metastore.sh
    ├── hiveserver2.sh
    ├── spark-master.sh
    ├── spark-worker.sh
    └── spark-history.sh
```

---

## Teardown

```bash
# Stop services (data preserved in volumes)
make down

# Full reset — removes all containers AND volumes
make clean
```

---

## Tuning for Production

- Raise `yarn.nodemanager.resource.memory-mb` in `hadoop/conf/yarn-site.xml`
- Set `dfs.replication` to `3` in `hdfs-site.xml` and add more DataNode replicas
- Set `spark.executor.memory` / `spark.driver.memory` in `spark/conf/spark-defaults.conf`
- Enable LDAP/Kerberos authentication in `hive-site.xml`
- Use `hive.execution.engine=tez` or `spark` for faster Hive queries
