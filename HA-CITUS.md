## Network ip addresses
```
monitor     172.28.0.2
router-a    172.28.0.7
router-b    172.28.0.8
node-a      172.28.0.3
node-b      172.28.0.4
node-c      172.28.0.5
node-d      172.28.0.6
```
## Creating network
```bash
docker network create --subnet=172.28.0.0/24 citus
```
## Runnig monitor
```bash
docker run -it --user postgres --name monitor --hostname monitor --network citus --ip=172.28.0.2 --add-host node-a:172.28.0.3 --add-host node-b:172.28.0.4 --add-host node-c:172.28.0.5 --add-host node-d:172.28.0.6 --add-host router:172.28.0.7 auto-citus

pg_autoctl create monitor --nodename monitor --pgdata $PGDATA
pg_autoctl run

pg_autoctl create formation --formation shard-a --kind citus
pg_autoctl create formation --formation shard-b --kind citus
```
## Shard A: node-a, node-b

### Node-A
```bash
docker run -it --user postgres --name node-a --hostname node-a --network citus --ip=172.28.0.3 --add-host monitor:172.28.0.2 --add-host node-b:172.28.0.4 --add-host node-c:172.28.0.5 --add-host node-d:172.28.0.6 --add-host router:172.28.0.7 auto-citus

pg_autoctl create postgres --pgdata $PGDATA --nodename node-a --monitor postgres://autoctl_node@monitor:5432/pg_auto_failover --formation shard-a
echo "shared_preload_libraries = 'citus'" >> $PGDATA/postgresql.conf
echo "hostssl   all all 172.28.0.0/24   trust" >> $PGDATA/pg_hba.conf
echo "host      all all 172.28.0.0/24   trust" >> $PGDATA/pg_hba.conf
pg_ctl -D $PGDATA restart
pg_autoctl run
```
### Node-B
```bash
docker run -it --user postgres --name node-b --hostname node-b --network citus --ip=172.28.0.4 --add-host node-a:172.28.0.3 --add-host monitor:172.28.0.2 --add-host node-c:172.28.0.5 --add-host node-d:172.28.0.6 --add-host router:172.28.0.7 auto-citus

pg_autoctl create postgres --pgdata $PGDATA --nodename node-b --monitor postgres://autoctl_node@monitor:5432/pg_auto_failover --formation shard-a
pg_autoctl run
```
## Shard B: node-c, node-d

### Node-C
```bash
docker run -it --user postgres --name node-c --hostname node-c --network citus --ip=172.28.0.5 --add-host monitor:172.28.0.2 --add-host node-b:172.28.0.4 --add-host node-d:172.28.0.6 --add-host router:172.28.0.7 auto-citus

pg_autoctl create postgres --pgdata $PGDATA --monitor postgres://autoctl_node@monitor:5432/pg_auto_failover --nodename node-c --formation shard-b
echo "shared_preload_libraries = 'citus'" >> $PGDATA/postgresql.conf
echo "hostssl   all all 172.28.0.0/24   trust" >> $PGDATA/pg_hba.conf
echo "host     all all 172.28.0.0/24   trust" >> $PGDATA/pg_hba.conf
pg_ctl -D $PGDATA restart
pg_autoctl run
```
### Node-D
```bash
docker run -it --user postgres --name node-d --hostname node-d --network citus --ip=172.28.0.6 --add-host node-a:172.28.0.3 --add-host monitor:172.28.0.2 --add-host node-c:172.28.0.5 --add-host router:172.28.0.7 auto-citus

pg_autoctl create postgres --pgdata $PGDATA --monitor postgres://autoctl_node@monitor:5432/pg_auto_failover --nodename node-d --formation shard-b

pg_autoctl run
```

## Router A
```bash
docker run -it --user postgres --name router-a --hostname router --network citus --ip=172.28.0.7 --add-host node-a:172.28.0.3 --add-host node-b:172.28.0.4 --add-host node-c:172.28.0.5 --add-host node-d:172.28.0.6 --add-host router-b:172.28.0.8 auto-citus

pg_autoctl create postgres --pgdata $PGDATA --monitor postgres://autoctl_node@monitor:5432/pg_auto_failover --nodename router-a

echo "shared_preload_libraries = 'citus'" >> $PGDATA/postgresql.conf
echo "citus.shard_count = 2"  >> $PGDATA/postgresql.conf
echo "citus.shard_replication_factor = 1" >> $PGDATA/postgresql.conf
echo "citus.explain_all_tasks = on" >> $PGDATA/postgresql.conf
echo "hostssl all all 172.28.0.0/24 trust" >> $PGDATA/pg_hba.conf
echo "log_destination = 'csvlog'" >> $PGDATA/postgresql.conf
echo "logging_collector = on" >> $PGDATA/postgresql.conf
echo "log_directory = 'pg_log'" >> $PGDATA/postgresql.conf
echo "log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'" >> $PGDATA/postgresql.conf

pg_ctl -D $PGDATA restart
```

## Router B
```bash
docker run -it --user postgres --name router-b --hostname router-b --network citus --ip=172.28.0.8 --add-host node-a:172.28.0.3 --add-host node-b:172.28.0.4 --add-host node-c:172.28.0.5 --add-host node-d:172.28.0.6 --add-host router-a:172.28.0.7 auto-citus

pg_autoctl create postgres --pgdata $PGDATA --monitor postgres://autoctl_node@monitor:5432/pg_auto_failover --nodename router-b

echo "citus.use_secondary_nodes = 'always'" >> $PGDATA/postgresql.conf
pg_ctl -D $PGDATA restart
```

## Cluster setup

```SQL
SET citus.shard_count TO 2;
SET citus.shard_replication_factor TO 1;
SET citus.explain_all_tasks TO on;

SELECT master_add_node('node-a', 5432);
SELECT master_add_secondary_node('node-b', 5432, 'node-a', 5432);
SELECT master_add_node('node-c', 5432);
SELECT master_add_secondary_node('node-d', 5432, 'node-c', 5432);

SELECT master_get_active_worker_nodes();
SELECT run_command_on_workers('show ssl');

-- Create table t
CREATE table t(
    id bigint, 
    text text, 
    CONSTRAINT id_pkey PRIMARY KEY (id)
    );

-- Ditribute table t
SELECT create_distributed_table('t','id');

-- Heplful function
CREATE OR REPLACE FUNCTION random_string(randomLength int)
RETURNS text AS $$
SELECT array_to_string(
  ARRAY(
      SELECT substring(
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',
        trunc(random()*62)::int+1,
        1
      )
      FROM generate_series(1,randomLength) AS gs(x)
  )
  , ''
)
$$ LANGUAGE SQL
RETURNS NULL ON NULL INPUT
VOLATILE LEAKPROOF;

-- Fill table t with random data
INSERT INTO t(
    id,text
    )
SELECT
    (random() * 100000000)::bigint,
     (SELECT random_string(10+i-i))
FROM generate_series(1,10) s(i)
ON CONFLICT DO NOTHING;

-- find sharded table
SELECT logicalrelid, partmethod, repmodel, shardcount,
replicationfactor FROM pg_dist_partition p INNER JOIN pg_dist_colocation c ON
p.colocationid = c. colocationid;
```