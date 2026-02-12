# Infrastructure

Azure infrastructure managed with Bicep. **Bicep is the single source of truth** for all Azure resources.

## Architecture

### Shared Resources (`{project}-shared-rg`)

Resources deployed once and reused across all environments:

- **Azure Container Registry**: `{project}acr` — stores container images promoted across environments

### Per-Environment Resources (`{project}-{env}-rg`)

- **Azure Container Apps**: Hosts API container
- **Azure Static Web Apps**: Hosts frontend SPA (Free tier)
- **Azure SQL Database**: Basic tier (5 DTU) for development
- **User-Assigned Managed Identity**: ACR pull access for the Container App

**Estimated monthly cost:** ~$10-15 (dev environment)

### Deployment Order

Both phases use subscription-level deployments (`az deployment sub create`). Bicep creates the resource groups — they are not created separately by scripts.

**Phase 1 — Shared infrastructure:**
1. **Resource group** — `{project}-shared-rg`
2. **registry** — Azure Container Registry

**Phase 2 — Environment infrastructure:**
1. **Resource group** — `{project}-{env}-rg`
2. **database** — Azure SQL (independent)
3. **staticWebApp** — SWA for frontend (independent)
4. **managedIdentity** — User-assigned identity (independent)
5. **acrRoleAssignment** — AcrPull role (depends on identity, deployed to shared RG)
6. **containerApp** — App + environment (depends on role assignment + database)

The environment deployment references the shared ACR cross-resource-group via Bicep's `existing` resource + `scope: resourceGroup(...)` pattern.

## Deployment

### Prerequisites

1. **Azure CLI**: Install from https://aka.ms/azure-cli
2. **Azure Subscription**: Active Azure subscription
3. **Permissions**: Contributor + User Access Administrator role on the subscription
4. **Secrets**: SQL admin credentials

### GitHub Actions (Recommended)

1. Configure GitHub Secrets (see `docs/workflow-setup.md`)
2. Trigger deployment via Actions tab

### Local Deployment

```bash
# Set required environment variables
export SQL_ADMIN_LOGIN="sqladmin"
export SQL_ADMIN_PASSWORD="YourSecurePassword123!"

# Login to Azure
az login

# Run deployment script (deploys shared + environment)
./infra/scripts/deploy.sh dev
```

#### What-if Mode

Preview changes without deploying:

```bash
./infra/scripts/deploy.sh dev --what-if
```

## Teardown

```bash
# Delete environment only (preserves shared ACR)
./infra/scripts/teardown.sh

# Delete environment AND shared resources (ACR)
./infra/scripts/teardown.sh --shared
```

## Bicep Structure

```
infra/bicep/
├── main.bicep                        # Environment orchestration (subscription-scoped)
├── shared.bicep                      # Shared infrastructure (subscription-scoped)
├── parameters.dev.bicepparam         # Dev environment parameters
├── parameters.staging.bicepparam     # Staging environment parameters
├── parameters.prod.bicepparam        # Production environment parameters
├── parameters.shared.bicepparam      # Shared infrastructure parameters
└── modules/                          # Resource modules
    ├── database.bicep                # Azure SQL Server and Database
    ├── registry.bicep                # Azure Container Registry
    ├── managed-identity.bicep        # User-assigned managed identity
    ├── acr-role-assignment.bicep     # AcrPull role assignment
    ├── container-app-env.bicep       # Container Apps Environment
    ├── container-app.bicep           # Container App
    └── static-web-app.bicep          # Azure Static Web Apps
```

Parameter files use `.bicepparam` format with `readEnvironmentVariable()` for secrets — no credentials are stored in source control.

## Modifying Infrastructure

1. Edit the Bicep files in `infra/bicep/modules/`
2. Verify compilation:
   ```bash
   az bicep build --file infra/bicep/shared.bicep
   az bicep build --file infra/bicep/main.bicep
   ```
3. Preview changes:
   ```bash
   ./infra/scripts/deploy.sh dev --what-if
   ```
4. Commit and deploy via GitHub Actions

## Troubleshooting

### Container App not starting

Check logs:
```bash
az containerapp logs show \
  --name {project}-app-dev \
  --resource-group {project}-dev-rg \
  --follow
```

### ACR pull authentication errors

Verify role assignment:
```bash
az role assignment list \
  --scope $(az acr show --name {project}acr --resource-group {project}-shared-rg --query id -o tsv) \
  --role AcrPull \
  --output table
```

## Cost Management

### Scale to Zero

The Container App is configured to scale to 0 replicas when idle.

### Manual Shutdown

```bash
az containerapp update \
  --name {project}-app-dev \
  --resource-group {project}-dev-rg \
  --min-replicas 0 \
  --max-replicas 0
```
