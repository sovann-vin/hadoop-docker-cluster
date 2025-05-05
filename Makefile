# Makefile for managing the Hadoop Docker Compose setup

# Variables
COMPOSE_FILE = docker-compose.yml
MASTER_CONTAINER = hadoop-master
HADOOP_VERSION ?= 3.3.6 # Default Hadoop version, can be overridden e.g., make HADOOP_VERSION=3.3.5 test

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

.PHONY: test
test: ## Run a sample MapReduce Pi job inside the master container (requires cluster running)
	@echo "Running MapReduce Pi example job..."
	@echo "Creating input directory (if needed)..."
	docker exec $(MASTER_CONTAINER) hdfs dfs -mkdir -p /user/root
	@echo "Executing Pi job..."
	docker exec $(MASTER_CONTAINER) hadoop jar $$HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-$(HADOOP_VERSION).jar pi 2 5
	@echo "Pi job finished. Check master logs or container output for results."