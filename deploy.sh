#!/bin/bash

# ===== SMART CONTRACT DEPLOYMENT SUITE =====
# Secure deployment script for ActivitiesPlatformCertificates
# 
# Usage: ./deploy.sh [network] [options]
# Example: ./deploy.sh sepolia --verify

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
NETWORK="sepolia"
VERIFY=false
DRY_RUN=false
INITIAL_OWNER=""

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [network] [options]"
    echo ""
    echo "Networks:"
    echo "  sepolia     - Ethereum Sepolia testnet (default)"
    echo "  mumbai      - Polygon Mumbai testnet"
    echo "  eth         - Ethereum mainnet"
    echo "  polygon     - Polygon mainnet"
    echo "  arbitrum    - Arbitrum One"
    echo "  optimism    - Optimism"
    echo ""
    echo "Options:"
    echo "  --verify    - Verify contract on Etherscan after deployment"
    echo "  --dry-run   - Simulate deployment without broadcasting"
    echo "  --owner     - Set initial owner address (default: deployer)"
    echo "  --help      - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 sepolia --verify"
    echo "  $0 polygon --owner 0x1234... --verify"
    echo "  $0 mumbai --dry-run"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        sepolia|mumbai|eth|polygon|arbitrum|optimism)
            NETWORK="$1"
            shift
            ;;
        --verify)
            VERIFY=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --owner)
            INITIAL_OWNER="$2"
            shift 2
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Check if .env file exists
if [ ! -f .env ]; then
    print_warning ".env file not found. Creating from template..."
    cp .env.example .env
    print_info "Please edit .env file with your configuration and run again."
    exit 1
fi

# Load environment variables
source .env

print_info "=== SMART CONTRACT DEPLOYMENT SUITE ==="
print_info "Network: $NETWORK"
print_info "Verify: $VERIFY"
print_info "Dry Run: $DRY_RUN"

# Set initial owner environment variable if provided
if [ ! -z "$INITIAL_OWNER" ]; then
    export INITIAL_OWNER="$INITIAL_OWNER"
    print_info "Initial Owner: $INITIAL_OWNER"
fi

# Check if required environment variables are set
check_env_var() {
    local var_name=$1
    local var_value=${!var_name}
    
    if [ -z "$var_value" ]; then
        print_error "Environment variable $var_name is not set"
        print_info "Please check your .env file"
        exit 1
    fi
}

# Network-specific checks
case $NETWORK in
    sepolia)
        check_env_var "SEPOLIA_RPC_URL"
        RPC_URL=$SEPOLIA_RPC_URL
        ;;
    mumbai)
        check_env_var "MUMBAI_RPC_URL"
        RPC_URL=$MUMBAI_RPC_URL
        ;;
    eth)
        check_env_var "ETH_RPC_URL"
        RPC_URL=$ETH_RPC_URL
        print_warning "Deploying to MAINNET! This will cost real ETH!"
        read -p "Are you sure? (yes/no): " confirm
        if [ "$confirm" != "yes" ]; then
            print_info "Deployment cancelled."
            exit 0
        fi
        ;;
    polygon)
        check_env_var "POLYGON_RPC_URL"
        RPC_URL=$POLYGON_RPC_URL
        print_warning "Deploying to Polygon MAINNET! This will cost real MATIC!"
        read -p "Are you sure? (yes/no): " confirm
        if [ "$confirm" != "yes" ]; then
            print_info "Deployment cancelled."
            exit 0
        fi
        ;;
    arbitrum)
        check_env_var "ARBITRUM_RPC_URL"
        RPC_URL=$ARBITRUM_RPC_URL
        ;;
    optimism)
        check_env_var "OPTIMISM_RPC_URL"
        RPC_URL=$OPTIMISM_RPC_URL
        ;;
esac

# Build the project
print_info "Building project..."
forge build

if [ $? -ne 0 ]; then
    print_error "Build failed!"
    exit 1
fi

print_success "Build successful!"

# Prepare forge command
FORGE_CMD="forge script script/DeployActivitiesPlatformCertificates.s.sol:DeployActivitiesPlatformCertificates"
FORGE_CMD="$FORGE_CMD --rpc-url $RPC_URL"

# Add broadcast flag if not dry run
if [ "$DRY_RUN" = false ]; then
    FORGE_CMD="$FORGE_CMD --broadcast"
fi

# Add verification if requested
if [ "$VERIFY" = true ] && [ "$DRY_RUN" = false ]; then
    FORGE_CMD="$FORGE_CMD --verify"
fi

# Add verbosity
FORGE_CMD="$FORGE_CMD -vvvv"

print_info "Executing deployment..."
print_info "Command: $FORGE_CMD"

# Execute deployment
eval $FORGE_CMD

if [ $? -eq 0 ]; then
    if [ "$DRY_RUN" = true ]; then
        print_success "Dry run completed successfully!"
    else
        print_success "Deployment completed successfully!"
        print_info "Check the deployments/ directory for deployment artifacts"
        
        if [ "$VERIFY" = true ]; then
            print_success "Contract verification initiated!"
        fi
    fi
else
    print_error "Deployment failed!"
    exit 1
fi

print_info "=== DEPLOYMENT COMPLETE ==="
