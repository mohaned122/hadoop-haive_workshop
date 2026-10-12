# Hadoop Workshop — 15 Hard-Core Questions

Each question has 4 choices. Exactly one is correct — it is marked with `(*)`.

---

**Q1. Which one of these Java daemons is NOT part of the HDFS component?**

- A. NameNode
- B. DataNode
- C. ResourceManager (*)
- D. SecondaryNameNode

---

**Q2. Which daemon is the single holder of the HDFS namespace (directories, filenames, permissions, block mappings)?**

- A. DataNode
- B. NameNode (*)
- C. NodeManager
- D. JobHistoryServer

---

**Q3. What HDFS replication factor is configured in this single-node workshop (`hdfs-site.xml`)?**

- A. 1 (*)
- B. 2
- C. 3
- D. 4

---

**Q4. Hadoop 3.x (as used here) splits files into blocks. What is the default block size?**

- A. 64 MB
- B. 128 MB (*)
- C. 256 MB
- D. 512 MB

---

**Q5. This cluster sets `fs.defaultFS`. What is its exact value?**

- A. `hdfs://localhost:9870`
- B. `file:///`
- C. `hdfs://localhost:9000` (*)
- D. `hdfs://hadoop-master:8020`

---

**Q6. In this workshop the NameNode web UI is on port 9870 instead of the classic 50070. Why?**

- A. 50070 was already used by the ResourceManager
- B. Windows permanently reserves TCP range 50061–50160, so the host can never bind 50070 (*)
- C. 50070 is the HTTPS port and cannot be served by the NameNode
- D. Because `dfs.namenode.http-address` defaults to 9870 and the workshop never overrides it

---

**Q7. Which port exposes the ResourceManager web dashboard (YARN cluster page)?**

- A. 9870
- B. 8088 (*)
- C. 19888
- D. 9101

---

**Q8. For MapReduce jobs, YARN's NodeManager runs the `mapreduce_shuffle` auxiliary service. Which class is the correct implementation of the shuffle handler?**

- A. `org.apache.hadoop.hive.ql.exec.mr.ExecDriver`
- B. `org.apache.hadoop.mapreduce.v2.app.MRAppMaster`
- C. `org.apache.hadoop.mapred.ShuffleHandler` (*)
- D. `org.apache.hadoop.yarn.server.nodemanager.NodeManager`

---

**Q9. After a successful `wordcount` run writing to `/user/hadoop/output`, where do you read the aggregated results?**

- A. In `/user/hadoop/output/_SUCCESS`
- B. Directly from the map tasks' stdout in `userlogs`
- C. In the file `/user/hadoop/output/part-r-00000` (*)
- D. There is no persistent output; results only appear in the console

---

**Q10. For a single MapReduce job, which YARN component negotiates container resources from the cluster and drives the map/reduce phase transitions?**

- A. ResourceManager
- B. The job's ApplicationMaster (*)
- C. NodeManager
- D. NameNode

---

**Q11. Which daemon is directly responsible for launching the containers (processes) that run map/reduce tasks locally and reporting their status back?**

- A. ResourceManager
- B. DataNode
- C. NodeManager (*)
- D. SecondaryNameNode

---

**Q12. What is the real role of the Secondary NameNode?**

- A. A hot standby that takes over immediately if the NameNode crashes
- B. A read-only replica that balances read load
- C. It periodically checkpoints the NameNode: it fetches and merges the edit log into a new `fsimage` (*)
- D. It stores a duplicate copy of every HDFS block

---

**Q13. A container's `stderr` shows `Error: Could not find or load main class org.apache.hadoop.mapreduce.v2.app.MRAppMaster`. Which configuration setting fixes this in this workshop?**

- A. Increase `yarn.nodemanager.resource.memory-mb`
- B. Set `mapreduce.application.classpath` to the explicit `/opt/hadoop/share/hadoop/{mapreduce,common,yarn,hdfs}/* + lib/*` paths (*)
- C. Enable `dfs.namenode.http-address`
- D. Format the NameNode again

---

**Q14. In `docker-compose.yml`, the startup command contains `export PATH=/opt/hadoop/sbin:$$PATH`. Why is the doubled `$$` needed?**

- A. Docker Compose would otherwise interpolate `$PATH` with the **host** (Windows) PATH, whose parentheses break the shell — `$$` passes a literal `$PATH` into the container (*)
- B. Because bash requires `$$` to reference the PID and then append `PATH`
- C. YAML escapes a dollar sign only when doubled, or the syntax error `(` appears
- D. It is a typo that has no effect at runtime

---

**Q15. This cluster is started with compose `user: root`, yet the six Hadoop daemons do NOT run as root. Why, and who actually owns them?**

- A. The daemons run as root, and root rights in the container allow Hadoop to be faster
- B. `sshd` needs root to bind port 22 / set gid 0, while `start-dfs.sh`/`start-yarn.sh` drop each daemon to the `hadoop` user via the `HDFS_*_USER`/`YARN_*_USER` environment variables (*)
- C. The daemons run as a dedicated `datanode` POSIX user created by Hadoop
- D. The container runs as root but every process, including sshd, is forced to the `hadoop` user


---------------------------------------------------------------------------------------------------------------------------------------------------------------

1. **Quel composant de Hive stocke les métadonnées des tables (schémas, localisations) ?**

* Le Compiler
* * Le Metastore
* L'Execution Engine
* Le JobTracker

2. **Quel composant de Hive reçoit les requêtes HiveQL et gère les sessions ?**

* Le Metastore
* Le Compiler
* * Le Driver
* HDFS

3. **Dans quel système sont physiquement stockées les données traitées par Hive ?**

* Le Metastore
* La mémoire du Driver
* Une base de données relationnelle uniquement
* * HDFS

4. **Dans l'architecture Hadoop MapReduce, quel est le rôle du JobTracker ?**

* Stocker les métadonnées
* * Planifier et suivre les tâches MapReduce
* Analyser les requêtes HiveQL
* Stocker les fichiers de données

5. **Pourquoi Hive n'est-il pas adapté aux transactions en temps réel ?**

* Il ne peut pas traiter de grandes quantités de données
* Il ne prend pas en charge HiveQL
* * Il est principalement conçu pour le traitement analytique par lots
* Il fonctionne uniquement en mémoire

6. **Quelle est la principale différence entre Hadoop et Hive ?**

* Hadoop est un langage SQL et Hive un système de fichiers
* * Hadoop est un framework de stockage et de traitement distribué, tandis que Hive est un outil d'analyse de données
* Hadoop stocke uniquement les métadonnées
* Hadoop et Hive sont le même outil

7. **Pourquoi Hive est-il adapté au Big Data ?**

* Il traite uniquement de petites bases de données
* Il exige que toutes les données soient en mémoire
* Il fonctionne uniquement sur un ordinateur
* * Il exploite l'infrastructure distribuée de Hadoop

8. **Dans la commande `CLUSTERED BY (user_id) INTO 4 BUCKETS`, que choisit l'utilisateur ?**

* Créer quatre partitions selon la date
* Trier les lignes par `user_id`
* * Répartir les lignes en quatre buckets selon `user_id`
* Créer quatre tables indépendantes

9. **Comment les lignes sont-elles réparties dans les buckets ?**

* Selon leur ordre d'insertion
* De manière totalement aléatoire
* Selon la taille des lignes
* * À l'aide d'une fonction de hachage appliquée à la colonne de clustering

10. **Quelle est une limite de Hive ?**

* Il ne prend pas en charge les données distribuées
* Il ne permet pas les requêtes de type SQL
* * Il n'est généralement pas adapté aux requêtes à très faible latence
* Il fonctionne uniquement avec de petits fichiers texte

11. **Pourquoi le partitionnement peut-il améliorer les performances d'une requête Hive ?**

* Il duplique les données dans chaque partition
* Il supprime automatiquement les lignes inutiles
* Il transforme les requêtes en transactions temps réel
* * Il permet de lire uniquement les partitions pertinentes

12. **Pourquoi le Compiler communique-t-il avec le Metastore ?**

* Pour envoyer les résultats à l'utilisateur
* Pour gérer les connexions réseau
* * Pour récupérer les métadonnées nécessaires à la préparation du plan d'exécution
* Pour stocker les données en mémoire vive

13. **Quelle séquence représente correctement le début du traitement d'une requête Hive ?**

* Metastore → HDFS → Driver → Compiler
* Compiler → Driver → Metastore → Execution Engine
* * Driver → Compiler → récupération des métadonnées auprès du Metastore
* HDFS → Execution Engine → Compiler → Driver

14. **Quelle est la principale différence entre le Compiler et l'Execution Engine ?**

* Le Compiler stocke les données et l'Execution Engine les métadonnées
* * Le Compiler prépare le plan d'exécution, tandis que l'Execution Engine l'exécute
* Le Compiler gère les sessions et l'Execution Engine les connexions
* Le Compiler gère HDFS et l'Execution Engine remplace Hadoop

15. **Quel avantage de Hive permet de l'adapter à des besoins de traitement spécifiques ?**

* L'utilisation exclusive de fonctions prédéfinies
* L'impossibilité d'ajouter des fonctions
* L'exécution sur un seul ordinateur
* * La possibilité de créer des fonctions personnalisées (UDF)

16. **Quelle situation correspond le mieux à un usage de Hive ?**

* La gestion de transactions bancaires en temps réel
* Le développement d'un jeu vidéo interactif
* La gestion de sessions web à très faible latence
* * L'analyse de grands volumes de données historiques pour produire des rapports
