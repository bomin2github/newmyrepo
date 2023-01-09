with
temptable as (
	select
		localip||' - Drive '||cast(typesubinfo as varchar(1)) as driveinfo

		--전체 용량: 고정된 시작 위치로부터 Free 키워드 기준으로 가변 길이 구하여 문자열 가공
		,replace(substring(viewhwinfo.description from 8 for (position('Free' in viewhwinfo.description) - 10)),' ','.') as totalspace

		--가용 용량: Free 키워드 기준으로 가변 길이 구하여 문자열 가공
		,replace(substring(split_part(viewhwinfo.description,'Free','2') from 2 for length(viewhwinfo.description) - (position('Free' in viewhwinfo.description)+4)),' ','.') as availspace

		--용량을 MB 단위로 환산: Free 키워드 기준으로 단위를 확인하여 정수형 가공
		,case substring(viewhwinfo.description from position('Free' in viewhwinfo.description)-4 for 2)
			when 'GB' then
				cast(substring(viewhwinfo.description from 8 for (position('Free' in viewhwinfo.description) - 14)) as integer)*1024
				+ cast(substring(viewhwinfo.description from position('Free' in viewhwinfo.description)-5 for 1) as integer)*102	--소수 이하 용량을 일부 버림하여 계산
			when 'MB' then
				cast(substring(viewhwinfo.description from 8 for (position('Free' in viewhwinfo.description) - 14)) as integer)
			when 'KB' then
				1
			else NULL end as to_mb_totalspace

		,case substring(viewhwinfo.description from length(viewhwinfo.description)-1 for 2)
			when 'GB' then
				cast(substring(split_part(viewhwinfo.description,'Free','2') from 2 for length(viewhwinfo.description) - (position('Free' in viewhwinfo.description)+8)) as integer)*1024
				+ cast(substring(viewhwinfo.description from length(viewhwinfo.description)-2 for 1) as integer)*102
			when 'MB' then
				cast(substring(split_part(viewhwinfo.description,'Free','2') from 2 for length(viewhwinfo.description) - (position('Free' in viewhwinfo.description)+8)) as integer)
			when 'KB' then
				1
			else NULL end as to_mb_availspace

	from viewnodes
		inner join viewhwinfo 
			on viewnodes.nodeid = viewhwinfo.nodeid
	where nodetype in (1,4)	--콘솔 표시 노드 (휴지통 노드 포함)
		and jobname='HDD'
	order by driveinfo
)
select
	driveinfo
	,totalspace
	,availspace
	,split_part(cast((cast(to_mb_availspace as real) / cast(to_mb_totalspace as real))*100 as varchar(3)),'.','1') as availpercent
from temptable
where ((cast(to_mb_availspace as real) / cast(to_mb_totalspace as real))*100) < 15	--가용공간이 지정된 값 이하인 노드 필터
