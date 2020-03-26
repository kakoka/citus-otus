## Как использовать демо стенд CitusDB

1. Если у вас уже установлен докер

```bash

git clone https://github.com/kakoka/citus-otus.git

cd ./citus-otus

docker-compose up -d

docker-compose docker-compose scale worker=2
```

На порту 5433 будет слушать router кластера CitusDB. Кластер состоит из 1 координатора и 2-х рабочих узлов.

2. Скрипт создания базы данных

```bash
psql -h 127.1 -U postgres -p5433 -f 'example/init-mt.sql'
```

создаст в базе данных postgres схему БД и заполнит ее тестовыми данными.

3. Возможно запустить ту же самую базу в варианте без шардирования

```bash
docker run -d --name postgres -p "5432:5432" -e POSTGRES_PASSWORD="" -e POSTGRES_HOST_AUTH_METHOD="trust" postgres:latest
```

и запустить скрипт, который создаст схему БД

```bash
psql -h 127.1 -U postgres -p5432 -f 'example/init-single.sql'
```

4. В файлах [query.sql](example/query.sql) и [diagostic.sql](exapmle/diagostic.sql) набор тестовых запросов для изучения.

5.[*] В файле [HA-CITUS.md](HA-CITUS.md) последовательность шагов для запуска кластера CitusDB в режиме HA.