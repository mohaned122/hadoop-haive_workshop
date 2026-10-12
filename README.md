# Hadoop & Hive Workshop Project

This repository contains a complete, hands-on learning environment for Apache Hadoop and Apache Hive, built around a Dockerized single-node Hadoop cluster. It also includes a quiz system (both CLI and a protected web version) to test your knowledge.

## What is Apache Hadoop?

Apache Hadoop is an open-source, distributed framework for storing and processing large datasets across clusters of computers. It is designed to scale from a single server to thousands of machines, with built-in fault tolerance and high throughput.

### Core Hadoop Components (used in this project)

- **HDFS (Hadoop Distributed File System)**: The distributed storage layer. It splits large files into blocks and replicates them for fault tolerance.
  - **NameNode**: Manages the namespace (directories, files, permissions) and block locations.
  - **DataNode**: Stores the actual data blocks on disk.
  - **Secondary NameNode**: Performs periodic checkpoints of the NameNode's metadata (`fsimage` + edit logs), but it is **not** a hot standby.
- **YARN (Yet Another Resource Negotiator)**: The cluster resource manager that schedules and monitors jobs.
  - **ResourceManager (RM)**: Allocates cluster resources and handles job submission.
  - **NodeManager (NM)**: Manages resources and runs containers on each worker node.
  - **ApplicationMaster (AM)**: Created per job; negotiates containers and orchestrates map/reduce tasks.
- **MapReduce**: A programming model for distributed data processing. Jobs are split into Map and Reduce phases, with data shuffled between them.

In this workshop, we run Hadoop in **pseudo-distributed mode** inside a single Docker container (`hadoop-master`). This simulates a real cluster on one machine, making it perfect for learning.

## What is Apache Hive?

Apache Hive is a data warehouse infrastructure built on top of Hadoop. It allows you to query, analyze, and manage large datasets stored in HDFS using a SQL-like language called **HiveQL**.

### Hive Architecture (Key Components)

- **Metastore**: Central repository that stores metadata about Hive tables (schema, column types, table locations in HDFS, partitions, etc.). It typically uses a relational database (like Derby/MySQL/Postgres).
- **Driver**: The entry point for queries. It manages the lifecycle of a HiveQL statement, including session handling and query compilation/execution.
- **Compiler**: Parses HiveQL, performs semantic analysis, and generates an execution plan. It communicates with the Metastore to fetch table/column metadata.
- **Execution Engine**: Executes the optimized plan by submitting MapReduce (or Tez/Spark) jobs to YARN/Hadoop.
- **HDFS**: The physical storage layer for all table data (files, partitions, buckets).

### Hive vs Hadoop: Key Differences

| Aspect | Apache Hadoop | Apache Hive |
|---|---|---|
| **Purpose** | Distributed storage & general-purpose batch processing framework. | Data warehousing & SQL-based analytics on top of Hadoop. |
| **Interface** | Java APIs, MapReduce, CLI tools (`hdfs`, `yarn`, `hadoop`). | HiveQL (SQL-like) submitted via `hive`, `beeline`, or JDBC. |
| **Users** | Developers/engineers building distributed applications. | Data analysts, BI users, or anyone familiar with SQL. |
| **Processing** | Low-level, explicit MapReduce logic. | High-level, declarative SQL translated to MapReduce/YARN jobs. |
| **Metadata** | HDFS namespace only (files/blocks). No table schemas. | Rich metadata (tables, columns, partitions, buckets) in Metastore. |
| **Latency** | Batch-oriented; can be tuned but not designed for sub-second queries. | Also batch-oriented (typical MapReduce backend) — not ideal for real-time/low-latency transactions. |
| **Extensibility** | Highly flexible (custom InputFormats, mappers/reducers). | Supports User-Defined Functions (UDFs), User-Defined Aggregates (UDAFs), and SerDes to handle custom data formats. |

**In short:** Hadoop is the underlying engine (storage + compute), while Hive provides a SQL abstraction layer that makes big data querying accessible to a much wider audience.

## About This Workshop Project

This project is a self-contained learning kit that lets you run Hadoop + Hive-like concepts in practice and test yourself. Here's what you'll find:

### 1) Dockerized Hadoop Cluster (`docker-compose.yml`, `Dockerfile`, `setup-hadoop.sh`, `startup.sh`)
- **Single-node pseudo-distributed** Hadoop 3.5.0
- Automatically starts: NameNode, DataNode, SecondaryNameNode, ResourceManager, NodeManager, JobHistoryServer
- Pre-configured XMLs, SSH setup, and a safe startup that guards against reformatting on restarts
- Exposes web UIs and SSH for hands-on practice

### 2) Hands-on Tutorial (`TUTORIAL.md`)
Step-by-step guide covering:
- Starting/stopping the cluster
- Using HDFS CLI (`hdfs dfs` commands)
- Running MapReduce examples (like `wordcount`, `pi`, `teragen`/`terasort`)
- Exploring YARN/NameNode UIs
- Debugging common issues

### 3) Quiz System (CLI + Web)
- **CLI Quiz** (`quiz_app.py`, `quiz_data.py`, `quiz_scoring.py`): Interactive console quiz that reads questions from an external file, times answers, applies speed bonuses, and shows detailed results.
- **Protected Web Quiz** (`index.html`): Single-file static web app hosted-ready for GitHub Pages. Correct answers are XOR+Base64 encrypted (`answers.enc`) and decrypted at runtime (not stored in plaintext). 
- **Question Bank** (`quiz_questions.txt`): Merged Hadoop + Hive questions (31 total). Easy to extend without modifying the app code.
- **Configurable Scoring** (`quiz_config.example.json`, `QUIZ_README.md`): Time limits, base points, speed bonus, shuffle/seed, and rating thresholds.

### 4) Offline-First Web Hosting (`WEB_README.md`)
The web quiz is a tiny (~22 KB) single-file app that works offline when served locally. You can also expose it via `ngrok` when internet is available, but `localhost` remains fully functional if the connection drops — perfect for school environments.

### 5) Security Notes
- `index.html` embeds an encrypted blob of correct answer indices; no plaintext answers appear in the HTML source.
- `ENCRYPTION_README.md` (kept out of git) documents the obfuscation details.
- `.gitignore` is configured to exclude sensitive artifacts while keeping the protected web assets and CLI question text tracked as appropriate.

## Getting Started

### Quick CLI Quiz
```powershell
cd 'C:\Users\user\Desktop\hadoop workshop'
python quiz_app.py
```

### Quick Web Quiz (local, offline-capable)
```powershell
cd 'C:\Users\user\Desktop\hadoop workshop'
npx http-server -p 8080 -c-1 .
# open http://localhost:8080
```

### Start Hadoop Cluster
```powershell
docker compose up -d
# check: docker exec hadoop-master jps
# UIs: http://localhost:9870, http://localhost:8088, http://localhost:19888
```

See `TUTORIAL.md` and `QUIZ_README.md` for full details. 

## Learning Goals
After completing this workshop, you should be able to:
- Explain the roles of HDFS, YARN, and MapReduce
- Differentiate Hadoop and Hive architectures and use cases
- Navigate HDFS and run basic MapReduce jobs
- Understand Hive's metadata-driven model and SQL abstraction
- Apply your knowledge with the included quiz system