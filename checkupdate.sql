--주요 테이블/컬럼 정보 마스킹, 복원 후 사용해야 하는 SQL Query

--PostgreSQL
update TABLENAME_01 set ITEM_01=1
where ITEM_02 in (
 select ITEM_02 from VIEWNAME_01
 where ITEM_03 in (1,4) and ITEM_04 <> 3 and
 cast(ITEM_05 as varchar(10))
 < cast(ITEM_06-'7day'::interval as varchar(10))
)

--MSSQL
update TABLENAME_01 set ITEM_01=1
where ITEM_02 in (
select ITEM_02 from VIEWNAME_01
where ITEM_03 in (1,4) and ITEM_04 <> 3
and cast(ITEM_05 as nvarchar(10)) < convert(nvarchar(10),dateadd(day,-7,ITEM_06),120)
)
