# GitHub Actions Workflow Setup

Steps to enable CI/CD workflows. Each step includes both **Azure Portal** and **CLI** instructions — use whichever you prefer.

## Prerequisites

- Infrastructure already deployed (`./infra/scripts/deploy.sh dev`)
- For CLI steps: Azure CLI (`az login`) and GitHub CLI (`gh auth login`)

## 1. Register a Microsoft Entra ID Application (OIDC)

GitHub Actions authenticates to Azure via OIDC — no stored credentials. This step creates an identity that GitHub will impersonate.

### Portal

1. Go to **portal.azure.com** > **Microsoft Entra ID**
2. Click **App registrations** > **+ New registration**
3. Set **Name** to `__PROJECT__-github-actions`
4. Leave **Supported account types** as single tenant and **Redirect URI** blank
5. Click **Register**
6. On the overview page, note the **Application (client) ID** and **Directory (tenant) ID**

### CLI

```bash
az ad app create --display-name "__PROJECT__-github-actions"

# Note the appId from the output — this is your AZURE_CLIENT_ID
APP_ID=<appId from output>

az ad sp create --id $APP_ID

# Get your tenant and subscription IDs
az account show --query '{tenantId:tenantId, subscriptionId:id}' --output table
```

## 2. Add Federated Identity Credentials

Each credential maps a GitHub Actions trigger to this app identity. Azure checks the token's subject claim against these credentials before granting access.

You need two credentials: one for **pull requests** and one for **pushes to main** (which also covers manual `workflow_dispatch` runs from main).

### Portal

1. From the app registration, click **Certificates & secrets** > **Federated credentials** tab
2. Click **+ Add credential**
   - **Scenario:** GitHub Actions deploying Azure resources
   - **Organization:** `YOUR-ORG`
   - **Repository:** `YOUR-REPO`
   - **Entity type:** Pull request
   - **Name:** `github-pr`
   - Click **Add**
3. Click **+ Add credential** again
   - Same scenario, org, and repo
   - **Entity type:** Branch
   - **Branch:** `main`
   - **Name:** `github-main`
   - Click **Add**

### CLI

```bash
# Replace YOUR-ORG/YOUR-REPO with your actual repo path

# For pull requests
az ad app federated-credential create --id $APP_ID --parameters '{
  "name": "github-pr",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:YOUR-ORG/YOUR-REPO:pull_request",
  "audiences": ["api://AzureADTokenExchange"]
}'

# For push to main (also covers workflow_dispatch from main)
az ad app federated-credential create --id $APP_ID --parameters '{
  "name": "github-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:YOUR-ORG/YOUR-REPO:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}'
```

## 3. Grant Azure RBAC Permissions

The app registration is just an identity — it has zero permissions by default. Grant it:
- **Contributor** on the resource groups (create/update Container Apps, databases, etc.)
- **AcrPush** on the container registry (build and push Docker images)

### Portal

**3a. Contributor on `__PROJECT__-dev-rg`:**

1. Go to **Resource Groups** > **__PROJECT__-dev-rg**
2. Click **Access control (IAM)** > **+ Add** > **Add role assignment**
3. Search for **Contributor**, select it, click **Next**
4. Select "User, group, or service principal" > **+ Select members**
5. Search for `__PROJECT__-github-actions`, select it, click **Select**
6. Click **Review + assign**

**3b. Contributor on `__PROJECT__-shared-rg`:**

Repeat the same steps on the **__PROJECT__-shared-rg** resource group.

**3c. AcrPush on the container registry:**

1. Go to **Container registries** > **__PROJECT__acr**
2. Click **Access control (IAM)** > **+ Add** > **Add role assignment**
3. Search for **AcrPush** (not Contributor), select it, click **Next**
4. Select members > search `__PROJECT__-github-actions`, select, click **Select**
5. Click **Review + assign**

### CLI

```bash
SUBSCRIPTION_ID=$(az account show --query id --output tsv)

# Contributor on dev resource group
az role assignment create \
  --assignee $APP_ID \
  --role Contributor \
  --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/__PROJECT__-dev-rg

# Contributor on shared resource group
az role assignment create \
  --assignee $APP_ID \
  --role Contributor \
  --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/__PROJECT__-shared-rg

# AcrPush on the container registry
ACR_ID=$(az acr show --name __PROJECT__acr --query id --output tsv)
az role assignment create \
  --assignee $APP_ID \
  --role AcrPush \
  --scope $ACR_ID
```

## 4. Get SWA Deployment Token

Static Web Apps uses a separate deployment token (not OIDC) for frontend deploys.

### Portal

1. Go to **Static Web Apps** > **__PROJECT__-web-dev**
2. Click **Manage deployment token** in the top toolbar
3. Copy the token value

### CLI

```bash
az staticwebapp secrets list \
  --name __PROJECT__-web-dev \
  --resource-group __PROJECT__-dev-rg \
  --query properties.apiKey \
  --output tsv
```

## 5. Add GitHub Secrets

Store all collected values as encrypted secrets in the GitHub repo.

### Portal (GitHub)

1. Go to your repo on GitHub
2. **Settings** > **Secrets and variables** > **Actions**
3. Click **New repository secret** for each:

| Secret | Value |
|--------|-------|
| `AZURE_CLIENT_ID` | Application (client) ID from Step 1 |
| `AZURE_TENANT_ID` | Directory (tenant) ID from Step 1 |
| `AZURE_SUBSCRIPTION_ID` | Your subscription ID (portal: **Subscriptions** page) |
| `SQL_ADMIN_LOGIN` | A username you choose |
| `SQL_ADMIN_PASSWORD` | A strong password you choose |
| `AZURE_STATIC_WEB_APPS_API_TOKEN` | Token from Step 4 |

### CLI

```bash
gh secret set AZURE_CLIENT_ID --body "<appId>"
gh secret set AZURE_TENANT_ID --body "<tenantId>"
gh secret set AZURE_SUBSCRIPTION_ID --body "<subscriptionId>"
gh secret set SQL_ADMIN_LOGIN --body "<your-sql-admin-username>"
gh secret set SQL_ADMIN_PASSWORD --body "<your-sql-admin-password>"
gh secret set AZURE_STATIC_WEB_APPS_API_TOKEN --body "<token>"
```

## 6. Merge Workflows to Main

Workflow files in `.github/workflows/` must be on the default branch (main) for triggers to work. Merge the branch containing these files to main.

## How It Works

```
GitHub Actions trigger fires
  > GitHub mints an OIDC token (e.g. "I am repo:your-org/your-repo, trigger: pull_request")
  > Azure checks: does the app have a federated credential matching this subject?
  > Yes > Azure issues a short-lived access token
  > Workflow uses that token to push images, deploy infra, deploy apps
```

No long-lived passwords are stored in GitHub for Azure access. The only actual secret is the SWA deployment token (SWA doesn't support OIDC deployment yet).

## Workflow Overview

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `pr.yml` | Pull request | CI + deploy API to dev + SWA preview |
| `deploy-dev.yml` | Push to main, manual | Deploy API/web to dev |
| `deploy-infra.yml` | Manual, called by other workflows | Bicep infrastructure deployment |
| `deploy-api.yml` | Called by orchestrators | Docker build + Container App deploy |
| `deploy-web.yml` | Called by orchestrators | Frontend build + SWA deploy |

## Secrets Summary

| Secret | Required By | Source |
|--------|-------------|--------|
| `AZURE_CLIENT_ID` | All deploy workflows | Entra ID app registration |
| `AZURE_TENANT_ID` | All deploy workflows | Entra ID or `az account show` |
| `AZURE_SUBSCRIPTION_ID` | All deploy workflows | Subscriptions page or `az account show` |
| `SQL_ADMIN_LOGIN` | deploy-infra.yml | You choose |
| `SQL_ADMIN_PASSWORD` | deploy-infra.yml | You choose |
| `AZURE_STATIC_WEB_APPS_API_TOKEN` | deploy-web.yml | Azure portal or CLI |

## Troubleshooting

**OIDC login fails with "AADSTS70021"**
The federated credential subject doesn't match. Check that the credential matches the trigger type (pull_request vs ref:refs/heads/main).

**ACR build fails with 403**
The service principal needs AcrPush on the registry, not just Contributor on the resource group.

**SWA deploy fails with "No deployment token"**
The `AZURE_STATIC_WEB_APPS_API_TOKEN` secret is missing or expired. Regenerate from the Azure portal (Static Web Apps > Manage deployment token).

**Health check fails after Container App update**
Check container logs:
```bash
az containerapp logs show \
  --name __PROJECT__-app-dev \
  --resource-group __PROJECT__-dev-rg \
  --follow
```
