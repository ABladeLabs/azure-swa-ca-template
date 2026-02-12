#!/usr/bin/env bash
set -euo pipefail

# Template Initialization Script
#
# Replaces __PROJECT__ and __LOCATION__ placeholders in all files,
# renames files containing __PROJECT__, reinitializes git, and
# creates an initial commit.
#
# Usage: ./init.sh <project-name> [location]
#   project-name: lowercase alphanumeric + hyphens (e.g., myapp, my-project)
#   location:     Azure region (default: eastus2)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

if [ $# -eq 0 ]; then
  echo -e "${RED}Usage: $0 <project-name> [location]${NC}"
  echo ""
  echo "  project-name: lowercase alphanumeric + hyphens (e.g., myapp, my-project)"
  echo "  location:     Azure region (default: eastus2)"
  echo ""
  echo "Examples:"
  echo "  $0 myapp"
  echo "  $0 my-project westus2"
  exit 1
fi

PROJECT_NAME="$1"
LOCATION="${2:-eastus2}"

# Validate project name: lowercase alphanumeric + hyphens, no leading/trailing hyphens
if [[ ! "$PROJECT_NAME" =~ ^[a-z][a-z0-9-]*[a-z0-9]$ ]] && [[ ! "$PROJECT_NAME" =~ ^[a-z][a-z0-9]*$ ]]; then
  echo -e "${RED}Error: project name must be lowercase alphanumeric + hyphens (e.g., myapp, my-project)${NC}"
  echo "  - Must start with a letter"
  echo "  - Must end with a letter or number"
  echo "  - Only lowercase letters, numbers, and hyphens"
  exit 1
fi

# Derive PascalCase for C# namespaces (e.g., my-project -> MyProject)
PASCAL_CASE=$(echo "$PROJECT_NAME" | sed -E 's/(^|-)([a-z])/\U\2/g')

echo -e "${CYAN}Initializing project: ${GREEN}$PROJECT_NAME${NC}"
echo -e "${CYAN}Location: ${GREEN}$LOCATION${NC}"
echo -e "${CYAN}PascalCase: ${GREEN}$PASCAL_CASE${NC}"
echo ""

# Step 1: Replace __PROJECT__ and __LOCATION__ in file contents
echo -e "${YELLOW}Replacing placeholders in files...${NC}"
find . -type f \
  ! -path './.git/*' \
  ! -path './init.sh' \
  ! -name '*.png' \
  ! -name '*.jpg' \
  ! -name '*.ico' \
  ! -name '*.woff' \
  ! -name '*.woff2' \
  -print0 | while IFS= read -r -d '' file; do
    if grep -q '__PROJECT__\|__LOCATION__' "$file" 2>/dev/null; then
      sed -i "s/__PROJECT__/$PROJECT_NAME/g" "$file"
      sed -i "s/__LOCATION__/$LOCATION/g" "$file"
      echo "  Updated: $file"
    fi
  done

# Step 2: Rename files containing __PROJECT__
echo ""
echo -e "${YELLOW}Renaming files...${NC}"
find . -type f -name '*__PROJECT__*' ! -path './.git/*' -print0 | while IFS= read -r -d '' file; do
  dir=$(dirname "$file")
  base=$(basename "$file")
  newbase="${base//__PROJECT__/$PROJECT_NAME}"
  mv "$file" "$dir/$newbase"
  echo "  Renamed: $file -> $dir/$newbase"
done

# Step 3: Reinitialize git
echo ""
echo -e "${YELLOW}Reinitializing git...${NC}"
rm -rf .git
git init
git add -A
git commit -m "Initial commit from azure-swa-ca-template

Project: $PROJECT_NAME
Location: $LOCATION"

# Step 4: Clean up
rm -f init.sh
git add -A
git commit -m "Remove template init script"

# Done
echo ""
echo -e "${GREEN}Project initialized successfully!${NC}"
echo ""
echo -e "${CYAN}Next steps:${NC}"
echo "  1. Create your GitHub repo:"
echo "     gh repo create your-org/$PROJECT_NAME --public --source=. --push"
echo ""
echo "  2. Add your application code:"
echo "     - Backend API in src/api/ (update the Dockerfile)"
echo "     - Frontend in src/web/"
echo ""
echo "  3. Set up local development:"
echo "     - Start SQL Server: make docker-up"
echo "     - Update Makefile targets with your build commands"
echo ""
echo "  4. Set up Azure deployment:"
echo "     - Follow docs/workflow-setup.md for OIDC + secrets"
echo "     - Update infra/scripts/deploy.sh with your subscription ID"
echo "     - Deploy infra: ./infra/scripts/deploy.sh dev"
echo ""
echo "  5. Set up CI/CD:"
echo "     - Update .github/workflows/pr.yml with your build/test steps"
echo "     - Update .github/workflows/deploy-web.yml with your frontend build"
echo "     - Push to main to trigger deploy-dev.yml"
