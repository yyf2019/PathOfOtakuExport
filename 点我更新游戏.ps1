param(
    [string]$InstallPath = $PSScriptRoot,
    [string]$Owner = "yyf2019",
    [string]$Repository = "PathOfOtakuExport"
)

$ErrorActionPreference = "Stop"

$VersionFileName = ".installed_release"
$ApiBaseUrl = "https://api.github.com/repos/$Owner/$Repository"
$UserAgent = "PathOfOtakuExportUpdater"
$ReleaseFileNames = @("um.exe", "un.exe", "README.md")

function TextFromCodes {
    param([int[]]$Codes)

    $builder = New-Object System.Text.StringBuilder
    foreach ($code in $Codes) {
        [void]$builder.Append([char]$code)
    }
    return $builder.ToString()
}

function Get-Text {
    param(
        [string]$Key,
        [string]$Version = "",
        [string]$Detail = ""
    )

    switch ($Key) {
        "Title" {
            return "PathOfOtaku " + (TextFromCodes @(26356, 26032))
        }
        "FailTitle" {
            return "PathOfOtaku " + (TextFromCodes @(26356, 26032, 22833, 36133))
        }
        "NoReleaseRoot" {
            return TextFromCodes @(26410, 25214, 21040, 32, 114, 101, 108, 101, 97, 115, 101, 32, 35299, 21387, 21518, 30340, 20869, 23481, 12290)
        }
        "NoReleaseFiles" {
            return TextFromCodes @(114, 101, 108, 101, 97, 115, 101, 32, 37324, 27809, 26377, 25214, 21040, 38656, 35201, 30340, 25991, 20214, 12290)
        }
        "NoVersion" {
            return TextFromCodes @(26080, 27861, 33719, 21462, 26368, 26032, 29256, 26412, 21495, 12290)
        }
        "NoLfsDownload" {
            return TextFromCodes @(26080, 27861, 33719, 21462, 32, 76, 70, 83, 32, 25991, 20214, 19979, 36733, 22320, 22336, 12290)
        }
        "Latest" {
            return (TextFromCodes @(24403, 21069, 20026, 26368, 26032, 29256, 26412)) + $Version
        }
        "UpdateAvailable" {
            return (TextFromCodes @(24050, 26377, 26032, 29256, 26412)) + $Version
        }
        "ConfirmUpdate" {
            return TextFromCodes @(30830, 35748, 26356, 26032)
        }
        "Close" {
            return TextFromCodes @(20851, 38381)
        }
        "Updated" {
            return (TextFromCodes @(24050, 26356, 26032, 21040, 26368, 26032, 29256, 26412)) + $Version
        }
        "Failed" {
            return (TextFromCodes @(26356, 26032, 22833, 36133, 65306)) + $Detail
        }
    }
}

function Show-Message {
    param(
        [string]$Message,
        [string]$Title = (Get-Text "Title")
    )

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Title
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.ClientSize = New-Object System.Drawing.Size(360, 140)

    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Message
    $label.AutoSize = $false
    $label.TextAlign = "MiddleCenter"
    $label.Location = New-Object System.Drawing.Point(20, 20)
    $label.Size = New-Object System.Drawing.Size(320, 55)
    $form.Controls.Add($label)

    $closeButton = New-Object System.Windows.Forms.Button
    $closeButton.Text = Get-Text "Close"
    $closeButton.Size = New-Object System.Drawing.Size(96, 32)
    $closeButton.Location = New-Object System.Drawing.Point(132, 90)
    $closeButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.AcceptButton = $closeButton
    $form.CancelButton = $closeButton
    $form.Controls.Add($closeButton)

    [void]$form.ShowDialog()
    $form.Dispose()
}

function Show-Confirm {
    param(
        [string]$Message,
        [string]$Title = (Get-Text "Title")
    )

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Title
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.ClientSize = New-Object System.Drawing.Size(380, 150)

    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Message
    $label.AutoSize = $false
    $label.TextAlign = "MiddleCenter"
    $label.Location = New-Object System.Drawing.Point(20, 20)
    $label.Size = New-Object System.Drawing.Size(340, 55)
    $form.Controls.Add($label)

    $updateButton = New-Object System.Windows.Forms.Button
    $updateButton.Text = Get-Text "ConfirmUpdate"
    $updateButton.Size = New-Object System.Drawing.Size(110, 32)
    $updateButton.Location = New-Object System.Drawing.Point(75, 95)
    $updateButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $updateButton
    $form.Controls.Add($updateButton)

    $closeButton = New-Object System.Windows.Forms.Button
    $closeButton.Text = Get-Text "Close"
    $closeButton.Size = New-Object System.Drawing.Size(110, 32)
    $closeButton.Location = New-Object System.Drawing.Point(195, 95)
    $closeButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.CancelButton = $closeButton
    $form.Controls.Add($closeButton)

    $result = $form.ShowDialog()
    $form.Dispose()
    return $result
}

function Get-InstalledVersion {
    param([string]$TargetPath)

    $versionPath = Join-Path $TargetPath $VersionFileName
    if (Test-Path -LiteralPath $versionPath) {
        return (Get-Content -LiteralPath $versionPath -Raw).Trim()
    }

    return ""
}

function Save-InstalledVersion {
    param(
        [string]$TargetPath,
        [string]$Version
    )

    $versionPath = Join-Path $TargetPath $VersionFileName
    Set-Content -LiteralPath $versionPath -Value $Version -Encoding ASCII
}

function Get-LatestRelease {
    $headers = @{
        "Accept" = "application/vnd.github+json"
        "User-Agent" = $UserAgent
    }

    return Invoke-RestMethod -Uri "$ApiBaseUrl/releases/latest" -Headers $headers
}

function Test-LfsPointer {
    param([string]$FilePath)

    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
        return $false
    }

    $file = Get-Item -LiteralPath $FilePath
    if ($file.Length -gt 1024) {
        return $false
    }

    $firstLine = Get-Content -LiteralPath $FilePath -TotalCount 1 -ErrorAction SilentlyContinue
    return $firstLine -eq "version https://git-lfs.github.com/spec/v1"
}

function Get-LfsPointerInfo {
    param([string]$FilePath)

    $lines = Get-Content -LiteralPath $FilePath -ErrorAction Stop
    $oidLine = $lines | Where-Object { $_ -like "oid sha256:*" } | Select-Object -First 1
    $sizeLine = $lines | Where-Object { $_ -like "size *" } | Select-Object -First 1

    if ([string]::IsNullOrWhiteSpace($oidLine) -or [string]::IsNullOrWhiteSpace($sizeLine)) {
        return $null
    }

    return [pscustomobject]@{
        Oid = $oidLine.Substring("oid sha256:".Length).Trim()
        Size = [int64]($sizeLine.Substring("size ".Length).Trim())
    }
}

function Invoke-LfsDownload {
    param(
        [string]$Oid,
        [int64]$Size,
        [string]$OutputPath
    )

    $body = @{
        operation = "download"
        transfers = @("basic")
        objects = @(
            @{
                oid = $Oid
                size = $Size
            }
        )
    } | ConvertTo-Json -Depth 5

    $headers = @{
        "Accept" = "application/vnd.git-lfs+json"
        "Content-Type" = "application/vnd.git-lfs+json"
        "User-Agent" = $UserAgent
    }

    $batchUrl = "https://github.com/$Owner/$Repository.git/info/lfs/objects/batch"
    $response = Invoke-RestMethod -Method Post -Uri $batchUrl -Headers $headers -Body $body
    $downloadUrl = $response.objects[0].actions.download.href

    if ([string]::IsNullOrWhiteSpace($downloadUrl)) {
        throw (Get-Text "NoLfsDownload")
    }

    Invoke-WebRequest -Uri $downloadUrl -Headers @{ "User-Agent" = $UserAgent } -OutFile $OutputPath

    $downloaded = Get-Item -LiteralPath $OutputPath
    if ($downloaded.Length -ne $Size) {
        throw "LFS size mismatch: expected $Size, got $($downloaded.Length)."
    }
}

function Resolve-LfsFile {
    param([string]$FilePath)

    if (-not (Test-LfsPointer -FilePath $FilePath)) {
        return
    }

    $pointer = Get-LfsPointerInfo -FilePath $FilePath
    if ($null -eq $pointer) {
        return
    }

    Invoke-LfsDownload -Oid $pointer.Oid -Size $pointer.Size -OutputPath $FilePath
}

function Test-InstallComplete {
    param([string]$TargetPath)

    $readmePath = Join-Path $TargetPath "README.md"
    $gameExePath = Join-Path $TargetPath "um.exe"

    if (-not (Test-Path -LiteralPath $readmePath -PathType Leaf)) {
        return $false
    }

    if (-not (Test-Path -LiteralPath $gameExePath -PathType Leaf)) {
        return $false
    }

    if (Test-LfsPointer -FilePath $gameExePath) {
        return $false
    }

    return ((Get-Item -LiteralPath $gameExePath).Length -gt 1024)
}

function Install-ReleaseFilesFromZip {
    param(
        [string]$ZipUrl,
        [string]$Version,
        [string]$TargetPath
    )

    $zipFileName = "PathOfOtakuExport-$Version.zip"
    $zipPath = Join-Path $TargetPath $zipFileName
    $extractPath = Join-Path ([System.IO.Path]::GetTempPath()) ("PathOfOtakuUpdate_" + [guid]::NewGuid().ToString("N"))

    try {
        Invoke-WebRequest -Uri $ZipUrl -Headers @{ "User-Agent" = $UserAgent } -OutFile $zipPath
        Expand-Archive -LiteralPath $zipPath -DestinationPath $extractPath -Force

        $releaseRoot = Get-ChildItem -LiteralPath $extractPath -Directory | Select-Object -First 1
        if ($null -eq $releaseRoot) {
            throw (Get-Text "NoReleaseRoot")
        }

        $copiedCount = 0
        foreach ($fileName in $ReleaseFileNames) {
            $sourcePath = Join-Path $releaseRoot.FullName $fileName
            if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
                continue
            }

            $targetFilePath = Join-Path $TargetPath $fileName
            Copy-Item -LiteralPath $sourcePath -Destination $targetFilePath -Force
            Resolve-LfsFile -FilePath $targetFilePath
            $copiedCount += 1
        }

        if ($copiedCount -eq 0) {
            throw (Get-Text "NoReleaseFiles")
        }
    }
    finally {
        Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $extractPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

try {
    if (-not (Test-Path -LiteralPath $InstallPath)) {
        New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    }

    $installedVersion = Get-InstalledVersion -TargetPath $InstallPath
    $latestRelease = Get-LatestRelease
    $latestVersion = [string]$latestRelease.tag_name

    if ([string]::IsNullOrWhiteSpace($latestVersion)) {
        throw (Get-Text "NoVersion")
    }

    if (($installedVersion -eq $latestVersion) -and (Test-InstallComplete -TargetPath $InstallPath)) {
        Show-Message -Message (Get-Text "Latest" -Version $latestVersion)
        exit 0
    }

    $result = Show-Confirm -Message (Get-Text "UpdateAvailable" -Version $latestVersion)
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
        exit 0
    }

    Install-ReleaseFilesFromZip -ZipUrl $latestRelease.zipball_url -Version $latestVersion -TargetPath $InstallPath
    if (-not (Test-InstallComplete -TargetPath $InstallPath)) {
        throw (Get-Text "NoReleaseFiles")
    }

    Save-InstalledVersion -TargetPath $InstallPath -Version $latestVersion
    Show-Message -Message (Get-Text "Updated" -Version $latestVersion)
}
catch {
    Show-Message -Message (Get-Text "Failed" -Detail $_.Exception.Message) -Title (Get-Text "FailTitle")
    exit 1
}
