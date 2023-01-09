update tbnodesreal set tasknode=1
  where nodeid in (
    select nodeid from viewnodes
      where nodetype in (1,4) and existtype <> 3
      and cast(VirobotReserved1 as nvarchar(10)) < convert(nvarchar(10),dateadd(day,-7,lastconntime),120)
  )
