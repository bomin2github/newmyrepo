--주요 테이블/컬럼 정보 마스킹, 복원 후 사용해야 하는 SQL Query

--기본형
select
	ITEM_01||' - Drive '||cast(ITEM_02 as varchar(1)) as ITEM_04

	--전체 용량: 고정된 시작 위치로부터 Free 키워드 기준으로 가변 길이 구하여 문자열 가공
	,replace(substring(VIEWNAME_01.ITEM_03 from 8 for (position('Free' in VIEWNAME_01.ITEM_03) - 10)),' ','.') as totalspace

	--가용 용량: Free 키워드 기준으로 가변 길이 구하여 문자열 가공
	,replace(substring(split_part(VIEWNAME_01.ITEM_03,'Free','2') from 2 for length(VIEWNAME_01.ITEM_03) - (position('Free' in VIEWNAME_01.ITEM_03)+4)),' ','.') as availspace

from VIEWNAME_02
	inner join VIEWNAME_01 
		on VIEWNAME_02.nodeid = VIEWNAME_01.nodeid
where ITEMCODE_01
	and ITEM_05='HDD'
order by ITEM_04



--확장형, 가용공간이 지정된 값 이하인 노드 필터
with
temptable as (
	select
		ITEM_01||' - Drive '||cast(ITEM_02 as varchar(1)) as ITEM_04

		--전체 용량: 고정된 시작 위치로부터 Free 키워드 기준으로 가변 길이 구하여 문자열 가공
		,replace(substring(VIEWNAME_01.ITEM_03 from 8 for (position('Free' in VIEWNAME_01.ITEM_03) - 10)),' ','.') as totalspace

		--가용 용량: Free 키워드 기준으로 가변 길이 구하여 문자열 가공
		,replace(substring(split_part(VIEWNAME_01.ITEM_03,'Free','2') from 2 for length(VIEWNAME_01.ITEM_03) - (position('Free' in VIEWNAME_01.ITEM_03)+4)),' ','.') as availspace

		--용량을 MB 단위로 환산: Free 키워드 기준으로 단위를 확인하여 정수형 가공
		,case substring(VIEWNAME_01.ITEM_03 from position('Free' in VIEWNAME_01.ITEM_03)-4 for 2)
			when 'GB' then
				cast(substring(VIEWNAME_01.ITEM_03 from 8 for (position('Free' in VIEWNAME_01.ITEM_03) - 14)) as integer)*1024
				+ cast(substring(VIEWNAME_01.ITEM_03 from position('Free' in VIEWNAME_01.ITEM_03)-5 for 1) as integer)*102	--소수 이하 용량을 일부 버림하여 계산
			when 'MB' then
				cast(substring(VIEWNAME_01.ITEM_03 from 8 for (position('Free' in VIEWNAME_01.ITEM_03) - 14)) as integer)
			when 'KB' then
				1
			else NULL end as to_mb_totalspace

		,case substring(VIEWNAME_01.ITEM_03 from length(VIEWNAME_01.ITEM_03)-1 for 2)
			when 'GB' then
				cast(substring(split_part(VIEWNAME_01.ITEM_03,'Free','2') from 2 for length(VIEWNAME_01.ITEM_03) - (position('Free' in VIEWNAME_01.ITEM_03)+8)) as integer)*1024
				+ cast(substring(VIEWNAME_01.ITEM_03 from length(VIEWNAME_01.ITEM_03)-2 for 1) as integer)*102
			when 'MB' then
				cast(substring(split_part(VIEWNAME_01.ITEM_03,'Free','2') from 2 for length(VIEWNAME_01.ITEM_03) - (position('Free' in VIEWNAME_01.ITEM_03)+8)) as integer)
			when 'KB' then
				1
			else NULL end as to_mb_availspace

	from VIEWNAME_02
		inner join VIEWNAME_01 
			on VIEWNAME_02.nodeid = VIEWNAME_01.nodeid
	where ITEMCODE_02
		and ITEM_05='HDD'
	order by ITEM_04
)
select
	ITEM_04
	,totalspace
	,availspace
	,split_part(cast((cast(to_mb_availspace as real) / cast(to_mb_totalspace as real))*100 as varchar(3)),'.','1') as availpercent
from temptable
where ((cast(to_mb_availspace as real) / cast(to_mb_totalspace as real))*100) < 15	--가용공간이 지정된 값 이하인 노드 필터
