# Agents Guide

This repository contains Helm charts for deploying Ontopic products to Kubernetes.

## Repository Structure

```
charts/
  ontopic-server/    # Helm chart for Ontopic Server (SPARQL and Semantic SQL endpoints)
  ontopic-suite/    # Helm chart for Ontopic Suite (includes ontopic-server as subchart)
docs/                # Documentation for deployment
samples/             # Sample configurations (e.g., k3d cluster)
```

## Charts

- **ontopic-server**: Standalone Ontopic Server deployment
- **ontopic-suite**: Full Ontopic Suite deployment with optional PostgreSQL and ontopic-server dependencies

## Key Files

- `charts/*/Chart.yaml` - Chart metadata and dependencies
- `charts/*/values.yaml` - Default configuration values
- `charts/*/templates/` - Kubernetes manifest templates
- `values.example.yaml` - Example values file for reference

## Development Guidelines

- Follow Helm best practices for chart development
- Chart versions follow Semantic Versioning
- Update both `version` and `appVersion` in Chart.yaml when making changes
- Test charts locally with k3d or Docker Desktop before pushing
- Keep subchart dependencies in sync between ontopic-suite and ontopic-server

## Common Tasks

- **Lint charts**: `helm lint charts/<chart-name>`
- **Template locally**: `helm template charts/<chart-name>`
- **Update dependencies**: `helm dependency update charts/ontopic-suite`
