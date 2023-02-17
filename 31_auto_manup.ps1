#HMU Tool 자동화 스크립트, 일부 제품/파일정보 마스킹. 변환 후 사용
$manuppath = "Tool path"
$downpath = "download path"
$downsdk = "download path2"
$sralnum = "productnumber"
$backuppath = "backup path"
$backupsdk = "backup path2"


##include module
	add-type -AssemblyName System.Windows.Forms

##function define
	function Get-Focus{
		[System.Windows.Forms.SendKeys]::SendWait("%{TAB}")
		Start-Sleep -s 1
		[System.Windows.Forms.SendKeys]::SendWait("%{TAB}")
		Start-Sleep -s 2
	}

	function Watch-Log{
		$logsize_new = (get-itemproperty $manuppath\LOGFILENAME.log length).length
		while ($logsize_new -ne $logsize_old) {
			Start-Sleep -s 5
			$logsize_tmp = $logsize_new
			$logsize_old = $logsize_tmp
			$logsize_new = (get-itemproperty $manuppath\LOGFILENAME.log length).length
			
			if ($logsize_new -eq $logsize_old) {
				clear-variable -name logsize_new
				clear-variable -name logsize_tmp
				clear-variable -name logsize_old
			}
		}
	}

##start script
	echo "`n For autobackup, Please exit the TOOLNAME within 10 minutes after download. `n`n"

<#
if ( (gps|where {$_.processname -eq "hmanup"}).id -lt 0 ){
	echo "notrunning"
}
if ((gps|where {$_.processname -eq "hmanup"}).id -gt 0){
	echo "running"
}
#>

##start hmanup process
$flag_pid = (gps|where {$_.processname -eq "PROCESSNAME"}).id

if ( $flag_pid -lt 0 ){
	start-process $manuppath\RUNFILENAME.exe -argumentlist PARAMINPUT
	while ( $flag_pid -lt 0 ){
		Start-Sleep -s 1
		$flag_pid = (gps|where {$_.processname -eq "PROCESSNAME"}).id
	}
	clear-variable -name flag_pid
}

elseif ( $flag_pid -gt 0 ){
	clear-variable -name flag_pid
	(New-Object -ComObject WScript.Shell).Popup("PROCESSNAME is already running.",0,"Warning",48)
	exit
}

##type path - module & engine
	[System.Windows.Forms.SendKeys]::SendWait($downpath)

##authentication
	[System.Windows.Forms.SendKeys]::SendWait("{TAB 3}")
	[System.Windows.Forms.SendKeys]::SendWait($sralnum)
	[System.Windows.Forms.SendKeys]::SendWait("{TAB 2}")
	[System.Windows.Forms.SendKeys]::SendWait("{ENTER}")

	Watch-Log
	echo " authentication completed. `n`n"
	get-focus

##exclusion SDK
	[System.Windows.Forms.SendKeys]::SendWait("{TAB 6}")
	[System.Windows.Forms.SendKeys]::SendWait("{END}")
	[System.Windows.Forms.SendKeys]::SendWait(" ")
	[System.Windows.Forms.SendKeys]::SendWait("{UP}")
	[System.Windows.Forms.SendKeys]::SendWait(" ")
	[System.Windows.Forms.SendKeys]::SendWait("{UP}")
	[System.Windows.Forms.SendKeys]::SendWait(" ")
	[System.Windows.Forms.SendKeys]::SendWait("{UP}")
	[System.Windows.Forms.SendKeys]::SendWait(" ")
	Start-Sleep -s 1

##start download module & engine
	[System.Windows.Forms.SendKeys]::SendWait("{TAB 5}")
	[System.Windows.Forms.SendKeys]::SendWait(" ")

	Watch-Log
	echo " download module & engine completed. `n"
	get-focus

##type path - SDK
	##[System.Windows.Forms.SendKeys]::SendWait("{END}")
	[System.Windows.Forms.SendKeys]::SendWait($downsdk)

##select SDK
	[System.Windows.Forms.SendKeys]::SendWait("{TAB 7}")
	[System.Windows.Forms.SendKeys]::SendWait("  ")
	[System.Windows.Forms.SendKeys]::SendWait("+{TAB}")
	[System.Windows.Forms.SendKeys]::SendWait(" ")
	[System.Windows.Forms.SendKeys]::SendWait("{DOWN}")
	[System.Windows.Forms.SendKeys]::SendWait(" ")
	[System.Windows.Forms.SendKeys]::SendWait("{DOWN}")
	[System.Windows.Forms.SendKeys]::SendWait(" ")
	[System.Windows.Forms.SendKeys]::SendWait("{DOWN}")
	[System.Windows.Forms.SendKeys]::SendWait(" ")
	Start-Sleep -s 1

##start download module & engine
	[System.Windows.Forms.SendKeys]::SendWait("{TAB 5}")
	[System.Windows.Forms.SendKeys]::SendWait(" ")

	Watch-Log	
	echo " download SDK completed. `n`n"
	get-focus

##exit manup
	[System.Windows.Forms.SendKeys]::SendWait("+{TAB 4}")
	[System.Windows.Forms.SendKeys]::SendWait(" ")


$time_ref = (date).addminutes(-10).tostring("yyMMdd_HHmm")
$time_mod = (get-itemproperty $downpath lastwritetime).lastwritetime.tostring('yyMMdd_HHmm')
$time_sdk = (get-itemproperty $downsdk lastwritetime).lastwritetime.tostring('yyMMdd_HHmm')

$count_mod = (get-childitem -path $backuppath -name|measure-object).count
$count_sdk = (get-childitem -path $backupsdk -name|measure-object).count


if ( $time_mod -gt $time_ref ){
	
	if ( $count_mod -gt 26 ){
		##Remove old backup - module & engine
		echo " Remove old backup - module & engine `n"
		cd $backuppath
		remove-item(get-childitem -name|select -first 1) -Force -recurse
	}

	##copy new backup - module & engine
	echo " copy new backup - module & engine `n"
	$time_engine = (get-itemproperty $downpath lastwritetime).lastwritetime.tostring('yyMMdd_HHmm')
	copy-item -recurse $downpath -destination $backuppath\$time_engine
	clear-variable -name time_engine

}


if ( $time_sdk -gt $time_ref ){
	
	if ( $count_sdk -gt 26 ){
		##Remove old backup - SDK
		echo " Remove old backup - SDK `n"
		cd $backupsdk
		remove-item(get-childitem -name|select -first 1) -Force -recurse
	}

	##copy new backup - sdk
	echo " copy new backup - sdk `n"
	$time_sdk = (get-itemproperty $downsdk lastwritetime).lastwritetime.tostring('yyMMdd_HHmm')
	copy-item -recurse $downsdk -destination $backupsdk\$time_sdk
	clear-variable -name time_sdk

}

echo "`nclear-variable"
clear-variable -name time_ref
clear-variable -name time_sdk
clear-variable -name count_mod
clear-variable -name count_sdk

remove-item function:\Get-Focus
remove-item function:\Watch-Log

clear-variable -name manuppath
clear-variable -name downpath
clear-variable -name downsdk
clear-variable -name sralnum
clear-variable -name backuppath
clear-variable -name backupsdk
