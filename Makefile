# Makefile for managing the Hadoop Docker Compose setup

# Variables
COMPOSE_CMD = docker compose
COMPOSE_FILE = docker-compose.yml
MASTER_CONTAINER = hadoop-master
SLAVE_1 = hadoop-slave1
SLAVE_2 = hadoop-slave2
HADOOP_VERSION ?= 3.3.6# Default Hadoop version, can be overridden e.g., make HADOOP_VERSION=3.3.5 test
HADOOP_EXAMPLES_JAR = $$HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-$(HADOOP_VERSION).jar
HDFS_WC_INPUT_DIR = /user/root/input/wc_example # Input dir on HDFS
HDFS_WC_OUTPUT_DIR = /user/root/output/wc_example # Output dir on HDFS
LOCAL_SAMPLE_FILE = sample-wordcount-input.txt # Temp local file name

# --- Targets ---

# Default target: Executed when running 'make' without arguments.
# Builds (if needed), starts the cluster, waits briefly, then shows status reports.
.PHONY: all
all: start status hdfs-report yarn-nodes
	@echo "-----------------------------------------------------"
	@echo "Default 'make' sequence finished. Cluster started."
	@echo "Review status reports above. Use 'make logs', 'make shell', 'make test', 'make down', etc. for other actions."
	@echo "-----------------------------------------------------"

.PHONY: help
help: ## Display this help message
	@echo "Usage: make [target]"
	@echo ""
	@echo "Default Target (just 'make'): Builds (if needed), starts cluster, shows status reports."
	@echo ""
	@echo "Other Targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST) | sort

.PHONY: build
build: ## Build or rebuild the Docker images without starting
	@echo "Building Hadoop Docker images..."
	docker-compose -f $(COMPOSE_FILE) build

.PHONY: start
start: ## Build (if needed) and start all Hadoop services in detached mode
	@echo "Starting Hadoop cluster (builds image if necessary)..."
	docker-compose -f $(COMPOSE_FILE) up --build -d
	@echo "Cluster starting... Use 'make logs' or check UIs (allow ~30-60s for full startup):"
	@echo "  Namenode:    http://localhost:9870"
	@echo "  YARN RM:     http://localhost:8088"
	@echo "  MR History:  http://localhost:19888"
	@echo "Waiting briefly for services to initialize before running status checks..."
	@sleep 20 # Add a delay to allow services time to come online before dependent targets run

.PHONY: stop
stop: ## Stop running Hadoop services (containers remain)
	@echo "Stopping Hadoop cluster services..."
	docker-compose -f $(COMPOSE_FILE) stop

.PHONY: down
down: ## Stop and remove Hadoop containers and networks (volumes persist)
	@echo "Stopping and removing Hadoop containers..."
	docker-compose -f $(COMPOSE_FILE) down

.PHONY: clean
clean: ## Stop, remove containers, networks, AND associated volumes (WARNING: Deletes HDFS data)
	@echo "WARNING: This will delete all persisted HDFS/YARN data!"
	@read -p "Are you sure? (y/N) " confirm && [[ $$confirm == [yY] ]] || exit 1
	@echo "Stopping containers and removing volumes..."
	docker-compose -f $(COMPOSE_FILE) down -v

.PHONY: logs
logs: ## Follow logs from the Hadoop master container
	@echo "Following logs for $(MASTER_CONTAINER)... (Press Ctrl+C to stop)"
	docker-compose -f $(COMPOSE_FILE) logs -f $(MASTER_CONTAINER)

.PHONY: status
status: ## Show the status of the Hadoop containers
	@echo "--- Container Status ---"
	docker-compose -f $(COMPOSE_FILE) ps
	@echo "------------------------"

.PHONY: shell
shell: ## Get an interactive bash shell inside the Hadoop master container
	@echo "Opening bash shell in $(MASTER_CONTAINER)..."
	docker exec -it $(MASTER_CONTAINER) bash

.PHONY: hdfs-report
hdfs-report: ## Run 'hdfs dfsadmin -report' inside the master container (requires cluster running)
	@echo "--- HDFS Report ---"
	docker exec $(MASTER_CONTAINER) hdfs dfsadmin -report
	@echo "-------------------"

.PHONY: yarn-nodes
yarn-nodes: ## Run 'yarn node -list' inside the master container (requires cluster running)
	@echo "--- YARN Nodes ---"
	docker exec $(MASTER_CONTAINER) yarn node -list
	@echo "------------------"

test: ## [Project-specific] Run a sample MapReduce Pi job inside the master container
	@echo "Running MapReduce Pi example job..."
	@echo "Creating input directory (if needed)..."
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) exec $(MASTER_CONTAINER) hdfs dfs -mkdir -p /user/root
	@echo "Executing Pi job using explicit paths..."
	# Use absolute paths for both hadoop script and examples jar:
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) exec $(MASTER_CONTAINER) \
	  /opt/hadoop-3.3.6/bin/hadoop jar /opt/hadoop-3.3.6/share/hadoop/mapreduce/hadoop-mapreduce-examples-$(HADOOP_VERSION).jar pi 2 5
	@echo "Pi job finished."

exec: ## Get an interactive bash shell inside the Hadoop master container
	@echo "Opening bash shell in $(MASTER_CONTAINER)..."
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) exec $(MASTER_CONTAINER) bash

up: build ## Build (if needed) and start all Hadoop services in detached mode
	@echo "Starting Hadoop cluster..."
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) up -d
	@echo "Cluster starting... Use 'make logs' or check UIs (allow ~30-60s for full startup):"
	@echo "  Namenode:    http://localhost:9870"
	@echo "  YARN RM:     http://localhost:8088"
	@echo "  MR History:  http://localhost:19888"

ps: ## Show the status of the Hadoop containers
	@echo "--- Container Status ---"
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) ps
	@echo "------------------------"

prepare-wc-input: ## [Project-specific] Create sample input and upload to HDFS for WordCount
	@echo "Creating local sample input file ($(LOCAL_SAMPLE_FILE))..."
	@echo "hadoop mapreduce word count example for hadoop makefile" > $(LOCAL_SAMPLE_FILE)
	@echo "this is a second line for word count makefile" >> $(LOCAL_SAMPLE_FILE)
	@echo "hadoop example line to count words" >> $(LOCAL_SAMPLE_FILE)
	@echo "Uploading sample input to HDFS directory: $(HDFS_WC_INPUT_DIR)"
	# Ensure parent HDFS dir exists
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) exec $(MASTER_CONTAINER) hdfs dfs -mkdir -p $(HDFS_WC_INPUT_DIR)
	# Copy local file into the master container's /tmp directory first
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) cp $(LOCAL_SAMPLE_FILE) $(MASTER_CONTAINER):/tmp/$(LOCAL_SAMPLE_FILE)
	# Use hdfs dfs -put to move the file from the container's FS to HDFS (overwrite if exists)
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) exec $(MASTER_CONTAINER) hdfs dfs -put -f /tmp/$(LOCAL_SAMPLE_FILE) $(HDFS_WC_INPUT_DIR)
	@echo "Removing temporary file from container..."
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) exec $(MASTER_CONTAINER) rm /tmp/$(LOCAL_SAMPLE_FILE)
	@echo "Sample input uploaded to HDFS."
	@echo "Cleaning up local sample file..."
	@rm $(LOCAL_SAMPLE_FILE)

wordcount: up prepare-wc-input ## [Project-specific] Run WordCount MapReduce example job
	@echo "Running WordCount MapReduce job..."
	@echo "Input HDFS directory: $(HDFS_WC_INPUT_DIR)"
	@echo "Output HDFS directory: $(HDFS_WC_OUTPUT_DIR)"
	@echo "Removing previous output directory $(HDFS_WC_OUTPUT_DIR) from HDFS (if any)..."
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) exec $(MASTER_CONTAINER) hdfs dfs -rm -r -f $(HDFS_WC_OUTPUT_DIR)
	@echo "Executing WordCount job via hadoop jar using explicit paths..."
	# Using explicit path for hadoop command AND the examples JAR file
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) exec $(MASTER_CONTAINER) \
		/opt/hadoop-3.3.6/bin/hadoop jar /opt/hadoop-3.3.6/share/hadoop/mapreduce/hadoop-mapreduce-examples-$(HADOOP_VERSION).jar wordcount $(HDFS_WC_INPUT_DIR) $(HDFS_WC_OUTPUT_DIR)
	@echo "WordCount job finished (check YARN UI or use 'make view-wc-output')."

view-wc-output: ## [Project-specific] View the output of the WordCount job from HDFS
	@echo "Viewing output from $(HDFS_WC_OUTPUT_DIR)..."
	# Try with hardcoded path inside bash -c '' (inner shell should handle glob)
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) exec $(MASTER_CONTAINER) bash -c 'hdfs dfs -cat /user/root/output/wc_example/part-r-*'
	@echo "----------------------------------------"