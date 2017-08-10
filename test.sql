-- Shortest paths between 40 vertex pairs
truncate table r01;
insert into r01 (v0,v2) values
 ('P714635','P117865')
,('P159297','P110511')
,('P811753','P700578')
,('P492780','P528010')
,('P234381','P567367')
,('P958642','P1232180')
,('P692377','P971721')
,('P595485','P217876')
,('P866844','P627370')
,('P1376583','P14549')
,('P368246','P317114')
,('P352273','P784535')
,('P541546','P127344')
,('P236623','P446462')
,('P187200','P841452')
,('P219524','P731898')
,('P503312','P1318044')
,('P1005','P1092752')
,('P936310','P680729')
,('P608336','P1402861')
,('P1220491','P965308')
,('P291232','P1307107')
,('P36353','P175674')
,('P965308','P201752')
,('P462344','P1379169')
,('P29435','P38933')
,('P1196866','P825403')
,('P999682','P973793')
,('P626705','P855126')
,('P447623','P1467849')
,('P805829','P1031968')
,('P101765','P1604307')
,('P217725','P49992')
,('P60920','P1462378')
,('P843607','P1176536')
,('P307570','P1299724')
,('P226965','P1477966')
,('P577188','P703342')
,('P61002','P1458919')
,('P236134','P1521866');


-- run test
-- selecting records from "r01" one by one and finding shrtest path
do $$
declare 
  _nn int := 0;
  r r01%rowtype;
  _t0 timestamp := clock_timestamp();
begin
        truncate table res;
        for r in select * from r01
        loop
          insert into res 
            (select _t0,r.v0,r.v2,p.*
                   ,extract(epoch from clock_timestamp()) - extract(epoch from _t0),_nn 
               from spath2(r.v0,r.v2,0) p order by d);
          _nn := _nn+1;
        end loop;
end;
$$

-- get detailed results
select nn,vv0 "_from",vv2 "_to",count(*) "path_length",max(t) "time (s)"
      ,max(t1)-(select min(t1) from res) "cumulative_time (s)"
  from res 
  group by nn,vv0,vv2 
  order by nn;

-- get general results
select sum(t) "total_time (s)",avg(t) "avg_time (s)",min(t) "min_time (s)",max(t) "max_time (s)"
    from (select nn,vv0,vv2,count(*) n,max(t) t,max(t1) from res group by nn,vv0,vv2 order by nn) x;
    
