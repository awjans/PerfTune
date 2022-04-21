#Requires -RunAsAdministrator

'Auditing Application Packages' | Write-Host -ForegroundColor DarkCyan
Get-AppxPackage -AllUsers | Where-Object NonRemovable -eq $false | Sort-Object Name | Select-Object Name,PackageFullName | ForEach-Object {
    $Pkg = $_
    $keep = Read-Host -Prompt ('Keep {0}? ([Y]es, [n]o)' -f $Pkg.Name)
    IF (-not [String]::IsNullOrWhiteSpace($keep) -and $keep[0] -eq 'n') {
        TRY {
            'Removing {0}: ' -f $Pkg.Name | Write-Host -NoNewline -ForegroundColor DarkCyan
            Remove-AppxPackage -Package $Pkg.PackageFullName
            'Success' | Write-Host -ForegroundColor Green
        } CATCH {
            'Failure' | Write-Host -ForegroundColor Red
        }
    }
}

'Auditing Uninstall Applications' | Write-Host -ForegroundColor DarkCyan
@(
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
,   'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
,   'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
) | Get-Item | ForEach-Object {
    $Uninstall = $_
    $DisplayName = (Get-ItemProperty -Path $Uninstall.PSPath -Name DisplayName -ErrorAction SilentlyContinue).DisplayName
    $UninstallString = (Get-ItemProperty -Path $Uninstall.PSPath -Name UninstallString -ErrorAction SilentlyContinue).UninstallString
    IF ((-not [String]::IsNullOrWhiteSpace($DisplayName)) -and (-not [String]::IsNullOrWhiteSpace($UninstallString))) {
        $keep = Read-Host -Prompt ('Keep {0}? ([Y]es, [n]o)' -f $DisplayName)
        IF (-not [String]::IsNullOrWhiteSpace($keep) -and $keep[0] -eq 'n') {
            TRY {
                'Removing {0}: ' -f $DisplayName | Write-Host -NoNewline -ForegroundColor DarkCyan
                Start-Process -NoNewWindow -Wait $env:ComSpec -ArgumentList '/Q','/C',$UninstallString
                'Success' | Write-Host -ForegroundColor Green
            } CATCH {
                'Failure' | Write-Host -ForegroundColor Red
            }
        }
    }
}

'Auditing Startup Programs' | Write-Host -ForegroundColor DarkCyan
@(
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'
,   'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce'
,   'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
,   'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce'
) | Get-ItemProperty | ForEach-Object {
    $RegKey = $_
    $RegKey | Get-Member -MemberType NoteProperty | Where-Object Name -NotIn ('PSChildName','PSDrive','PSParentPath','PSPath','PSProvider') | ForEach-Object {
        $StartUp = $_
        $keep = Read-Host -Prompt ('Keep {0}? ([Y]es, [n]o)' -f $StartUp.Name)
        IF (-not [String]::IsNullOrWhiteSpace($keep) -and $keep[0] -eq 'n') {
            TRY {
                'Removing {0}: ' -f $StartUp.Name | Write-Host -NoNewline -ForegroundColor DarkCyan
                Remove-ItemProperty -Path $RegKey.PSPath -Name $StartUp.Name
                'Success' | Write-Host -ForegroundColor Green
            } CATCH {
                'Failure' | Write-Host -ForegroundColor Red
            }
        }
    }
}

'Auditing Scheduled Tasks' | Write-Host -ForegroundColor DarkCyan
Get-ScheduledTask | Where-Object State -eq Ready | Sort-Object TaskName | ForEach-Object {
    $Task = $_
    $keep = Read-Host -Prompt ('Keep {0} in {1}? ([Y]es, [n]o)' -f $Task.TaskName,$Task.TaskPath)
    IF (-not [String]::IsNullOrWhiteSpace($keep) -and $keep[0] -eq 'n') {
        TRY {
            'Disabling {0} in {1}: ' -f $Task.TaskName,$Task.TaskPath | Write-Host -NoNewline -ForegroundColor DarkCyan
            Disable-ScheduledTask -TaskName $Task.TaskName -TaskPath $Task.TaskPath
            'Success' | Write-Host -ForegroundColor Green
        } CATCH {
            'Failure' | Write-Host -ForegroundColor Red
        }
    }
}

$cleanMgrArgs = @{}
$sageSet = Get-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\* -Name StateFlags0153 -ErrorAction SilentlyContinue
IF ($sageSet) {
    $cleanMgrArgs.Add('ArgumentList',@('/SAGERUN:153'))
} ELSE {
    $cleanMgrArgs.Add('ArgumentList',@('/TUNEUP:153'))
}

TRY {
    'Running Clean Manager: ' | Write-Host -NoNewline -ForegroundColor DarkCyan
    Start-Process -NoNewWindow -Wait CLEANMGR.EXE @cleanMgrArgs
    'Success' | Write-Host -ForegroundColor Green
} CATCH {
    'Failure' | Write-Host -ForegroundColor Red
}

TRY {
    'Cleaning Deployment Image: ' | Write-Host -NoNewline -ForegroundColor DarkCyan
    Start-Process -NoNewWindow -Wait DISM.exe -ArgumentList '/online','/cleanup-image','/scanhealth'
    'Success' | Write-Host -ForegroundColor Green
} CATCH {
    'Failure' | Write-Host -ForegroundColor Red
}

TRY {
    'Fixing System File Corruption: ' | Write-Host -NoNewline -ForegroundColor DarkCyan
    Start-Process -NoNewWindow -Wait SFC.exe -ArgumentList '/scannow'
    'Success' | Write-Host -ForegroundColor Green
} CATCH {
    'Failure' | Write-Host -ForegroundColor Red
}
