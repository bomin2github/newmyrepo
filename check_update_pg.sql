update tbnodesreal set tasknode=1
where nodeid in (
 select nodeid from viewnodes
 where nodetype in (1,4) and existtype <> 3 and
 cast(virobotreserved1 as varchar(10))
 < cast(lastconntime-'7day'::interval as varchar(10))
)
