<#
  Windows PowerShell script tương đương compile.sh
  Yêu cầu:
  - Đã cài `aiken` và có trong PATH
  - PowerShell 5.1+ hoặc PowerShell 7
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Bảo đảm chạy tại thư mục chứa script để dùng đường dẫn tương đối
if ($PSScriptRoot) {
  Set-Location -Path $PSScriptRoot
}

function Write-Section {
  param(
    [string]$Title
  )
  Write-Host ''
  Write-Host ('=' * 66)
  Write-Host $Title
  Write-Host ('=' * 66)
}

function Convert-Validator {
  param(
    [Parameter(Mandatory=$true)][string]$Validator
  )

  # Lấy module name (phần trước dấu chấm đầu tiên)
  $moduleName = ($Validator -split '\.')[0]
  $outDir = '.output'
  if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
  $outFile = Join-Path $outDir ("{0}.plutus.json" -f $moduleName)

  # 1) Convert validator -> JSON Plutus script
  Write-Host "Converting to JSON: $Validator -> $outFile"
  & aiken blueprint convert --validator $Validator | Set-Content -Encoding UTF8 -Path $outFile

  # 2) Lấy địa chỉ từ validator (có thể fail nếu validator có parameters)
  $addr = ""
  try {
    $addrOutput = & aiken blueprint address --validator $Validator 2>&1
    if ($LASTEXITCODE -eq 0) {
      $addr = ($addrOutput | Out-String).Trim()
    } else {
      Write-Host "  Warning: Cannot compute address (validator may be parameterized)"
      $addr = "PARAMETERIZED_VALIDATOR"
    }
  } catch {
    Write-Host "  Warning: Error getting address: $_"
    $addr = "ERROR_GETTING_ADDRESS"
  }

  # 3) Thêm field "address" vào JSON (dùng PowerShell JSON cmdlets, thay cho jq)
  $json = Get-Content -Raw -Path $outFile | ConvertFrom-Json
  $json | Add-Member -NotePropertyName address -NotePropertyValue $addr -Force
  $json | ConvertTo-Json -Depth 100 | Set-Content -Encoding UTF8 -Path $outFile

  Write-Host "Generated $outFile with address:"
  Write-Host "------------------------------------"
  # Pretty print
  (Get-Content -Raw -Path $outFile | ConvertFrom-Json) | ConvertTo-Json -Depth 100
  Write-Host ''
}

# 0) Build contract
Write-Section -Title 'Building contract with aiken build'
& aiken build

# 1) Nếu không có tham số: quét tất cả validators (.title kết thúc bằng .spend) từ plutus.json
if ($args.Count -eq 0) {
  Write-Host 'No validator specified. Scanning all validators from plutus.json...'
  Write-Host '=================================================================='

  if (-not (Test-Path 'plutus.json')) {
    throw 'plutus.json not found. Ensure `aiken build` generated blueprint in the current folder.'
  }

  $bp = Get-Content -Raw -Path 'plutus.json' | ConvertFrom-Json
  $validators = @()
  if ($bp -and $bp.validators) {
    $validators = @($bp.validators | Where-Object { $_.title -like '*.spend' } | ForEach-Object { $_.title })
  }

  if ((@($validators)).Length -eq 0) {
    throw 'No spend validators found in plutus.json'
  }

  foreach ($v in $validators) {
    if ([string]::IsNullOrWhiteSpace($v)) { continue }
    $validatorModule = ($v -split '\.')[0]
  Write-Host "Converting validator: $validatorModule"
    Convert-Validator -Validator $validatorModule
  }

  Write-Host 'All validators converted successfully!'
}
else {
  # 2) Single validator mode
  $validator = [string]$args[0]
  $validatorModule = ($validator -split '\.')[0]
  Write-Host "Converting single validator: $validatorModule"
  Convert-Validator -Validator $validatorModule
}
