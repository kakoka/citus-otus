-- Query 1: Найдем распределенные таблицы в БД.
 
SELECT tablename
FROM pg_tables t
JOIN pg_dist_partition p
  ON t.tablename = p.logicalrelid::text
WHERE schemaname = 'public';
 
-- Query 2: Описание, как таблицы распределены.
 
SELECT logicalrelid, partmethod, repmodel, shardcount,
replicationfactor FROM pg_dist_partition p INNER JOIN pg_dist_colocation c ON
p.colocationid = c. colocationid;
 
-- Query 3: На каких рабочих узлах какие шарды размещены.
 
SELECT shardid, nodename
FROM pg_dist_shard_placement order by nodename;
 
-- Query 4: Вычислим размер каждой шарды для таблицы impressions.

SELECT *
FROM run_command_on_shards('impressions', $cmd$
  SELECT json_build_object(
    'shard_name', '%1$s',
    'size',       pg_size_pretty(pg_table_size('%1$s'))
  );
$cmd$);

 
-- Query 5: Вычислим размер распределенной таблицы clicks.
 
SELECT pg_size_pretty((
    SELECT sum(result::bigint)
    FROM run_command_on_shards(
    'clicks',
    $cmd$
        SELECT pg_table_size('%1$s');
    $cmd$
    ))
) as distibuted_table_size;
 
-- query 6: Вычислим размер базы данных на каждом рабочем узле.
 
SELECT *
    FROM run_command_on_workers(
        $cmd$
        SELECT pg_size_pretty(pg_database_size('postgres'));
        $cmd$
        );