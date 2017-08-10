================== recursive SQL =========================
/*
Following query finds 40 shortest paths between 'P99999' and 'P95370', 
but to complete it in reasonable time we have to limit maximum path length by 7.
Array "vv" stores path from initial vertex to the current one.
*/
----------------------------
with recursive dist(_from,_to,d,vv) as (
      -- initial set
      select _from,_to,1,array[_from,_to] from r1
        where _from='P99999' -- 'P716248'
    union all
      -- recursively built set
      select d._from,r._to,d+1,vv||r._to
        from dist d, r1 r
        where d._to=r._from
          and not (r._to = any(vv))
          and d<=7  -- without this query is too slow
  )
  select * from dist 
    where _to = 'P95370'
    order by d
    limit 40
    ;

