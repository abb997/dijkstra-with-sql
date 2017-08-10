/*
Shortest path.

Distance d(u,v) between two vertices is length of shortest path from u to v.
Distance between sets A, B of vertices is minimal distance d(a,b) 
icalculated for all a in A and b in B.
Distance is not necessarily symmetrical.
In graph G sphere S(v,N) with center v and radius N 
is set of vertices {u} such that d(v,u) <= N.

Program uses Dijkstra shortest path algorithm for graph with same edge lengths
which is common for social networks. 
It is probably not very difficult to iimplement it in general case.

Algorithm starts from both sides, vertices v0 and v2 become 
centers of spheres S0, S2, each iteration increases radius of S0 and S2 by 1 
until either distance d(S0,S2) <= 2 or no vertex added to one of spheres.
  

Returns
  {(_from,_to,d,t,error_code) } - set of edges (_from,_to) of the path with distance from the initial vertex _v0 to _to
                                  and time spent to reach _to.
error_code=0 - no error
          -1 - vertex not in graph
          -8 - vertex unreachable or maximum radius reached

Note that in PL/pgsql for the functions returning record sets
"return" operator does not return from function,
it just adds records to the result set
*/
-------------------------

/*
-- graph
create table relations (
   _from text not null
  ,_to text not null
  ,primary key (_from,_to)
  );

*/

create unique index if not exists relations_i on relations (_to,_from); -- either on "relations" or "r1"

create or replace function path_bld(_v0 vert_t, _v1 vert_t, _v2 vert_t,_d dist_t,_t0 timestamp)
    returns table(_from vert_t,_to vert_t,d dist_t,t double precision) as $$
  declare
    _t timestamp := clock_timestamp();
  begin
    return query
      -- moving backward from _v0 = v(n) to u(n) = v(n-1) to u(n-1) ... v(0) to u(0) = initial_vertex
      with recursive ll(u,v,d,t) as (
        select v.u,v.v,v.d,v.t from vv v where is2=FALSE and v=_v0
        union all
        select v.u,v.v,v.d,v.t
          from ll p, vv v
          where p.u=v.v
            and v.u is not null
      )
      select ll.u,ll.v,ll.d,extract(epoch from ll.t) - extract(epoch from _t0) from ll;

    _d:=_d+1;
    if (_v1 is null) then
      return query select _v0,_v2,_d,extract(epoch from _t) - extract(epoch from _t0);
    else
      return query select _v0,_v1,_d,extract(epoch from _t) - extract(epoch from _t0);
      _d:=_d+1;
      return query select _v1,_v2,_d,extract(epoch from _t) - extract(epoch from _t0);
    end if;

    return query
      -- moving forward from _v2 = u(_d+1) to v(_d+1) = u(_d+2) to v(_d+2) ... u(n) to v(n) = target_vertex
      with recursive ll(u,v,d,t) as (
        select v.u,v.v,(_d+1)::dist_t,v.t from vv v where is2=TRUE and v=_v2
        union all
        select v.u,v.v,(p.d+1)::dist_t,v.t
          from ll p, vv v
          where p.u=v.v
            and v.u is not null
      )
      select ll.v,ll.u,ll.d,extract(epoch from ll.t) - extract(epoch from _t0) from ll;
  end;
$$ language plpgsql;

create or replace function spath2(
     _v0 vert_t -- from
    ,_v2 vert_t -- to
    ,_d2 dist_t -- maximum sphere radius, 0 - unlimited
    )
    returns table(_from vert_t,_to vert_t,d dist_t,t double precision,err integer) as $$
  declare
    _d dist_t := 1;
    _t0 timestamp := clock_timestamp();
    _xx integer := 0;
    _u0 vert_t;
    _u1 vert_t;
    _u2 vert_t;
  begin
    -- create unique index if not exists rel_i on relations (_to,_from); -- this is important
    create or replace view r as (select * from relations); -- helps to switch between "r1" and "relations"

    -- check if edges (_v0,*) and (*,_v2) in the graph
    select count(*) into _xx from
      (           (select 1 from r where r._from = _v0 limit 1)
        union all (select 1 from r where r._to   = _v2 limit 1)) x
      having count(*)=2;
    if (found) then
      -- check if edge (_v0,_v2) is in the graph
      select 1 into _xx from r where r._from = _v0 and r._to = _v2;
      if (found) then
        return query select _v0,_v2,1::dist_t,cast(0.0 as double precision),0;
      else
        -- drop table if exists vv;
        -- create unlogged table if not exists vv (
        create local temporary table if not exists vv (
           is2 boolean not null default FALSE -- if FALSE then center is in start vertex, else in target
          ,v vert_t not null                  -- current vertex
          ,u vert_t                           -- previous vertex
          ,d dist_t not null                  -- distance to the center, radius of the sphere
          ,t timestamp not null default current_timestamp -- time to reach this vertex
          ,primary key (is2,v)
          ) on commit drop;
        truncate table vv; -- just in case
        create index if not exists vv_d_i on vv (is2, d desc);

        _t0 := clock_timestamp();
        -- insert centers and spheres of radius 1, they already have been checked for (_v0,_v2)
        insert into vv (is2,v,u,d,t) (select FALSE,_v0,null,0,_t0
                            union all select FALSE,r._to,r._from,1,clock_timestamp() from r where r._from=_v0);
        insert into vv (is2,v,u,d,t) (select  TRUE,_v2,null,0,_t0
                            union all select  TRUE,r._from,r._to,1,clock_timestamp() from r where r._to=_v2);

        loop
          -- check if spheres are 1 or 2 steps apart
          select v0,v1,v2 into _u0,_u1,_u2 from
            ((select 1 d,v0.v v0,null v1,v2.v v2 from vv v0, vv v2, r
                where v0.is2=FALSE and v2.is2=TRUE
                  and v0.v=r._from and v2.v=r._to
								  -- and v0.d=_d and v2.d=_d -- slow
                  limit 1) -- all pathes equal, pick first
             union all
             (select 2 d,v0.v,r0._to,v2.v from vv v0, vv v2, r r0, r r2
                where v0.is2=FALSE and v2.is2=TRUE
                  and v0.v=r0._from and v2.v=r2._to
                  and r0._to=r2._from
                  -- and v0.d=_d and v2.d=_d -- slow
                limit 1)
            ) x
            order by x.d asc limit 1; -- if found both pick x.d=1, it is shortest
         if (found) then       -- target found, build result set
           return query select *,0 from path_bld(_u0,_u1,_u2,_d,_t0);
           exit when true;
         end if;

          /*  main query
              exit when one of spheres does not grow
              this means one of connection components traversed,
              and other vertex was not found
          */
          insert into vv (is2,v,u,d,t) (
            select FALSE,r._to,min(r._from),_d+1,clock_timestamp()
              from vv v, r
              where v.is2=FALSE
                and v.d=_d
                and v.v=r._from
                and not exists (select 1 from vv w where is2=FALSE and w.v=r._to)
              group by r._to);
          if (found) then
            insert into vv (is2,v,u,d,t) ( -- _from mapsto _to, _to mapsto _from
              select TRUE,r._from,min(r._to),_d+1,clock_timestamp()
                from vv v, r  -- for restricted dataset replace "relations" by "r1"
                where v.is2=TRUE
                  and v.d=_d
                  and v.v=r._to
                  and not exists (select 1 from vv w where is2=TRUE and w.v=r._from)
                group by r._from);
          end if;

          _d:=_d+1;
          if (_d2>0 and _d>=_d2) or (not found) then
            -- return query select vv.u,vv.v,vv.d,extract(epoch from vv.t) - extract(epoch from _t0) from vv; -- debug
            return query select _v0,_v2,_d,extract(epoch from clock_timestamp()::timestamp) - extract(epoch from _t0),-8; -- vertex unreachable, distance is infinity
            exit when true;
          end if;
        end loop;
      end if;
    else
      return query select _v0,_v2,0::dist_t,extract(epoch from clock_timestamp()::timestamp) - extract(epoch from _t0),-1; -- wrong _v0 or _v2
    end if;
  end;
$$ language plpgsql;


-- example: 
--select * from spath2('P99999','P95370',0) order by d;
