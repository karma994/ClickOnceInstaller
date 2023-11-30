[CmdletBinding(PositionalBinding=$false)]
param (
    [switch]$OnlyBuild=$false
)

$appName = "WPF_ClickOnce" # 👈 Replace with your application project name.
$projDir = "WPF_ClickOnce" # 👈 Replace with your project directory (where .csproj resides).

Set-StrictMode -version 2.0
$ErrorActionPreference = "Stop"

Write-Output "Working directory: $pwd"

# Find MSBuild.
$msBuildPath = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" `
    -latest -requires Microsoft.Component.MSBuild -find MSBuild\**\Bin\MSBuild.exe `
    -prerelease | select-object -first 1
Write-Output "MSBuild: $((Get-Command $msBuildPath).Path)"

# Load current Git tag.
$tag = $(git describe --tags)
Write-Output "Tag: $tag"

# Parse tag into a three-number version.
$version = $tag.Split('-')[0].TrimStart('v')
$version = "$version.0"
Write-Output "Version: $version"

# Clean output directory.
$publishDir = "bin/publish"
$outDir = "$projDir/$publishDir"
if (Test-Path $outDir) {
    Remove-Item -Path $outDir -Recurse
}

# Publish the application.
Push-Location $projDir
try {
    Write-Output "Restoring:"
    dotnet restore -r win-x64
    Write-Output "Publishing:"
    $msBuildVerbosityArg = "/v:m"
    if ($env:CI) {
        $msBuildVerbosityArg = ""
    }
    & $msBuildPath /target:publish /p:PublishProfile=ClickOnceProfile `
        /p:ApplicationVersion=$version /p:Configuration=Release `
        /p:PublishDir=$publishDir /p:PublishUrl=$publishDir `
        $msBuildVerbosityArg

    # Measure publish size.
    $publishSize = (Get-ChildItem -Path "$publishDir/Application Files" -Recurse |
        Measure-Object -Property Length -Sum).Sum / 1Mb
    Write-Output ("Published size: {0:N2} MB" -f $publishSize)
}
finally {
    Pop-Location
}

if ($OnlyBuild) {
    Write-Output "Build finished."
    exit
}

# Stage and commit in the current branch.
Write-Output "Staging..."
git add -A
Write-Output "Committing..."
git commit -m "Update to v$version"
