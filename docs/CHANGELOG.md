# Changelog

All notable changes to the stranger-social Docker deployment are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [5.0.2] - 2025-10-24

### Changed
- Increased Sidekiq ingress concurrency from 150 to 300 workers
- Scaled Sidekiq default queue from 5 to 20 workers
- Increased Puma web server from 2 to 4 workers with thread pool 5-10
- Increased streaming cluster from 1 to 2 processes
- Tuned PostgreSQL performance settings (max_connections=500, shared_buffers=512MB, effective_cache_size=1536MB, work_mem=1032kB)
- Configured Nginx with dynamic DNS resolution (resolver 127.0.0.11) to prevent stale upstream IPs

### Fixed
- Nginx 502 errors when web/streaming containers are recreated due to cached upstream IPs
- Nginx healthcheck failures by implementing dynamic upstream resolution

### Removed
- Removed deprecated `version` key from docker-compose.yml
- Removed sidekiq-ingress-extra service (consolidated into single ingress worker)

## [5.0.1] - 2025-10-23

### Added
- Comprehensive documentation reorganization with topic-specific guides
- Server migration guide for any deployment type (Kubernetes, VPS, bare metal, Docker)
- Pre-migration checklist and verification procedures
- Expanded troubleshooting guide with common issues and solutions
- Detailed maintenance schedule with daily/weekly/monthly/quarterly tasks
- Performance tuning guide for small, medium, and large instances
- Security best practices guide with encryption and incident response
- Architecture overview with system design documentation
- Updated GitHub Copilot instructions with research resources

### Changed
- Restructured Home.md as index with navigation to all topics
- Unified example domains to use stranger.social throughout documentation
- Improved Configuration Reference with complete environment variable tables
- Enhanced Operations guide with user management and database maintenance
- Reorganized documentation into focused category-based guides

### Fixed
- Documentation examples now consistently use stranger.social domain
- Nginx configuration references corrected to use stranger.social

## [5.0.0] - 2025-10-23

### Initial Implementation
- Docker Compose setup for Mastodon deployment
- Multi-service architecture (web, streaming, sidekiq, redis, postgres, nginx)
- SSL/TLS support with Certbot integration
- S3-compatible object storage support
- SMTP email configuration
- Database migration tools
- Basic documentation and setup guides

---

**Version History Note:** This deployment represents the 5th iteration of the stranger-social Mastodon server. Version 5.0.0 marks the transition to this Docker Compose-based deployment.
