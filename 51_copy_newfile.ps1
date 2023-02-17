#새로 생성/변경된 파일만 선택하여 복사하는 스크립트, 'intervalDays' 값으로 대상파일 설정
$sourcePath = "download_path"
$destinationPath = "target_path"
$intervalDays = 7

$sourceFiles = Get-ChildItem -Path $sourcePath -Recurse | Where-Object {! $_.PSIsContainer}
$destinationFiles = Get-ChildItem -Path $destinationPath -Recurse | Where-Object {! $_.PSIsContainer}

foreach ($file in $sourceFiles) {
    $destinationFile = $destinationFiles | Where-Object {$_.FullName -eq $file.FullName.Replace($sourcePath, $destinationPath)}

    if ((get-date).adddays(-$intervaldays) -ge $file.LastWriteTime) {
        Write-Host "Skipping $($file.FullName) - it hasn't changed."
        continue
    }

    $destinationFilePath = $file.FullName.Replace($sourcePath, $destinationPath)
    $destinationDirectory = Split-Path $destinationFilePath -Parent
    if (!(Test-Path -Path $destinationDirectory)) {
        New-Item -ItemType Directory -Path $destinationDirectory | Out-Null
    }

    Copy-Item -Path $file.FullName -Destination $destinationFilePath -Force
    Write-Host "Copied $($file.FullName) to $($destinationFilePath)."
}
