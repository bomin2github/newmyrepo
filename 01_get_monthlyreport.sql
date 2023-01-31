--주요 테이블/컬럼 정보 마스킹, 복원 후 사용해야 하는 SQL Query
CREATE OR REPLACE FUNCTION public.get_monthlyreport(
	OUT st_day character varying,
	OUT ed_day character varying,
	OUT usrinfo character varying,
	OUT trtname character varying,
	OUT rcdtime timestamp without time zone,
	OUT modact character varying,
	OUT ITEM_06 smallint)
    RETURNS SETOF record 
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE 
    ROWS 1000
AS $BODY$

declare
		--날짜 계산을 위한 변수
		st_month timestamp;
		ed_month timestamp;
		fst_wked timestamp;
		var_day timestamp;
		
		v_whilecnt smallint;
		b_sweek boolean;
		
		--형변환/Insert를 위한 변수
		v_st_month varchar(10);
		v_ed_month varchar(10);
		v_sday varchar(10);
		v_eday varchar(10);
		
		--user info
		v_ITEM_01 varchar(50);
		v_trtname varchar(4000);
		v_usrinfo_part1 varchar(50);
		v_usrinfo_part2 varchar(50);
		v_usrinfo_ITEM_04 varchar(50);
		v_rcdtime timestamp;
		v_modact varchar(10);
		v_ITEM_06 smallint;

		
BEGIN

	create temp table
	tbtmp(
		st_day varchar(5)
    	,ed_day varchar(5)
		,cnt smallint
		
		,usrinfo varchar(50)
		,trtname varchar(4000)
		,rcdtime timestamp
		,modact varchar(10)
		,ITEM_06 smallint
	);
	
	st_month := date_trunc('month',now()-'1month'::interval);	--월의 첫 날짜
	ed_month := st_month + '1month' - '1day'::interval;			--월의 마지막 날짜
	fst_wked := date_trunc('week',st_month)+'5day'::interval;	--월의 첫번째 주말(토요일)
	
	b_sweek := false;
	v_whilecnt := 0;
	
	if (fst_wked - st_month) < '4day'::interval then			--첫주/마지막주 기간 차이 보정
		fst_wked := fst_wked + '7day'::interval;
		b_sweek := true;
	end if;
	var_day := fst_wked;										--날짜 계산을 위한 변수
	
	
	WHILE cast(var_day as varchar(10)) < cast(ed_month as varchar(10)) LOOP

		--6주차 달의 첫주 날짜 보정
		if cast(cast((fst_wked - st_month) as varchar(2)) as smallint) < 2 and cast(var_day as varchar(10)) = cast(fst_wked as varchar(10)) then
			v_sday := cast(st_month as varchar(10));
			v_eday := cast((fst_wked+'7day'::interval) as varchar(10));
			var_day := (var_day+'8day'::interval);

		--초기 설정. 월초 날짜 적용
		elseif cast(var_day as varchar(10)) = cast(fst_wked as varchar(10)) then
			v_sday := cast(st_month as varchar(10));
			v_eday := cast(fst_wked as varchar(10));
			var_day := (var_day+'1day'::interval);
		
		--변수가 마지막 월 마지막 일자(ed_month)를 초과하였을 경우 보정
		elseif cast((var_day+'6day'::interval) as varchar(10)) > cast(ed_month as varchar(10)) or v_whilecnt = 3 then	--데이터 통계 분할 제한 (Default 4)
			v_sday := cast(var_day as varchar(10));
			v_eday := cast(ed_month as varchar(10));
			var_day := (var_day+'13day'::interval);	
		
		--일반설정
		else
			v_sday := cast(var_day as varchar(10));
			var_day := (var_day+'6day'::interval);
			v_eday := cast(var_day as varchar(10));
			var_day := (var_day+'1day'::interval);
		end if;
		
		
		--Top1 사용자정보
		select ITEM_01 into v_ITEM_01 from TABLENAME_01
			where cast(ITEM_05 as varchar(10)) between v_sday and v_eday
		group by ITEM_01 order by count(ITEM_01) desc limit 1;
		
		insert into tbtmp (st_day,ed_day,cnt,usrinfo) values (
			substring(v_sday from 6 for 10)
			,substring(v_eday from 6 for 10)
			,v_whilecnt*0
			,v_ITEM_01
			);
		
		--Top2 사용자정보
		select ITEM_01 into v_ITEM_01 from TABLENAME_01
			where cast(ITEM_05 as varchar(10)) between v_sday and v_eday
		group by ITEM_01 order by count(ITEM_01) desc limit 1 offset 1;
		
		insert into tbtmp (st_day,ed_day,cnt,usrinfo) values (
			substring(v_sday from 6 for 10)
			,substring(v_eday from 6 for 10)
			,v_whilecnt*0+1
			,v_ITEM_01
			);
		
		
		--사용자별 정보 update
		FOR i IN 0..1 LOOP
        		--ITEM_01/탐지명
			select ITEM_01,ITEM_02 into v_ITEM_01,v_trtname from TABLENAME_01
				where ITEM_01 = (select tbtmp.usrinfo from tbtmp where tbtmp.cnt = i and tbtmp.st_day = substring(v_sday from 6 for 10))
								and
								cast(ITEM_05 as varchar(10)) between v_sday and v_eday
			group by ITEM_01,ITEM_02 order by count(ITEM_02) desc limit 1;

				--사용자정보_상위부서정보
			select case ITEM_03 when '' then NULL else coalesce(split_part(ITEM_03,'|',1),'UNKNOWN') END
				into v_usrinfo_part1 from VIEWNAME_01 where ITEM_01 = (select tbtmp.usrinfo from tbtmp where tbtmp.cnt = i and tbtmp.st_day = substring(v_sday from 6 for 10));
				
				--사용자정보_하위부서정보
			select case ITEM_03 when '' then NULL else coalesce(split_part(ITEM_03,'|',length(ITEM_03) - length(replace(ITEM_03,'|',''))+1),'UNKNOWN') END
				into v_usrinfo_part2 from VIEWNAME_01 where ITEM_01 = (select tbtmp.usrinfo from tbtmp where tbtmp.cnt = i and tbtmp.st_day = substring(v_sday from 6 for 10));
				
				--사용자정보_노드이름
			select case ITEM_04 when '' then '미인증사용자' else coalesce(regexp_replace(split_part(ITEM_04,') ',2),'(?<=.{1}).','*'), 'NULLdata') END
				into v_usrinfo_ITEM_04 from VIEWNAME_01 where ITEM_01 = (select tbtmp.usrinfo from tbtmp where tbtmp.cnt = i and tbtmp.st_day = substring(v_sday from 6 for 10));

				--다수 탐지 악성코드 최근 탐지 시간, 검사구분
			select ITEM_05, case
					ITEMCODESTRING_01
					into v_rcdtime, v_modact from TABLENAME_01
				where ITEM_01 = (select tbtmp.usrinfo from tbtmp where tbtmp.cnt = i and tbtmp.st_day = substring(v_sday from 6 for 10))
					and ITEM_02 = v_trtname
					and cast(ITEM_05 as varchar(10)) between v_sday and v_eday
			order by ITEM_05 desc limit 1;

				--다수 탐지 악성코드의 치료실패/불가 수량
			select count(ITEM_01) into v_ITEM_06 from VIEWNAME_02
			where ITEM_01 = (select tbtmp.usrinfo from tbtmp where tbtmp.cnt = i and tbtmp.st_day = substring(v_sday from 6 for 10))
				and ITEM_02 = v_trtname
				and cast(ITEM_05 as varchar(10)) between v_sday and v_eday
				and ITEMCODESTRING_02;

				--update tmptable info
			update tbtmp set 
				usrinfo = v_usrinfo_part1||' '||v_usrinfo_part2||' '||v_usrinfo_ITEM_04
				,trtname = v_trtname
				,rcdtime = v_rcdtime
				,modact = v_modact
				,ITEM_06 = v_ITEM_06
			where tbtmp.usrinfo = v_ITEM_01 and tbtmp.cnt = i and tbtmp.st_day = substring(v_sday from 6 for 10)
			;
    	END LOOP;
		
		v_whilecnt := v_whilecnt+1;		--데이터 통계 분할 제한
	
	END LOOP;
	
	return query select tbtmp.st_day,tbtmp.ed_day,tbtmp.usrinfo,tbtmp.trtname,tbtmp.rcdtime,tbtmp.modact,tbtmp.ITEM_06 from tbtmp;
	
	drop table tbtmp;
	
END; $BODY$;

ALTER FUNCTION public.get_monthlyreport()
    OWNER TO OWNERNAME;

--select get_monthlyreport()
--drop FUNCTION get_monthlyreport
