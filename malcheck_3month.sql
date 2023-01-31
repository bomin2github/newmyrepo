--주요 테이블/컬럼 정보 마스킹, 복원 후 사용해야 하는 SQL Query
select VIEWNAME_01.ITEM_01,ITEM_02,
   sum(
     case substring(cast(VIEWNAME_01.ITEM_03 as varchar(10)) from 1 for 7)
      when substring(cast(now()-'1month'::interval as varchar(10)) from 1 for 7) then 1
     else 0 end) "1monthago",
   sum(
     case substring(cast(VIEWNAME_01.ITEM_03 as varchar(10)) from 1 for 7)
       when substring(cast(now()-'2month'::interval as varchar(10)) from 1 for 7) then 1
     else 0 end) "2monthago",
   sum(
     case substring(cast(VIEWNAME_01.ITEM_03 as varchar(10)) from 1 for 7)
       when substring(cast(now()-'3month'::interval as varchar(10)) from 1 for 7) then 1
     else 0 end) "3monthago"
 from VIEWNAME_01
   where substring(cast(ITEM_03 as varchar(10)) from 1 for 7)
     <> substring(cast(now() as varchar(10)) from 1 for 7)
   and
     substring(cast(ITEM_03 as varchar(10)) from 1 for 7)
     >= substring(cast(now()-'3month'::interval as varchar(10)) from 1 for 7)
 group by VIEWNAME_01.ITEM_01,ITEM_02
 order by VIEWNAME_01.ITEM_01,ITEM_02
