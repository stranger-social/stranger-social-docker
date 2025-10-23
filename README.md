# Mastodon Docker Deployment

Production-ready Docker Compose setup for running Mastodon on any cloud provider or on-premises infrastructure.

**Version:** 5.0.1 | **Status:** Stable | **Last Updated:** October 23, 2025

## Overview

This is a provider-agnostic Docker Compose deployment for Mastodon featuring:

- ✅ Complete production setup (web, streaming, sidekiq, nginx, postgres, redis)
- ✅ Security-first architecture (SSL/TLS, environment-based secrets, no hardcoded credentials)
- ✅ S3-compatible storage (AWS S3, Linode Objects, MinIO, etc.)
- ✅ Health checks and comprehensive logging
- ✅ Extensive documentation (auto-synced to GitHub Wiki)
- ✅ Works on any Linux host or cloud provider

## Quick Start

```bash
# Clone repository
git clone https://github.com/stranger-social/mastodon-docker
cd mastodon-docker

# Configure environment
cp .env.example .env
nano .env  # Edit with your settings

# Start services
docker compose up -d

# Check status
docker compose ps
```

## 📚 Documentation

Complete documentation lives in `docs/` (auto-synced to [GitHub Wiki](../../wiki)):

### Getting Started
- **[Installation Guide](docs/Installation.md)** - Prerequisites and step-by-step setup
- **[Configuration Reference](docs/Configuration.md)** - Environment variables and ports

### Operations & Maintenance
- **[Common Operations](docs/Operations.md)** - User management, backups, database maintenance
- **[Troubleshooting Guide](docs/Troubleshooting.md)** - Common issues and solutions
- **[Maintenance Schedule](docs/Maintenance.md)** - Daily/weekly/monthly/quarterly tasks

### Advanced Topics
- **[Server Migration Guide](docs/Kubernetes-Migration.md)** - Migrate from any deployment
- **[Performance Tuning](docs/Performance.md)** - Optimize for your instance size
- **[Security Guide](docs/Security.md)** - Best practices and encryption

### Reference
- **[Architecture Overview](docs/Architecture.md)** - System design and data flow
- **[Changelog](docs/CHANGELOG.md)** - Version history and updates
- **[MCP Integration](docs/MCP.md)** - GitHub Model Context Protocol setup

## Project Structure

```
.
├── docker-compose.yml              # Service definitions
├── .env.example                    # Configuration template
├── nginx/                          # Reverse proxy configuration
│   ├── nginx.conf
│   └── conf.d/default.conf
├── certbot/                        # SSL certificate structure
│   ├── live/
│   ├── conf/
│   └── www/
├── docs/                           # Documentation (synced to Wiki)
│   ├── Home.md
│   ├── Installation.md
│   ├── Configuration.md
│   ├── Operations.md
│   ├── Troubleshooting.md
│   ├── Maintenance.md
│   ├── Kubernetes-Migration.md
│   ├── Performance.md
│   ├── Security.md
│   ├── Architecture.md
│   ├── CHANGELOG.md
│   └── MCP.md
├── .github/
│   ├── copilot-instructions.md
│   └── workflows/
│       ├── sync-wiki.yml
│       └── secret-scan.yml
└── mastodon.service                # Systemd unit file
```

## Common Commands

```bash
# Start all services
docker compose up -d

# View logs
docker compose logs -f web

# Create admin user
docker exec mastodon-web bin/tootctl accounts create username \
  --email=user@stranger.social --confirmed --role=Admin

# Database backup
docker exec mastodon-postgres pg_dump -U mastodon mastodon_production | gzip > backup.sql.gz

# Restart services
docker compose restart

# Stop services
docker compose down
```

## Security

- 🔒 Never commit `.env` files (protected by `.gitignore`)
- 🔒 Use strong, unique passwords; rotate secrets periodically
- 🔒 Keep SSL certificates current and Docker images up-to-date
- 🔒 Enable `AUTHORIZED_FETCH` to reduce unauthorized scraping
- 🔒 See [Security Guide](docs/Security.md) for detailed best practices

## GitHub Wiki Sync

Documentation in `docs/` is automatically synced to the [GitHub Wiki](../../wiki) via GitHub Actions:

- Wiki feature must be enabled in repository settings
- Workflow pushes changes from `docs/**` to Wiki on each push to main
- Uses `GITHUB_TOKEN` with appropriate permissions

## Support & Resources

- **Mastodon Documentation:** https://docs.joinmastodon.org/
- **Docker Compose Docs:** https://docs.docker.com/compose/
- **GitHub Issues:** [Open an issue](../../issues) for problems
- **GitHub Wiki:** [Full documentation](../../wiki)

## Version History

- **5.0.1** (Oct 23, 2025) - Documentation reorganization, migration guides, security updates
- **5.0.0** (Oct 23, 2025) - Initial Docker Compose implementation

See [CHANGELOG](docs/CHANGELOG.md) for detailed history.

---

**Note:** This repository is provider-agnostic and works on AWS, DigitalOcean, Linode, Azure, GCP, self-hosted, and any Linux infrastructure. Customize `.env` and deployment configuration for your environment.
