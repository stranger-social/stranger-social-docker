# Changelog

All notable changes to the stranger-social Docker deployment are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [5.1.2] - 2025-12-14

### Changed
- Migrated PostgreSQL data from network mount to local SSD at `/var/lib/postgresql/data` for improved performance and reliability
- Increased database connection pools across all services:
  - Web: 30 → 60 connections (DB_POOL=60)
  - Sidekiq default: added DB_POOL=15
  - Sidekiq ingress: added DB_POOL=30
  - Sidekiq push-pull workers: added DB_POOL=80 each
- Total connection pool capacity: 265 connections (vs max_connections=225)
- Updated documentation to reflect current database configuration and connection pool sizing

### Fixed
- Eliminated connection pool timeout errors under high load

### Added
- Documentation for checking duplicate indexes in Performance guide
- Database connection monitoring to daily maintenance checklist
- Duplicate index check to monthly maintenance tasks
- Notes on bind mount vs Docker volume for postgres storage

## [5.1.1] - 2025-12-11

### Fixed
- **Critical:** Database connection pool exhaustion causing nginx timeouts and service unavailability
  - Increased `DB_POOL` from default (5) to 30 connections in docker-compose.yml
  - Mismatch between Puma threads (20 max) and DB connections (5) was causing request queuing
  - Adjusted proxy timeouts from 60s to 30s for faster failure detection
  - Added comprehensive monitoring and diagnostics guide (docs/Monitoring-and-Diagnostics.md)
- Added rate limiting to nginx to prevent abuse: 30 req/sec per IP
- Optimized nginx worker connection limits from 768 to 2048 per worker
- Added keepalive_requests limit to prevent connection reuse exhaustion
- Implemented per-IP connection limiting (max 50 concurrent per IP)
- Reduced nginx client timeouts for faster stalled connection cleanup
- Fixed HTTP/2 directive deprecation warning in nginx configuration

### Added
- New deployment guide: DEPLOYMENT-FIX-GUIDE.md with step-by-step instructions
- New monitoring guide: docs/Monitoring-and-Diagnostics.md with comprehensive health checks

## [5.1.0] - 2025-12-11

### Added
- Clarified Mastodon 4.5.x minimums (PostgreSQL 14+, Redis 7+, Node 20.19+ for asset builds) in deployment notes

### Changed
- Upgraded Mastodon images (web, streaming, Sidekiq) to v4.5.3 to pick up security and bug fixes
- Updated Sidekiq health checks to match Sidekiq 8 process names from Mastodon 4.5
- Refreshed documentation and key generation commands to use the 4.5.3 container tag
- Bumped deployment version metadata to 5.1.0

## [5.0.3] - 2025-10-30

### Added
- Integrated automated and manual PostgreSQL backup service using prodrigestivill/postgres-backup-local
- Created docs/Backup.md with detailed backup and restore instructions
- Updated docker-compose.yml to include postgres-backup service
- Added backup retention and restore procedures to documentation

### Changed
- README and documentation now reference backup service and procedures

### Fixed
- Project structure and documentation now consistently include backup folder and instructions

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
