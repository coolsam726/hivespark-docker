# Hadoop + Hive + Spark (PySpark) + PostgreSQL — Docker Bundle

## Version Matrix

| Component       | Version  | Java Requirement |
|-----------------|----------|-----------------|
| **Java**        | 11 (LTS) | —               |
| **Hadoop**      | 3.3.6    | 8 or 11         |
| **Hive**        | 4.0.0    | 11+ (required)  |
| **Tez**         | 0.10.4   | 8 or 11          |
| **Spark**       | 3.5.1    | 8, 11, or 17     |
| **PostgreSQL**  | 15       | N/A              |
| **PySpark**     | 3.5.1    | (via Spark)      |
| **Hue**         | latest   | N/A              |
| **JupyterLab**  | spark-3.5.1 (pyspark-notebook) | N/A |

> **Why Java 11?** Hive 4.0.0 officially requires Java 11 as minimum. Hadoop 3.3.x and Spark 3.5.x both support Java 11 — making it the safe common baseline.

> **Hive execution engine:** Hive uses **Tez** as its query execution engine, running on YARN. This gives significantly better performance than MapReduce for SQL workloads. The standalone Spark cluster (`spark-master` / `spark-worker`) is a separate service used directly via `spark-submit`, PySpark, or JupyterLab — it is not related to Hive's execution engine.

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

### Data Visualisation (Matplotlib & Plotly)

Both `matplotlib` and `plotly` are installed automatically when JupyterLab starts (see `docker-compose.yml`). Open a notebook at http://localhost:8888 and use the patterns below.

#### Setup — SparkSession with Hive

```python
import os
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder \
    .appName("visualisation") \
    .master(os.environ["SPARK_MASTER"]) \
    .config("hive.metastore.uris", "thrift://hive-metastore:9083") \
    .config("spark.sql.warehouse.dir", "hdfs://namenode:9000/user/hive/warehouse") \
    .enableHiveSupport() \
    .getOrCreate()

# Load a Hive table as a Spark DataFrame (no SQL strings needed)
df = spark.table("my_database.my_table")
```

> Always reduce the data with aggregations or `.limit()` before calling `.toPandas()` — never collect a full large table.

---

#### Matplotlib

Good for static charts, publication-quality figures, and quick exploratory plots.

```python
import matplotlib.pyplot as plt

# --- Bar chart ---
pdf = df.groupBy("attack_cat") \
        .agg(F.count("*").alias("cnt")) \
        .orderBy(F.desc("cnt")) \
        .toPandas()

fig, ax = plt.subplots(figsize=(12, 5))
ax.bar(pdf["attack_cat"], pdf["cnt"], color="steelblue")
ax.set_xlabel("Attack Category")
ax.set_ylabel("Count")
ax.set_title("Attack Category Distribution")
plt.xticks(rotation=30, ha="right")
plt.tight_layout()
plt.show()
```

```python
# --- Pie chart ---
fig, ax = plt.subplots(figsize=(7, 7))
ax.pie(pdf["cnt"], labels=pdf["attack_cat"], autopct="%1.1f%%", startangle=140)
ax.set_title("Attack Category Share")
plt.show()
```

```python
# --- Horizontal bar (easier to read long labels) ---
pdf_sorted = pdf.sort_values("cnt")
fig, ax = plt.subplots(figsize=(10, 6))
ax.barh(pdf_sorted["attack_cat"], pdf_sorted["cnt"], color="coral")
ax.set_xlabel("Count")
ax.set_title("Attack Categories (horizontal)")
plt.tight_layout()
plt.show()
```

```python
# --- Box plot (distribution of a numeric column per group) ---
sample_pdf = df.filter((F.col("dur") > 0) & (F.col("dur") < 100)) \
               .select("attack_cat", "dur") \
               .sample(fraction=0.05) \
               .toPandas()

groups = [g["dur"].values for _, g in sample_pdf.groupby("attack_cat")]
labels = [name for name, _ in sample_pdf.groupby("attack_cat")]

fig, ax = plt.subplots(figsize=(12, 5))
ax.boxplot(groups, labels=labels, vert=True)
ax.set_xlabel("Attack Category")
ax.set_ylabel("Duration (s)")
ax.set_title("Connection Duration by Attack Category")
plt.xticks(rotation=30, ha="right")
plt.tight_layout()
plt.show()
```

---

#### Plotly

Good for interactive charts — hover tooltips, zoom, and pan work out of the box in JupyterLab.

```python
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots

pdf = df.groupBy("attack_cat") \
        .agg(F.count("*").alias("cnt")) \
        .orderBy(F.desc("cnt")) \
        .toPandas()
```

```python
# --- Interactive bar chart ---
fig = px.bar(pdf, x="attack_cat", y="cnt", color="attack_cat",
             title="Attack Category Distribution",
             labels={"cnt": "Count", "attack_cat": "Category"})
fig.show()
```

```python
# --- Pie / donut chart ---
fig = px.pie(pdf, values="cnt", names="attack_cat",
             title="Attack Category Share", hole=0.3)
fig.show()
```

```python
# --- Grouped bar: two metrics side by side ---
byte_pdf = df.groupBy("attack_cat") \
             .agg(F.avg("sbytes").alias("avg_src_bytes"),
                  F.avg("dbytes").alias("avg_dst_bytes")) \
             .toPandas()

fig = go.Figure()
fig.add_trace(go.Bar(name="Avg Src Bytes", x=byte_pdf["attack_cat"], y=byte_pdf["avg_src_bytes"]))
fig.add_trace(go.Bar(name="Avg Dst Bytes", x=byte_pdf["attack_cat"], y=byte_pdf["avg_dst_bytes"]))
fig.update_layout(barmode="group", title="Avg Source vs Destination Bytes by Category")
fig.show()
```

```python
# --- Box plot (interactive) ---
sample_pdf = df.filter((F.col("dur") > 0) & (F.col("dur") < 100)) \
               .select("attack_cat", "dur") \
               .sample(fraction=0.05) \
               .toPandas()

fig = px.box(sample_pdf, x="attack_cat", y="dur",
             title="Connection Duration by Attack Category",
             labels={"dur": "Duration (s)", "attack_cat": "Category"})
fig.update_layout(xaxis_tickangle=-30)
fig.show()
```

```python
# --- Heatmap: service vs attack category ---
heatmap_pdf = df.groupBy("service", "attack_cat") \
                .agg(F.count("*").alias("cnt")) \
                .filter(F.col("service") != "-") \
                .toPandas() \
                .pivot(index="service", columns="attack_cat", values="cnt") \
                .fillna(0)

fig = px.imshow(heatmap_pdf, aspect="auto",
                title="Heatmap: Service vs Attack Category",
                color_continuous_scale="Reds")
fig.show()
```

```python
# --- Subplots: combine multiple charts in one figure ---
fig = make_subplots(rows=1, cols=2,
                    subplot_titles=("Attack Distribution", "Avg Src Bytes"))

fig.add_trace(go.Bar(x=pdf["attack_cat"], y=pdf["cnt"], name="Count"), row=1, col=1)
fig.add_trace(go.Bar(x=byte_pdf["attack_cat"], y=byte_pdf["avg_src_bytes"],
                     name="Avg Src Bytes"), row=1, col=2)
fig.update_layout(title_text="UNSW-NB15 Overview", showlegend=False)
fig.show()
```

---

#### Quick Comparison

| Feature | Matplotlib | Plotly |
|---|---|---|
| Interactivity | Static | Hover, zoom, pan |
| Export | PNG / SVG / PDF | HTML / PNG / SVG |
| Subplots | `plt.subplots()` | `make_subplots()` |
| Best for | Reports, publications | Dashboards, exploration |

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
│   ├── Dockerfile              # FROM hadoop-base + Hive 4.0.0 + Tez 0.10.4
│   └── conf/
│       ├── hive-site.xml       # Metastore, HiveServer2, engine=tez
│       └── tez-site.xml        # Tez AM/task memory and YARN classpath settings
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

## Tuning

### Memory budget (16 GB machine default)

| Layer | Allocation | Config file |
|---|---|---|
| YARN NodeManager pool | 10 240 MB | `hadoop/conf/yarn-site.xml` |
| Tez AppMaster container | 4 096 MB | `hive/conf/tez-site.xml` |
| Tez task containers | 4 096 MB each | `hive/conf/tez-site.xml` |
| Spark driver | 2 g | `spark/conf/spark-defaults.conf` |
| Spark executor | 4 g | `spark/conf/spark-defaults.conf` |
| Infrastructure daemons | ~6 GB remainder | — |

To increase Tez task memory, raise `tez.task.resource.memory.mb` in `hive/conf/tez-site.xml` and update `-Xmx` in `tez.task.launch.cmd-opts` to ~80% of that value. Also raise `yarn.nodemanager.resource.memory-mb` and `yarn.scheduler.maximum-allocation-mb` in `hadoop/conf/yarn-site.xml` to match.

### For production

- Set `dfs.replication` to `3` in `hdfs-site.xml` and add more DataNode replicas
- Enable LDAP/Kerberos authentication in `hive-site.xml` and re-enable `hive.security.authorization.enabled`
- Pin Hue to a specific version tag in `docker-compose.yml`
- Move PostgreSQL metastore to an external managed database
