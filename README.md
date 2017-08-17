# dijkstra-with-sql
SQL and PL/pgsql implementation of Shortest Path Dijkstra algorithm. Version for same length edge length (social network) for PostgreSQL server. 

In his very interesting post "Benchmark: PostgreSQL, MongoDB, Neo4j, OrientDB and ArangoDB"
(https://www.arangodb.com/2015/10/benchmark-postgresql-mongodb-arangodb/) 
Claudius Weinberger excluded PostgreSQL from shortest path test. 
Reason for this is that originally SQL had no recursion and traversing graphs 
to unknown depth was impossible. Now many SQL servers support recursive SQL, but it is still very ineffective 
at least in PostgreSQL. File dijkstra-recursive.sql contains an example of recursive query, 
which checks all paths and therefore very likely does not use Dijkstra algorithm.  

This is an attempt to test ability of relational databases to solve graph traversing problems in PL/pgSQL.
Procedures could be easily adapted to any SQL server with recursive SQL support. 

Original test code could be found here: https://github.com/weinberger/nosql-tests
and test data here: https://s3.amazonaws.com/nosql-sample-data/postgresql-9.4.4.tar.bz2

Relationship data that we need is in the postgresql-9.4.4/import/soc-pokec-relationships-postgres.txt

run

sed /_from/d soc-pokec-relationships-postgres.txt > relations.txt


and use relations.txt
in the data import command in db.sql:

COPY relations FROM 'path-to-data/relations.txt' (format csv, delimiter E'\t');



Files:

db.sql                  -- database structure, types, etc

dijkstra-recursive.sql  -- single query implementation

dijkstra.sql            -- PL/pgSQL implentation of Dijkstra Shortest Path algorithm

test.sql                -- test script


