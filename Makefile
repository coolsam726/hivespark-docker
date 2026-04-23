.PHONY: build download up down restart logs clean ps

# Pre-download all large archives (run once; skips files that already exist)
download:
	@bash scripts/download.sh

# Build order matters: base → hive, spark (both FROM hadoop-base)
build: download
	@echo "==> Building hadoop-base image ..."
	docker build -t hivespark/hadoop-base:latest \
	    --build-arg HADOOP_VERSION=3.3.6 \
	    -f base/Dockerfile .
	@echo "==> Building hive image ..."
	docker build -t hivespark/hive:latest \
	    --build-arg HIVE_VERSION=4.0.0 \
	    --build-arg POSTGRES_JDBC_VERSION=42.7.3 \
	    -f hive/Dockerfile .
	@echo "==> Building spark image ..."
	docker build -t hivespark/spark:latest \
	    --build-arg SPARK_VERSION=3.5.1 \
	    -f spark/Dockerfile .
	@echo "==> All images built."

up: build
	docker compose up -d
	@echo ""
	@echo "Services starting — wait ~2 min for full initialization."
	@echo "  HDFS NameNode UI  : http://localhost:9870"
	@echo "  YARN RM UI        : http://localhost:8088"
	@echo "  HiveServer2 UI    : http://localhost:10002"
	@echo "  Spark Master UI   : http://localhost:8080"
	@echo "  Spark History UI  : http://localhost:18080"
	@echo "  MR History UI     : http://localhost:19888"
	@echo "  PostgreSQL        : localhost:5432  (user=hive, pass=hive, db=metastore)"

down:
	docker compose down

restart:
	docker compose restart

logs:
	docker compose logs -f

ps:
	docker compose ps

# Remove containers AND volumes (full reset — destructive!)
clean:
	@read -p "This will delete all data volumes. Are you sure? [y/N] " ans; \
	if [ "$$ans" = "y" ] || [ "$$ans" = "Y" ]; then \
	    docker compose down -v --remove-orphans; \
	    echo "Cleaned."; \
	else \
	    echo "Aborted."; \
	fi

# Open a beeline session to HiveServer2
beeline:
	docker exec -it hiveserver2 \
	    ${HIVE_HOME:-/opt/hive}/bin/beeline -u "jdbc:hive2://hiveserver2:10000"

# Open a PySpark shell connected to the Spark standalone cluster
pyspark:
	docker exec -it spark-master \
	    ${SPARK_HOME:-/opt/spark}/bin/pyspark \
	    --master spark://spark-master:7077

# Open a Spark shell (Scala)
spark-shell:
	docker exec -it spark-master \
	    ${SPARK_HOME:-/opt/spark}/bin/spark-shell \
	    --master spark://spark-master:7077
