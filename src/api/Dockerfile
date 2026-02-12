# Dockerfile for __PROJECT__ API
# API-only — frontend deploys separately via Azure Static Web Apps
#
# TODO: Replace this placeholder with your actual build steps.
# Examples below show a multi-stage .NET build, but adapt for your stack.

# Stage 1: Build
# TODO: Choose your SDK image (e.g., mcr.microsoft.com/dotnet/sdk:10.0, node:22, golang:1.23)
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /app

# TODO: Copy dependency manifests and restore
# COPY src/api/*.csproj ./
# RUN dotnet restore

# TODO: Copy source code and build
# COPY src/api/ ./
# RUN dotnet publish -c Release -o /app/publish --self-contained false

# Stage 2: Runtime
# TODO: Choose your runtime image (e.g., mcr.microsoft.com/dotnet/aspnet:10.0, node:22-slim)
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app

# Install curl for health checks
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*

# TODO: Copy built artifacts
# COPY --from=build /app/publish .

# Create non-root user
RUN useradd -r -s /bin/false appuser && \
    chown -R appuser:appuser /app

USER appuser

EXPOSE 8080

ENV ASPNETCORE_URLS=http://+:8080
ENV ASPNETCORE_ENVIRONMENT=Production

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# TODO: Set your entrypoint
# ENTRYPOINT ["dotnet", "__PROJECT__.Api.dll"]
CMD ["echo", "TODO: Replace with your application entrypoint"]
