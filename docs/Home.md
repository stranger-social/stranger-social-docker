# Mastodon Docker Deployment - Documentation Index

Welcome to the Mastodon Docker documentation. For complete details, see the individual guides below.

## 📚 Documentation by Topic

### Getting Started
- **[Installation Guide](Installation.md)** — Prerequisites, setup steps, security key generation
- **[Configuration Reference](Configuration.md)** — Environment variables, ports, Docker volumes

### Daily Operations
- **[Operations Guide](Operations.md)** — User management, backups, database maintenance, logging
- **[Maintenance Schedule](Maintenance.md)** — Daily/weekly/monthly/quarterly tasks with examples
- **[Troubleshooting Guide](Troubleshooting.md)** — Common issues and solutions


### Advanced Topics
- **[Server Migration Guide](Kubernetes-Migration.md)** — Migrate from any deployment (Kubernetes, Docker, etc.)
- **[Performance Tuning](Performance.md)** — Optimize for your instance size (small/medium/large)
- **[Security Guide](Security.md)** — Best practices, encryption, incident response, access control

### Reference
- **[Architecture Overview](Architecture.md)** — System design, services, data flow, scaling
- **[Changelog](CHANGELOG.md)** — Version history and updates
- **[GitHub MCP Guide](MCP.md)** — Using GitHub MCP to manage this repository

## Quick Links

| Task | Guide |
|------|-------|
| First-time setup | [Installation](Installation.md) |
| Fix a problem | [Troubleshooting](Troubleshooting.md) |
| Daily maintenance | [Operations](Operations.md) |
| Move from Kubernetes | [Migration Guide](Kubernetes-Migration.md) |
| Scale the instance | [Performance](Performance.md) |
| Secure the deployment | [Security](Security.md) |

## Project Overview

- **Version:** 5.0.1 (Stable)
- **Released:** October 23, 2025
- **Services:** Web (Puma), Streaming (Node.js), Sidekiq, PostgreSQL 15, Redis 7, Nginx
- **Storage:** S3-compatible (AWS, Linode Objects, MinIO) + Docker volumes
- **Provider-agnostic:** Works on AWS, DigitalOcean, Linode, Azure, GCP, self-hosted

## Support

- **Mastodon Docs:** https://docs.joinmastodon.org/
- **Docker Compose:** https://docs.docker.com/compose/
- **GitHub Issues:** Report problems in this repository
- **GitHub Releases:** https://github.com/mastodon/mastodon/releases

---

See [README.md](../README.md) for quick start instructions.
