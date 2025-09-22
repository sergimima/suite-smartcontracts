# ===== SMART CONTRACT DEPLOYMENT SUITE (PowerShell) =====
# Secure deployment script for ActivitiesPlatformCertificates
# 
# Usage: .\deploy.ps1 [network] [options]
# Example: .\deploy.ps1 sepolia -verify

param(
    [string]$Network = "sepolia",
    [switch]$Verify,
    [switch]$DryRun,
    [string]$Owner = "",
    [switch]$Help
)

# Colors for output
$Red = "Red"
$Green = "Green"
$Yellow = "Yellow"
$Blue = "Cyan"

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor $Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor $Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor $Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor $Red
}

function Show-Usage {
    Write-Host "Usage: .\deploy.ps1 [network] [options]"
    Write-Host ""
    Write-Host "Networks:"
    Write-Host "  sepolia     - Ethereum Sepolia testnet (default)"
    Write-Host "  base_sepolia- Base Sepolia testnet"
    Write-Host "  mumbai      - Polygon Mumbai testnet"
    Write-Host "  eth         - Ethereum mainnet"
    Write-Host "  polygon     - Polygon mainnet"
    Write-Host "  arbitrum    - Arbitrum One"
    Write-Host "  optimism    - Optimism"
    Write-Host "  base        - Base mainnet"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Verify     - Verify contract on Etherscan after deployment"
    Write-Host "  -DryRun     - Simulate deployment without broadcasting"
    Write-Host "  -Owner      - Set initial owner address (default: deployer)"
    Write-Host "  -Help       - Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\deploy.ps1 sepolia -Verify"
    Write-Host "  .\deploy.ps1 base_sepolia -Verify"
    Write-Host "  .\deploy.ps1 polygon -Owner 0x1234... -Verify"
    Write-Host "  .\deploy.ps1 mumbai -DryRun"
}

if ($Help) {
    Show-Usage
    exit 0
}

# Validate network parameter
$ValidNetworks = @("sepolia", "base_sepolia", "mumbai", "eth", "polygon", "arbitrum", "optimism", "base")
if ($Network -notin $ValidNetworks) {
    Write-Error "Invalid network: $Network"
    Show-Usage
    exit 1
}

# Check if .env file exists
if (-not (Test-Path ".env")) {
    Write-Warning ".env file not found. Creating from template..."
    Copy-Item ".env.example" ".env"
    Write-Info "Please edit .env file with your configuration and run again."
    exit 1
}

# Load environment variables from .env file
Get-Content ".env" | ForEach-Object {
    if ($_ -match "^([^#][^=]+)=(.*)$") {
        $name = $matches[1].Trim()
        $value = $matches[2].Trim()
        [Environment]::SetEnvironmentVariable($name, $value, "Process")
    }
}

Write-Info "=== SMART CONTRACT DEPLOYMENT SUITE ==="
Write-Info "Network: $Network"
Write-Info "Verify: $Verify"
Write-Info "Dry Run: $DryRun"

# Set initial owner environment variable if provided
if ($Owner -ne "") {
    [Environment]::SetEnvironmentVariable("INITIAL_OWNER", $Owner, "Process")
    Write-Info "Initial Owner: $Owner"
}

# Function to check environment variable
function Test-EnvVar {
    param([string]$VarName)
    $value = [Environment]::GetEnvironmentVariable($VarName)
    if ([string]::IsNullOrEmpty($value)) {
        Write-Error "Environment variable $VarName is not set"
        Write-Info "Please check your .env file"
        exit 1
    }
    return $value
}

# Network-specific configuration
switch ($Network) {
    "sepolia" {
        $RpcUrl = Test-EnvVar "SEPOLIA_RPC_URL"
    }
    "base_sepolia" {
        $RpcUrl = Test-EnvVar "BASE_SEPOLIA_RPC_URL"
    }
    "mumbai" {
        $RpcUrl = Test-EnvVar "MUMBAI_RPC_URL"
        $ChainId = 80001
        $NetworkName = "Mumbai"
        $IsTestnet = $true
    }
    "eth" {
        $RpcUrl = Test-EnvVar "ETH_RPC_URL"
        $ChainId = 1
        $NetworkName = "Ethereum Mainnet"
        $IsTestnet = $false
        Write-Warning "Deploying to MAINNET! This will cost real ETH!"
        $confirm = Read-Host "Are you sure? (yes/no)"
        if ($confirm -ne "yes") {
            Write-Info "Deployment cancelled."
            exit 0
        }
    }
    "polygon" {
        $RpcUrl = Test-EnvVar "POLYGON_RPC_URL"
        $ChainId = 137
        $NetworkName = "Polygon"
        $IsTestnet = $false
        Write-Warning "Deploying to Polygon MAINNET! This will cost real MATIC!"
        $confirm = Read-Host "Are you sure? (yes/no)"
        if ($confirm -ne "yes") {
            Write-Info "Deployment cancelled."
            exit 0
        }
    }
    "arbitrum" {
        $RpcUrl = Test-EnvVar "ARBITRUM_RPC_URL"
        $ChainId = 42161
        $NetworkName = "Arbitrum One"
        $IsTestnet = $false
    }
    "optimism" {
        $RpcUrl = Test-EnvVar "OPTIMISM_RPC_URL"
        $ChainId = 10
        $NetworkName = "Optimism"
        $IsTestnet = $false
    }
    "base" {
        $RpcUrl = Test-EnvVar "BASE_RPC_URL"
        $ChainId = 8453
        $NetworkName = "Base"
        $IsTestnet = $false
    }
}

Write-Info "Building project..."
$buildResult = & forge build
if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed!"
    exit 1
}
Write-Success "Build successful!"

# Prepare forge command
$ForgeCmd = @(
    "forge", "script", 
    "script/DeployActivitiesPlatformCertificates.s.sol:DeployActivitiesPlatformCertificates",
    "--rpc-url", $RpcUrl
)

# Add broadcast flag if not dry run
if (-not $DryRun) {
    $ForgeCmd += "--broadcast"
}

# Add verification if requested
if ($Verify -and -not $DryRun) {
    $ForgeCmd += "--verify"
}

# Add verbosity
$ForgeCmd += "-vvvv"

Write-Info "Executing deployment..."
Write-Info "Command: $($ForgeCmd -join ' ')"

# Execute deployment
try {
    & $ForgeCmd[0] $ForgeCmd[1..($ForgeCmd.Length-1)]
    
    if ($LASTEXITCODE -eq 0) {
        if ($DryRun) {
            Write-Success "Dry run completed successfully!"
        } else {
            Write-Success "Deployment completed successfully!"
            Write-Info "Check the deployments/ directory for deployment artifacts"
            
            if ($Verify) {
                Write-Success "Contract verification initiated!"
            }
        }
    } else {
        Write-Error "Deployment failed!"
        exit 1
    }
} catch {
    Write-Error "Deployment failed: $_"
    exit 1
}

Write-Info "=== DEPLOYMENT COMPLETE ==="
