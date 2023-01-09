CREATE OR REPLACE FUNCTION public.get_monthlyreport(
	OUT st_day character varying,
	OUT ed_day character varying,
	OUT usrinfo character varying,
	OUT trtname character varying,
	OUT rcdtime timestamp without time zone,
	OUT modact character varying,
	OUT failcnt smallint)
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
		v_nodeid varchar(50);
		v_trtname varchar(4000);
		v_usrinfo_part1 varchar(50);
		v_usrinfo_part2 varchar(50);
		v_usrinfo_nodename varchar(50);
		v_rcdtime timestamp;
		v_modact varchar(10);
		v_failcnt smallint;

		
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
		,failcnt smallint
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
		select nodeid into v_nodeid from tbviruslog
			where cast(recordtime as varchar(10)) between v_sday and v_eday
		group by nodeid order by count(nodeid) desc limit 1;
		
		insert into tbtmp (st_day,ed_day,cnt,usrinfo) values (
			substring(v_sday from 6 for 10)
			,substring(v_eday from 6 for 10)
			,v_whilecnt*0
			,v_nodeid
			);
		
		--Top2 사용자정보
		select nodeid into v_nodeid from tbviruslog
			where cast(recordtime as varchar(10)) between v_sday and v_eday
		group by nodeid order by count(nodeid) desc limit 1 offset 1;
		
		insert into tbtmp (st_day,ed_day,cnt,usrinfo) values (
			substring(v_sday from 6 for 10)
			,substring(v_eday from 6 for 10)
			,v_whilecnt*0+1
			,v_nodeid
			);
		
		
		--사용자별 정보 update
		FOR i IN 0..1 LOOP
        		--nodeid/탐지명
			select nodeid,threatname into v_nodeid,v_trtname from tbviruslog
				where nodeid = (select tbtmp.usrinfo from tbtmp where tbtmp.cnt = i and tbtmp.st_day = substring(v_sday from 6 for 10))
								and
								cast(recordtime as varchar(10)) between v_sday and v_eday
			group by nodeid,threatname order by count(threatname) desc limit 1;

				--사용자정보_상위부서정보
			select case partname when '' then NULL else coalesce(split_part(partname,'|',1),'UNKNOWN') END
				into v_usrinfo_part1 from viewnodes where nodeid = (select tbtmp.usrinfo from tbtmp where tbtmp.cnt = i and tbtmp.st_day = substring(v_sday from 6 for 10));
				
				--사용자정보_하위부서정보
			select case partname when '' then NULL else coalesce(split_part(partname,'|',length(partname) - length(replace(partname,'|',''))+1),'UNKNOWN') END
				into v_usrinfo_part2 from viewnodes where nodeid = (select tbtmp.usrinfo from tbtmp where tbtmp.cnt = i and tbtmp.st_day = substring(v_sday from 6 for 10));
				
				--사용자정보_노드이름
			select case NodeName when '' then '미인증사용자' else coalesce(regexp_replace(split_part(nodename,') ',2),'(?<=.{1}).','*'), 'NULLdata') END
				into v_usrinfo_nodename from viewnodes where nodeid = (select tbtmp.usrinfo from tbtmp where tbtmp.cnt = i and tbtmp.st_day = substring(v_sday from 6 for 10));

				--다수 탐지 악성코드 최근 탐지 시간, 검사구분
			select recordtime, case
					moduleact when 256 then '실시간검사' when 512 then '예약검사' when 768 then '빠른검사' when 1024 then '정밀검사' when 1536 then '원격검사' when 2048 then '오른쪽마우스검사' when 2304 then '이동식디스크검사' when 2560 then '업데이트후검사' when 2816 then '전체검사' end
					into v_rcdtime, v_modact from tbviruslog
				where nodeid = (select tbtmp.usrinfo from tbtmp where tbtmp.cnt = i and tbtmp.st_day = substring(v_sday from 6 for 10))
					and threatname = v_trtname
					and cast(recordtime as varchar(10)) between v_sday and v_eday
			order by recordtime desc limit 1;

				--다수 탐지 악성코드의 치료실패/불가 수량
			select count(nodeid) into v_failcnt from ViewVirusLog
			where nodeid = (select tbtmp.usrinfo from tbtmp where tbtmp.cnt = i and tbtmp.st_day = substring(v_sday from 6 for 10))
				and threatname = v_trtname
				and cast(recordtime as varchar(10)) between v_sday and v_eday
				and ResultStatus in (32, 64, 240, 17);

				--update tmptable info
			update tbtmp set 
				usrinfo = v_usrinfo_part1||' '||v_usrinfo_part2||' '||v_usrinfo_nodename
				,trtname = v_trtname
				,rcdtime = v_rcdtime
				,modact = v_modact
				,failcnt = v_failcnt
			where tbtmp.usrinfo = v_nodeid and tbtmp.cnt = i and tbtmp.st_day = substring(v_sday from 6 for 10)
			;
    	END LOOP;
		
		v_whilecnt := v_whilecnt+1;		--데이터 통계 분할 제한
	
	END LOOP;
	
	return query select tbtmp.st_day,tbtmp.ed_day,tbtmp.usrinfo,tbtmp.trtname,tbtmp.rcdtime,tbtmp.modact,tbtmp.failcnt from tbtmp;
	
	drop table tbtmp;
	
END; $BODY$;

ALTER FUNCTION public.get_monthlyreport()
    OWNER TO hauri_db;

--select get_monthlyreport()
--drop FUNCTION get_monthlyreport
