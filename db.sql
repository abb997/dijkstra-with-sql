
-- types
create domain vert_t as text;
create domain dist_t as bigint;

-- graph
create table relations (
   _from text not null
  ,_to text not null
  ,primary key (_from,_to)
  );

-- load data, could take several minutes  
COPY relations FROM 'path-to-data/pokec-rel.txt' (format csv, delimiter E'\t');

-- very important
create unique index if not exists relations_i on relations (_to,_from);

-- this view allows to switch between different tables
-- procedures select data from "r" 
-- required fields are (_to,_from)
create or replace view r as (select * from relations);

-- tests
drop table if exists r01;
create table r01 (
   v0 text not null -- _from
  ,v2 text not null -- _to
  ,primary key (v0,v2)
);

-- table for results, 
-- query: select * from res order by t0,nn,d;
drop table if exists res;
create table res (
   t0 timestamp not null default current_timestamp
  ,vv0 vert_t not null  -- _from
  ,vv2 vert_t not null  -- _to
  ,v0  vert_t            -- current edge (v0,v2)
  ,v2  vert_t            --
  ,d   dist_t            -- distance to _from
  ,t   double precision  -- time to find v2 in seconds
  ,err integer
  ,t1 double precision  -- total_cumulative_time
  ,nn int not null default 0 -- current number of the (_from,_to) pair
  ,primary key (t0,vv0,vv2,v0,v2)
);
