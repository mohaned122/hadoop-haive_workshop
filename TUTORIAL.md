# Hadoop 3.5.0 — Workshop Tutorial

A single-node Hadoop cluster running in Docker. This tutorial shows you how to start it,
explore the web interfaces, and run your first MapReduce jobs.

---

## 1. Start the cluster

From this folder, run:

```powershell
docker compose up -d
```

First start builds the image and formats HDFS (takes a few minutes). Later starts skip
formatting and go straight to starting services.

Watch the startup log:

```powershell
docker compose logs -f
```

Wait until you see six Java daemons in the `jps` output (about 60–90 s):

```powershell
docker exec hadoop-master jps
```

You should see:

```
NameNode
DataNode
SecondaryNameNode
ResourceManager
NodeManager
JobHistoryServer
```

---

## 2. Web interfaces

Open these in your browser:

| Interface            | URL                         |
|----------------------|-----------------------------|
| NameNode (HDFS)      | http://localhost:9870       |
| ResourceManager (YARN) | http://localhost:8088     |
| Job History          | http://localhost:19888      |
| Secondary NameNode   | http://localhost:9101       |

- **NameNode**: browse the HDFS file tree (`Utilities → Browse the file system`).
- **ResourceManager**: watch running/finished applications in the cluster.

---

## 3. The console

### Inside the container

```powershell
docker exec -it hadoop-master bash
```

You start as `root`. Use the `hadoop` user for day-to-day work:

```powershell
docker exec -it -u hadoop hadoop-master bash
```

### Over SSH

```powershell
ssh -p 22 hadoop@localhost
```

Password: `hadoop`

---

## 4. HDFS basics

```powershell
docker exec -it -u hadoop hadoop-master bash
```

Create a directory and list the root:

```bash
hdfs dfs -mkdir -p /user/hadoop
hdfs dfs -ls /
```

Put a file into HDFS (create it first on the container's local disk):

```bash
echo "hello hadoop" > demo.txt
hdfs dfs -put demo.txt /user/hadoop/demo.txt
hdfs dfs -ls /user/hadoop
```

Read it back to the terminal, or download to local disk:

```bash
hdfs dfs -cat /user/hadoop/demo.txt
hdfs dfs -get /user/hadoop/demo.txt local-copy.txt
```

Delete a file:

```bash
hdfs dfs -rm /user/hadoop/demo.txt
```

Quick reference (`hdfs dfs -help <cmd>` for details):

| Task          | Command                                    |
|---------------|--------------------------------------------|
| list          | `hdfs dfs -ls <path>`                      |
| mkdir         | `hdfs dfs -mkdir -p <path>`                |
| copy in       | `hdfs dfs -put <local> <hdfs>`             |
| copy out      | `hdfs dfs -get <hdfs> <local>`             |
| view          | `hdfs dfs -cat <path>`                     |
| delete        | `hdfs dfs -rm <path>`                      |
| disk usage    | `hdfs dfs -du -h /`                        |

---

## 5. Your first MapReduce job (word count)

Word count is Hadoop's "hello world". Let's count the words in a couple of files.

### a) Create input data

```bash
mkdir -p ~/wc-input
echo "the quick brown fox jumps over the lazy dog" > ~/wc-input/a.txt
echo "lazy dogs sleep, quick foxes jump" > ~/wc-input/b.txt
hdfs dfs -mkdir -p /user/hadoop/input
hdfs dfs -put ~/wc-input/*.txt /user/hadoop/input/
hdfs dfs -ls /user/hadoop/input
```

### b) Run the job

```bash
hadoop jar /opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.5.0.jar \
  wordcount /user/hadoop/input /user/hadoop/output
```

Watch the progress:

```
map 0% reduce 0%
map 100% reduce 100%
Job job_XXXXXXXXXXXX finished successfully
```

### c) Read the results

```bash
hdfs dfs -cat /user/hadoop/output/part-r-00000
```

You should see each word with its count:

```
quick   2
the     2
...etc
```

The job's tracking URL is printed in the log, e.g.:

```
http://hadoop-master:8088/proxy/application_XXX/
```

Open it (replace `hadoop-master` with `localhost` from the browser to get the logs and
counters for each map/reduce attempt).

---

## 6. Other example programs

The examples jar contains several ready-to-run programs:

```bash
# Estimate Pi with 2 maps, 100 samples each
hadoop jar /opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.5.0.jar pi 2 100

# Generate / sort random data
hadoop jar /opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.5.0.jar teragen 100 /user/hadoop/tera-in
hadoop jar /opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.5.0.jar terasort /user/hadoop/tera-in /user/hadoop/tera-out
```

---

## 7. Stop & restart

```powershell
# Stop the cluster (data is kept)
docker compose stop

# Start it again (daemons restart, HDFS data survives)
docker compose start

# Or restart in place
docker compose restart
```

Completely reset (delete HDFS data, then format again):

```powershell
docker compose down -v
docker compose up -d
```

> Warning: `down -v` deletes the HDFS data volumes, so everything in HDFS is lost.

---

## 8. Logs & debugging

```powershell
# Hadoop daemon logs
docker exec -it hadoop-master bash
ls /opt/hadoop/logs/
tail -f /opt/hadoop/logs/hadoop-hadoop-namenode-*.log

# YARN container logs for a failed job
docker exec -it -u hadoop hadoop-master bash
ls /opt/hadoop/logs/userlogs/application_XXX/
```

Common checks:

- **Everything running?** `docker exec hadoop-master jps` → six daemons.
- **HDFS out of safe mode?** `docker exec hadoop-master hdfs dfsadmin -safemode get`
- **Can't reach a web UI?** Published ports are 9870, 8088, 19888, 9101, 9000, 22 — make
  sure none is used by another local service.