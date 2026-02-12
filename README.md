# azure-swa-ca-template

Template repository for fullstack apps deployed to Azure: frontend on **Static Web Apps**, backend API on **Container Apps**, **SQL Server** database, **Bicep** infrastructure-as-code, and **GitHub Actions** CI/CD.

## Quick Start

1. **Use this template** — click "Use this template" on GitHub, or:
   ```bash
   gh repo create your-org/your-project --template ABladeLabs/azure-swa-ca-template --public --clone
   cd your-project
   ```

2. **Initialize** — replace placeholders with your project name:
   ```bash
   chmod +x init.sh
   ./init.sh myproject eastus2
   ```

3. **Add your code** — build your API and frontend in the placeholder directories.

## Architecture

```
┌──────────────┐     ┌──────────────────┐     ┌──────────────┐
│  Static Web  │────>│  Container App   │────>│  Azure SQL   │
│    Apps      │     │  (.NET / Node /  │     │  Database    │
│  (Frontend)  │     │   any runtime)   │     │              │
└──────────────┘     └──────────────────┘     └──────────────┘
                            │
                     ┌──────┴──────┐
                     │    ACR      │
                     │  (Shared)   │
                     └─────────────┘
```

### Azure Resources

| Resource | Shared | Per-Environment |
|----------|--------|-----------------|
| Container Registry (ACR) | Yes | |
| Container App + Environment | | Yes |
| Static Web App | | Yes |
| SQL Server + Database | | Yes |
| Managed Identity | | Yes |

### Environments

- **dev** — auto-deploys on push to main
- **staging** — manual trigger
- **prod** — manual trigger

## Project Structure

```
├── init.sh                  # Template initialization script
├── Makefile                 # Dev commands (TODO: fill in your build steps)
├── docker-compose.yml       # Local SQL Server
├── src/
│   ├── api/                 # Backend API
│   │   └── Dockerfile       # TODO: customize for your runtime
│   └── web/                 # Frontend SPA
├── infra/
│   ├── bicep/               # Azure infrastructure (Bicep)
│   │   ├── main.bicep       # Environment orchestration
│   │   ├── shared.bicep     # Shared resources (ACR)
│   │   ├── modules/         # Resource modules
│   │   └── parameters.*     # Per-environment params
│   └── scripts/
│       ├── deploy.sh        # Deploy infrastructure
│       └── teardown.sh      # Delete infrastructure
├── .github/workflows/
│   ├── deploy-dev.yml       # Push to main → deploy dev
│   ├── deploy-staging.yml   # Manual → deploy staging
│   ├── deploy-prod.yml      # Manual → deploy prod
│   ├── pr.yml               # PR CI + SWA preview
│   ├── deploy-infra.yml     # Reusable: Bicep
│   ├── deploy-api.yml       # Reusable: Docker + Container App
│   └── deploy-web.yml       # Reusable: SWA
└── docs/
    └── workflow-setup.md    # Azure OIDC + secrets guide
```

## Customization Checklist

After running `init.sh`, complete these TODOs:

### Backend API
- [ ] Add your application code to `src/api/`
- [ ] Update `src/api/Dockerfile` with your build and runtime steps
- [ ] Uncomment the `app` service in `docker-compose.yml`

### Frontend
- [ ] Add your frontend project to `src/web/`
- [ ] Update `.github/workflows/deploy-web.yml` with your build steps
- [ ] Update `app_location` and `output_location` in the SWA deploy step

### CI/CD
- [ ] Update `.github/workflows/pr.yml` with your build/test/lint steps
- [ ] Update `Makefile` targets with your commands

### Infrastructure
- [ ] Update `infra/scripts/deploy.sh` with your Azure subscription ID
- [ ] Follow `docs/workflow-setup.md` to configure OIDC + GitHub secrets
- [ ] Deploy: `./infra/scripts/deploy.sh dev`

## Resource Naming Convention

| Resource | Pattern | Example |
|----------|---------|---------|
| Resource Group (shared) | `{project}-shared-rg` | `myapp-shared-rg` |
| Resource Group (env) | `{project}-{env}-rg` | `myapp-dev-rg` |
| ACR | `{project}acr` | `myappacr` |
| Container App | `{project}-app-{env}` | `myapp-app-dev` |
| Container App Env | `{project}-cae-{env}` | `myapp-cae-dev` |
| SQL Server | `{project}-sql-{env}` | `myapp-sql-dev` |
| SQL Database | `{project}-db-{env}` | `myapp-db-dev` |
| Managed Identity | `id-{project}-{env}` | `id-myapp-dev` |
| Static Web App | `{project}-web-{env}` | `myapp-web-dev` |

## Commands

```bash
make help           # Show all commands
make dev            # Run API + frontend (TODO: configure)
make docker-up      # Start SQL Server in Docker
make docker-down    # Stop Docker containers
make docker-build   # Build API Docker image
```

## Estimated Cost

Dev environment: ~$10-15/month (SQL Basic tier + Container App scales to zero)

## License

MIT
