# Mastodon Docker Deployment

Production-ready Docker Compose setup for running Mastodon in production on any cloud provider or on-premises server.

## Features

- Complete production setup (web, streaming, sidekiq, nginx, postgres, redis)
- Security-first: SSL/TLS, env-based secrets, `.env.example` provided
- S3-compatible storage support (AWS S3, Linode Objects, MinIO, etc.)
- Health checks and logging
- Comprehensive Wiki documentation (synced from `docs/`)
- Works on any Linux host or cloud provider

## Quick Start

```bash
# Clone repository
git clone <your-repo-url>
cd mastodon-docker

# Configure environment
cp .env.example .env
nano .env  # Edit with your settings

# Start services
docker compose up -d

# Check status
docker compose ps
```

## Documentation

Complete documentation lives in the Wiki and is auto-synced from `docs/`.

- docs/Home.md (synced to Wiki Home)
- docs/MCP.md (using GitHub MCP with this repo)

## Project Structure

```
.
├── docker-compose.yml          # Main service definitions
├── .env.example                # Environment template (no secrets)
├── nginx/                      # Nginx reverse proxy config
│   ├── nginx.conf
│   └── conf.d/
│       └── default.conf
├── docs/                       # Documentation (synced to Wiki)
│   ├── Home.md
│   └── MCP.md
└── .github/
      └── workflows/
            └── sync-wiki.yml       # Auto-sync docs to Wiki
```

## Key Commands

```bash
# Start all services
docker compose up -d

# View logs
docker compose logs -f web

# Create admin user
docker exec mastodon-web bin/tootctl accounts create admin \
   --email=admin@example.com --confirmed --role=Admin

# Database backup
docker exec mastodon-postgres pg_dump -U mastodon mastodon_production > backup.sql

# Restart services
docker compose restart

# Stop services
docker compose down
```

## Security Notes

- Never commit `.env` files to version control (protected by `.gitignore`)
- Use strong, unique passwords; rotate secrets periodically
- Keep SSL certificates and Docker images up to date
- Enable `AUTHORIZED_FETCH` to reduce scraping

## Wiki Sync

This repo includes a GitHub Action that syncs `docs/` to the GitHub Wiki on pushes to `main` that change files under `docs/**`.

- Ensure the Wiki feature is enabled in repo settings
- The workflow uses `GITHUB_TOKEN` with `contents: write` permissions

## Support

- Mastodon docs: https://docs.joinmastodon.org/
- Docker Compose: https://docs.docker.com/compose/
- GitHub Wiki: View in this repo's Wiki tab
# Mastodon Docker Setup - stranger.social

This directory contains a complete Docker Compose setup for migrating the Stranger Social Mastodon instance from Kubernetes to Docker.

## Documentation

For complete setup, migration, and troubleshooting guides, see the [GitHub Wiki](../../wiki) (synced from `docs/`):
- **[Home](../../wiki/Home)** — Quick start and deployment guides
- **[MCP Usage](../../wiki/MCP)** — Using GitHub MCP with this repository

## Support

- Mastodon documentation: https://docs.joinmastodon.org/
- Docker Compose: https://docs.docker.com/compose/
- Issues or questions: Open an issue in this repository

---

**Note:** This repository is provider-agnostic and supports deployment on any cloud provider or on-premises infrastructure. Customize `.env` and deployment paths for your environment.
