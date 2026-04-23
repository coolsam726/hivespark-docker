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
| **Hue**         | latest   | N/A             |
| **JupyterLab**  | spark-3.5.3 (pyspark-notebook) | N/A |

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
│                                                                 │
│  ┌───────────────────┐    ┌──────────────────────────────┐    │
│  │ hue               │    │ jupyterlab                   │    │
│  │  :8889 (→8888)    │    │  :8888                       │    │
│  └───────────────────┘    └──────────────────────────────┘    │
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
| Hue (SQL editor)    | http://localhost:8889      |
| JupyterLab          | http://localhost:8888      |

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

### Hue (SQL / HQL editor)

Hue provides a browser-based SQL editor wired to HiveServer2.

```
URL  : http://localhost:8889
User : admin   (set on first login — Hue will prompt you to create an account)
```

1. Open http://localhost:8889
2. On first launch Hue asks you to create an admin account — fill in any username/password.
3. Go to **Editor → Hive** to run HQL queries against HiveServer2.

> HDFS file browser and YARN job browser are also available via the left-hand sidebar.

---

### JupyterLab (PySpark notebooks)

JupyterLab runs a pre-built `pyspark-notebook` image with Spark 3.5 already installed.

```
URL   : http://localhost:8888/lab?token=hivespark
Token : hivespark
```

Create a new notebook and connect to the Spark standalone cluster:

```python
import os
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("notebook") \
    .master(os.environ["SPARK_MASTER"]) \
    .config("spark.hadoop.fs.defaultFS", "hdfs://namenode:9000") \
    .getOrCreate()

spark.range(5).show()
```

The `SPARK_MASTER` environment variable is pre-set to `spark://spark-master:7077` by docker-compose, so no hard-coding is needed.

To access the Hive metastore from a notebook:

```python
spark = SparkSession.builder \
    .appName("notebook-hive") \
    .master(os.environ["SPARK_MASTER"]) \
    .config("spark.hadoop.fs.defaultFS", "hdfs://namenode:9000") \
    .config("spark.sql.catalogImplementation", "hive") \
    .config("hive.metastore.uris", "thrift://hive-metastore:9083") \
    .enableHiveSupport() \
    .getOrCreate()

spark.sql("SHOW DATABASES").show()
```

Notebooks saved to `/home/jovyan/work` inside the container are persisted in the `jupyter-work` Docker volume.

---

### PyCharm Database Tool

PyCharm's built-in Database tool connects to HiveServer2 via the Apache Hive JDBC driver.

**Step 1 — Open the data source wizard**
- Go to **View → Tool Windows → Database**
- Click **+** → **Data Source → Apache Hive**

**Step 2 — Configure the connection**

| Field       | Value                          |
|-------------|-------------------------------|
| Host        | `localhost`                   |
| Port        | `10000`                       |
| Database    | *(leave blank for default)*   |
| User        | *(any value, e.g. `hive`)*    |
| Password    | *(leave blank)*               |

The resulting JDBC URL will be:
```
jdbc:hive2://localhost:10000
```

**Step 3 — Download the driver**
- PyCharm will show a **"Driver files are not configured"** warning at the bottom of the dialog.
- Click **Download** — PyCharm will automatically fetch the Hive JDBC driver from Maven.

**Step 4 — Test & Connect**
- Click **Test Connection** — you should see `Successful`.
- Click **OK**. The Hive catalog will appear in the Database panel.

> **Tip:** If the test fails, make sure HiveServer2 is fully started first:
> ```bash
> docker exec hiveserver2 ss -tlnp | grep 10000
> ```
> The port must be listed before connections are accepted.

---

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
├── hue/
│   └── hue.ini                 # Hue config (HiveServer2, HDFS, YARN endpoints)
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
