# ===== CONTRACT VERIFICATION SCRIPT =====
# Post-deployment verification for ActivitiesPlatformCertificates
# 
# Usage: .\verify.ps1 [contract_address] [network]
# Example: .\verify.ps1 0x1234... sepolia

param(
    [Parameter(Mandatory=$true)]
    [string]$ContractAddress,
    [string]$Network = "sepolia",
    [switch]$Help
)

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

if ($Help) {
    Write-Host "Usage: .\verify.ps1 [contract_address] [network]"
    Write-Host ""
    Write-Host "Parameters:"
    Write-Host "  contract_address - Address of deployed contract (required)"
    Write-Host "  network         - Network name (default: sepolia)"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\verify.ps1 0x1234567890123456789012345678901234567890 sepolia"
    Write-Host "  .\verify.ps1 0x1234567890123456789012345678901234567890 polygon"
    exit 0
}

# Load environment variables
if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match "^([^#][^=]+)=(.*)$") {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            [Environment]::SetEnvironmentVariable($name, $value, "Process")
        }
    }
}

# Get RPC URL for network
switch ($Network) {
    "sepolia" { $RpcUrl = [Environment]::GetEnvironmentVariable("SEPOLIA_RPC_URL") }
    "base_sepolia" { $RpcUrl = [Environment]::GetEnvironmentVariable("BASE_SEPOLIA_RPC_URL") }
    "mumbai" { $RpcUrl = [Environment]::GetEnvironmentVariable("MUMBAI_RPC_URL") }
    "eth" { $RpcUrl = [Environment]::GetEnvironmentVariable("ETH_RPC_URL") }
    "polygon" { $RpcUrl = [Environment]::GetEnvironmentVariable("POLYGON_RPC_URL") }
    "arbitrum" { $RpcUrl = [Environment]::GetEnvironmentVariable("ARBITRUM_RPC_URL") }
    "optimism" { $RpcUrl = [Environment]::GetEnvironmentVariable("OPTIMISM_RPC_URL") }
    "base" { $RpcUrl = [Environment]::GetEnvironmentVariable("BASE_RPC_URL") }
    default {
        Write-Error "Unknown network: $Network"
        exit 1
    }
}

if ([string]::IsNullOrEmpty($RpcUrl)) {
    Write-Error "RPC URL not found for network: $Network"
    Write-Info "Please check your .env file"
    exit 1
}

Write-Info "=== CONTRACT VERIFICATION ==="
Write-Info "Contract: $ContractAddress"
Write-Info "Network: $Network"
Write-Info "RPC URL: $RpcUrl"

# Test 1: Check if contract exists
Write-Info "Testing contract existence..."
try {
    $codeSize = & cast code $ContractAddress --rpc-url $RpcUrl
    if ($codeSize -eq "0x") {
        Write-Error "No contract found at address $ContractAddress"
        exit 1
    }
    Write-Success "Contract exists at address"
} catch {
    Write-Error "Failed to check contract existence: $_"
    exit 1
}

# Test 2: Check contract name
Write-Info "Checking contract name..."
try {
    $name = & cast call $ContractAddress "name()" --rpc-url $RpcUrl
    $decodedName = & cast --to-ascii $name
    Write-Success "Contract name: $decodedName"
} catch {
    Write-Error "Failed to get contract name: $_"
}

# Test 3: Check contract symbol
Write-Info "Checking contract symbol..."
try {
    $symbol = & cast call $ContractAddress "symbol()" --rpc-url $RpcUrl
    $decodedSymbol = & cast --to-ascii $symbol
    Write-Success "Contract symbol: $decodedSymbol"
} catch {
    Write-Error "Failed to get contract symbol: $_"
}

# Test 4: Check owner
Write-Info "Checking contract owner..."
try {
    $owner = & cast call $ContractAddress "owner()" --rpc-url $RpcUrl
    $ownerAddress = & cast --to-checksum-address $owner
    Write-Success "Contract owner: $ownerAddress"
} catch {
    Write-Error "Failed to get contract owner: $_"
}

# Test 5: Check next token ID
Write-Info "Checking next token ID..."
try {
    $nextTokenId = & cast call $ContractAddress "getNextTokenId()" --rpc-url $RpcUrl
    $tokenId = & cast --to-dec $nextTokenId
    Write-Success "Next token ID: $tokenId"
} catch {
    Write-Error "Failed to get next token ID: $_"
}

# Test 6: Check supports interface (ERC721)
Write-Info "Checking ERC721 interface support..."
try {
    $erc721InterfaceId = "0x80ac58cd"
    $supportsERC721 = & cast call $ContractAddress "supportsInterface(bytes4)" $erc721InterfaceId --rpc-url $RpcUrl
    if ($supportsERC721 -eq "0x0000000000000000000000000000000000000000000000000000000000000001") {
        Write-Success "ERC721 interface supported"
    } else {
        Write-Error "ERC721 interface not supported"
    }
} catch {
    Write-Error "Failed to check ERC721 interface: $_"
}

Write-Info "=== VERIFICATION COMPLETE ==="
