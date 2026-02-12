#!/usr/bin/env bash
set -euo pipefail

# __PROJECT__ - Deploy Bicep infrastructure
# Usage: ./deploy.sh <environment> [--what-if]
#
# Two-phase subscription-level deployment:
#   1. Shared infrastructure (ACR) — creates __PROJECT__-shared-rg
#   2. Environment infrastructure  — creates __PROJECT__-{env}-rg
#
# Bicep is the single source of truth — resource groups are created
# by the templates, not by this script.
#
# Required environment variables:
#   SQL_ADMIN_LOGIN    — SQL Server admin username
#   SQL_ADMIN_PASSWORD — SQL Server admin password

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BICEP_DIR="$SCRIPT_DIR/../bicep"

if [ $# -eq 0 ]; then
  echo "Usage: $0 <environment> [--what-if]"
  echo "  environment: dev, staging, prod"
  echo ""
  echo "Required env vars: SQL_ADMIN_LOGIN, SQL_ADMIN_PASSWORD"
  exit 1
fi

ENVIRONMENT=$1
WHAT_IF_FLAG=""
if [ "${2:-}" == "--what-if" ]; then
  WHAT_IF_FLAG="--what-if"
fi

# Validate required environment variables (read by .bicepparam via readEnvironmentVariable)
: "${SQL_ADMIN_LOGIN:?Environment variable SQL_ADMIN_LOGIN is required}"
: "${SQL_ADMIN_PASSWORD:?Environment variable SQL_ADMIN_PASSWORD is required}"

# TODO: Set your Azure subscription ID
SUBSCRIPTION_ID="TODO-SET-YOUR-SUBSCRIPTION-ID"
LOCATION="__LOCATION__"

# Ensure we're deploying to the correct subscription
az account set --subscription "$SUBSCRIPTION_ID"

# Step 1: Deploy shared infrastructure (creates RG + ACR)
echo "==> Deploying shared infrastructure..."
az deployment sub create \
  --name "__PROJECT__-shared" \
  --location "$LOCATION" \
  --parameters "$BICEP_DIR/parameters.shared.bicepparam" \
  $WHAT_IF_FLAG

# Step 2: Deploy environment infrastructure (creates RG + all env resources)
echo "==> Deploying $ENVIRONMENT environment..."
az deployment sub create \
  --name "__PROJECT__-${ENVIRONMENT}" \
  --location "$LOCATION" \
  --parameters "$BICEP_DIR/parameters.${ENVIRONMENT}.bicepparam" \
  $WHAT_IF_FLAG
