param(
    [string]$InstallPath = $PSScriptRoot,
    [string]$Owner = "yyf2019",
    [string]$Repository = "PathOfOtakuExport"
)

$ErrorActionPreference = "Stop"

$VersionFileName = ".installed_release"
$ApiBaseUrl = "https://api.github.com/repos/$Owner/$Repository"
$UserAgent = "PathOfOtakuExportUpdater"

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
        "NoVersion" {
            return TextFromCodes @(26080, 27861, 33719, 21462, 26368, 26032, 29256, 26412, 21495, 12290)
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

function Expand-ReleaseToInstallPath {
    param(
        [string]$ZipUrl,
        [string]$TargetPath
    )

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("PathOfOtakuUpdate_" + [guid]::NewGuid().ToString("N"))
    $zipPath = Join-Path $tempRoot "release.zip"
    $extractPath = Join-Path $tempRoot "extract"

    New-Item -ItemType Directory -Path $tempRoot, $extractPath -Force | Out-Null

    try {
        Invoke-WebRequest -Uri $ZipUrl -Headers @{ "User-Agent" = $UserAgent } -OutFile $zipPath
        Expand-Archive -LiteralPath $zipPath -DestinationPath $extractPath -Force

        $releaseRoot = Get-ChildItem -LiteralPath $extractPath -Directory | Select-Object -First 1
        if ($null -eq $releaseRoot) {
            throw (Get-Text "NoReleaseRoot")
        }

        Copy-Item -LiteralPath (Join-Path $releaseRoot.FullName "*") -Destination $TargetPath -Recurse -Force
    }
    finally {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
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

    if ($installedVersion -eq $latestVersion) {
        Show-Message -Message (Get-Text "Latest" -Version $latestVersion)
        exit 0
    }

    $result = Show-Confirm -Message (Get-Text "UpdateAvailable" -Version $latestVersion)
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
        exit 0
    }

    Expand-ReleaseToInstallPath -ZipUrl $latestRelease.zipball_url -TargetPath $InstallPath
    Save-InstalledVersion -TargetPath $InstallPath -Version $latestVersion
    Show-Message -Message (Get-Text "Updated" -Version $latestVersion)
}
catch {
    Show-Message -Message (Get-Text "Failed" -Detail $_.Exception.Message) -Title (Get-Text "FailTitle")
    exit 1
}
