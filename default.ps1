$framework = '4.0'
Set-StrictMode -Version Latest

$solutionDir = Resolve-Path .

properties {
  $buildConfiguration = 'Release'
  $baseDir = "$solutionDir"
  $buildDir = "$baseDir\build"
  $toolsDir = "$baseDir\tools"
  $libDir = "$baseDir\lib"
  $packageDir = "$baseDir\packages"
  $srcDir = "$baseDir\src"
  $publishDir = Join-Path $buildDir 'Publish'
  $nunit = "$packageDir\NUnit.2.5.10.11092\tools\nunit-console.exe"
  $sevenZip = "$toolsDir\7za.exe"
  $unitTestReportPath = "$buildDir\UnitTestReports"
  $unitTestReport = "$unitTestReportPath\UnitTestReport.xml"
  $solution = "DeployToAzure.sln"
  $packageZip = "$buildDir\DeployToAzure.zip"
  $packageFiles = @("$buildDir\DeployToAzure.exe")
}

task default -depends Compile, Unit-Test, Publish

task ? -Description "Helper to display task info" {
    Write-Documentation
}

task Pre-Compile -Description "Anything that needs to be done before compilation" {
  $ErrorActionPreference = "SilentlyContinue"
  $ReportErrorShowSource = 0
  $ErrorView = "CategoryView"
}

task Compile -depends Clean, Compile-Solution -Description "Compiles everything"

task Test -depends Unit-Test, Integration-Test -Description "Run all tests" 

task Publish -Depends Compile, Package -Description "Prepare packaged files for deployment"

task Clean -Description "Nuke buildDir" { 
  Write-Host "##teamcity[progressMessage 'Cleaning']"

  if (Test-Path $buildDir) {
    cmd /c "rmdir /s /q $($buildDir)"
  }
}

task Compile-Solution -depends Pre-Compile -Description "Compiles the solution" {
  Write-Host "##teamcity[progressMessage 'Compiling Solution']"
  exec { msbuild /v:m $solution /property:OutputPath=$buildDir /property:"Configuration=$buildConfiguration;Platform=Any CPU" /target:Build }
}

task ILMerge -depends Compile-Solution -Description "IL Merges the output EXE" {
  Write-Host "##teamcity[progressMessage 'IL Merging']"
  exec { 
    & $toolsDir\ilmerge.exe $buildDir\DeployToAzureConsole.exe /lib:$buildDir 'Microsoft.WindowsAzure.StorageClient.dll' /targetplatform:'v4,C:\Windows\Microsoft.NET\Framework\v4.0.30319' /out:$buildDir\DeployToAzure.exe
  }
}

task Package -depends ILMerge -Description "Builds and zips the deployment package" {
  exec { & $sevenZip a $packageZip $packageFiles }
}

task Unit-Test -Depends Compile-Solution -Description "The unit tests" {
  Write-Host "##teamcity[progressMessage 'Running unit tests']"
  
  $testAssemblyName =  "DeployToAzure.Tests.dll"
  Write-Host "##teamcity[progressMessage 'Running $testAssemblyName']"
  mkdir -f $unitTestReportPath | Out-Null
  $testAssemblyPath = [System.IO.Path]::Combine($buildDir, $testAssemblyName)
  $testAssemblyReportFile = [System.IO.Path]::Combine($unitTestReportPath, $testAssemblyName) + ".xml"
  exec { & $nunit $testAssemblyPath /xml=$testAssemblyReportFile /noshadow /nologo /framework=net-4.0 "/exclude=Pending" /process=Single }
}

task Integration-Test -Description "Integration tests (none yet)" {
  # nothing to do yet - we don't have any integration tests yet.
}

