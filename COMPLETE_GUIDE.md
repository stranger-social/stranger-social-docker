# Mastodon Kubernetes to Docker Migration - Complete Guide

**Status:** Ready for Deployment  
**Mastodon Version:** v4.4.8  
**Migration Date:** October 22, 2025  
**Instance:** stranger.social

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Files Provided](#files-provided)
5. [Quick Start](#quick-start)
6. [Detailed Setup](#detailed-setup)
7. [Configuration](#configuration)
8. [Deployment](#deployment)
9. [Verification](#verification)
10. [Maintenance](#maintenance)
11. [Troubleshooting](#troubleshooting)

## Overview

This migration converts your Mastodon instance from a Kubernetes deployment (bitnami/mastodon-4.2 helm chart) to a Docker Compose setup on a dedicated Linode machine.

### Key Points

- **Mastodon Version:** v4.4.8 (docker image: `ghcr.io/mastodon/mastodon:v4.4.8`)
- **Database:** PostgreSQL 15 (existing on Linode volume)
- **Storage:** 
  - PostgreSQL data: `/mnt/stranger_social_20251021_1400`
  - Media files: `/mnt/stranger_social_20251021_1400/mastodon-public-system`
  - S3 Bucket: `stranger-social-bucket` (Linode Objects, us-southeast-1)
- **Email:** SMTP via Gmail (smtp.gmail.com:587)
- **Domain:** stranger.social
- **Architecture:** Docker Compose with nginx reverse proxy

### Services

- **web:** Mastodon Rails application (Puma)
- **streaming:** WebSocket server for real-time updates (Node.js)
- **sidekiq:** Job queue processors (2 workers: service-queues, ingress-push-pull)
- **redis:** Cache and job queue
- **nginx:** Reverse proxy and web server

## Architecture

```
┌─────────────────────────────────────────┐
│         Internet (TLS/HTTPS)            │
This document has been deprecated.

Please see the docs in `docs/` (synced to the GitHub Wiki) for up-to-date, provider-agnostic deployment guidance.

- Start with: docs/Home.md
- GitHub MCP usage: docs/MCP.md

Note: This repository intentionally avoids storing provider-specific or migration-specific instructions in the root. All documentation now lives in the `docs/` folder for clarity and reuse.
psql -h localhost -U mastodon -d mastodon_production -c "SELECT count(*) FROM accounts;"

# Backup database (for safety)
pg_dump -h localhost -U mastodon mastodon_production > /tmp/mastodon-backup-$(date +%s).sql

# Password will be prompted
```

### Step 4: Extract Kubernetes Secrets

```bash
cd /opt/stranger-social-docker

# Ensure kubectl is configured
kubectl config current-context

# Extract secrets
./extract-k8s-secrets.sh

# This will create a temporary file with all secrets
# View the output and note the keys
```

### Step 5: Populate .env File

```bash
cd /opt/stranger-social-docker

# Open .env file
nano .env

# Replace all YOUR_*_HERE values with actual values from extract-k8s-secrets.sh

# Critical sections:
# - Database connection
# - Secret keys (SECRET_KEY_BASE, OTP_SECRET)
# - VAPID keys
# - Active Record Encryption keys
# - S3 credentials
# - SMTP credentials
# - Redis password

# Save and exit: Ctrl+X, Y, Enter

# Set secure permissions
chmod 600 .env

# Verify critical values are set
grep -E "SECRET_KEY_BASE|OTP_SECRET|VAPID_PRIVATE_KEY" .env | head -3
```

### Step 6: Set Up Directory Structure

```bash
cd /opt/stranger-social-docker

# Create directories
mkdir -p /mnt/stranger_social_20251021_1400/mastodon-public-system
mkdir -p storage
mkdir -p certbot/conf/live/stranger.social
mkdir -p certbot/www
mkdir -p nginx/conf.d

# Set permissions
sudo chown 991:991 /mnt/stranger_social_20251021_1400/mastodon-public-system
chmod 755 storage certbot/www

# Verify
ls -la /mnt/stranger_social_20251021_1400/mastodon-public-system
```

### Step 7: Set Up SSL/TLS Certificates

#### Option A: Let's Encrypt (Recommended)

```bash
# Install certbot (already done above)

# Generate certificate
sudo certbot certonly --standalone \
  -d stranger.social \
  -d www.stranger.social \
  --non-interactive \
  --agree-tos \
  -m admin@stranger.social

# Copy to Docker config directory
sudo cp /etc/letsencrypt/live/stranger.social/fullchain.pem \
  /opt/stranger-social-docker/certbot/conf/live/stranger.social/
sudo cp /etc/letsencrypt/live/stranger.social/privkey.pem \
  /opt/stranger-social-docker/certbot/conf/live/stranger.social/

# Set permissions
sudo chown 1000:1000 -R /opt/stranger-social-docker/certbot/conf

# Verify
ls -la /opt/stranger-social-docker/certbot/conf/live/stranger.social/
```

#### Option B: Existing Certificates

```bash
# Copy from Kubernetes setup or existing location
sudo cp /path/to/fullchain.pem \
  /opt/stranger-social-docker/certbot/conf/live/stranger.social/
sudo cp /path/to/privkey.pem \
  /opt/stranger-social-docker/certbot/conf/live/stranger.social/

sudo chown 1000:1000 -R /opt/stranger-social-docker/certbot/conf

# Verify expiration
openssl x509 -in /opt/stranger-social-docker/certbot/conf/live/stranger.social/fullchain.pem \
  -noout -dates
```

### Step 8: Verify Configuration

```bash
cd /opt/stranger-social-docker

# Check syntax
docker-compose config

# Should output the complete configuration without errors
```

## Configuration

### Environment Variables

The `.env` file contains all configuration. Key variables:

```bash
# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=mastodon_production
DB_USER=mastodon
DB_PASSWORD=timelord42

# Secrets (MUST BE SET)
SECRET_KEY_BASE=...
OTP_SECRET=...
VAPID_PRIVATE_KEY=...
VAPID_PUBLIC_KEY=...

# S3/Linode Objects
S3_BUCKET=stranger-social-bucket
S3_REGION=us-southeast-1
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...

# SMTP
SMTP_SERVER=smtp.gmail.com
SMTP_LOGIN=admin@stranger.social
SMTP_PASSWORD=xtohkuzyoyrkrosj

# Domain
LOCAL_DOMAIN=stranger.social
```

### Network Configuration

nginx handles:
- HTTP to HTTPS redirect
- TLS termination
- Reverse proxy to web server
- WebSocket proxy to streaming server
- Static file serving

### Storage

- **PostgreSQL:** On Linode volume (`/mnt/stranger_social_20251021_1400`)
- **Media files:** Also on Linode volume (or S3)
- **Redis:** In-memory (ephemeral)
- **Application:** Docker image (ephemeral)

## Deployment

### Step 1: Final Verification

```bash
cd /opt/stranger-social-docker

# Check all files exist
ls -la docker-compose.yml .env nginx/conf.d/default.conf

# Verify .env has actual values (not templates)
grep "YOUR_" .env

# Should return nothing
```

### Step 2: Start Services

```bash
cd /opt/stranger-social-docker

# Pull latest images
docker-compose pull

# Start in foreground to see startup output (first time)
docker-compose up

# Or start in background
docker-compose up -d

# Wait for services to start (10-15 seconds)
sleep 15

# Check status
docker-compose ps
```

Expected output:
```
NAME                  COMMAND                  SERVICE    STATUS
mastodon-web          bundle exec puma ...     web        Up 10s (healthy)
mastodon-streaming    node ./streaming/...     streaming  Up 8s (healthy)
mastodon-redis        redis-server ...         redis      Up 12s (healthy)
mastodon-sidekiq-...  bundle exec sidekiq ...  sidekiq    Up 5s
mastodon-nginx        nginx -g daemon off      nginx      Up 6s
```

### Step 3: Optional - Set Up Systemd Service

```bash
# Copy service file
sudo cp /opt/stranger-social-docker/mastodon.service /etc/systemd/system/

# Reload systemd
sudo systemctl daemon-reload

# Enable auto-start
sudo systemctl enable mastodon.service

# Start service
sudo systemctl start mastodon.service

# Check status
sudo systemctl status mastodon.service

# View logs
sudo journalctl -u mastodon -f
```

## Verification

### Step 1: Check Container Health

```bash
cd /opt/stranger-social-docker

# View real-time status
watch docker-compose ps

# View logs
docker-compose logs -f web
```

### Step 2: Health Checks

```bash
cd /opt/stranger-social-docker

# Run automated checks
./maintenance.sh health-check

# Expected output should show all services are healthy
```

### Step 3: Test Web Access

```bash
# Test web server
curl -i http://127.0.0.1:3000/health

# Should return: HTTP/1.1 200 OK

# Test streaming server
curl -i http://127.0.0.1:4000/health

# Should return: HTTP/1.1 200 OK
```

### Step 4: Test HTTPS

```bash
# Test nginx
curl -I https://stranger.social/

# Certificate validation
echo | openssl s_client -servername stranger.social -connect stranger.social:443 2>/dev/null | \
  openssl x509 -noout -dates

# Should show valid certificate dates
```

### Step 5: Access Web Interface

1. Open browser to: `https://stranger.social`
2. Verify page loads (may take 5-10 seconds on first request)
3. Try logging in with existing account
4. Check media uploads work
5. Verify federation (lookup user from another instance)

### Step 6: Database Integrity

```bash
# Connect to database
psql -h localhost -U mastodon -d mastodon_production

# Count records
mastodon_production=> SELECT count(*) FROM accounts;
mastodon_production=> SELECT count(*) FROM statuses;
mastodon_production=> SELECT count(*) FROM media_attachments;

# Should show existing data
```

## Maintenance

### Daily Tasks

```bash
# Check status
docker-compose ps

# View recent logs
docker-compose logs --tail=50 web

# Monitor resources
docker stats
```

### Backups

```bash
cd /opt/stranger-social-docker

# Daily backup (add to crontab)
./maintenance.sh backup

# Backup stays in current directory with timestamp

# List backups
ls -lh mastodon-backup-*.sql.gz
```

### Updates

```bash
cd /opt/stranger-social-docker

# Check for updates
docker-compose pull

# If new versions available
./maintenance.sh update

# Or manually
docker-compose down
docker-compose pull
docker-compose up -d
```

### Maintenance Commands

```bash
cd /opt/stranger-social-docker

# View all available commands
./maintenance.sh help

# Examples
./maintenance.sh status           # Show service status
./maintenance.sh logs web         # View web logs
./maintenance.sh health-check     # Run health checks
./maintenance.sh restart web      # Restart web service
./maintenance.sh backup           # Create database backup
./maintenance.sh restore file.sql # Restore from backup
./maintenance.sh shell web        # Open shell in web container
```

### Database Maintenance

```bash
cd /opt/stranger-social-docker

# Run migrations
./maintenance.sh db-migrate

# Precompile assets (if needed after updates)
./maintenance.sh assets-precompile

# Media cleanup (weekly)
./maintenance.sh media-cleanup
```

## Troubleshooting

### Services Won't Start

```bash
# Check logs
docker-compose logs

# Common issues:
# 1. Port conflicts: Check for processes using 80, 443, 3000, 4000
sudo lsof -i :80
sudo lsof -i :443
sudo lsof -i :3000

# 2. Database not accessible
psql -h localhost -U mastodon -d mastodon_production -c "SELECT 1;"

# 3. Insufficient permissions
sudo chown 991:991 /mnt/stranger_social_20251021_1400/mastodon-public-system
```

### High CPU/Memory Usage

```bash
# Monitor
docker stats

# If web server using too much:
# Reduce PUMA_WORKERS in .env or restart

# If sidekiq using too much:
# Reduce concurrency in docker-compose.yml

# Restart after changes
docker-compose restart
```

### SSL Certificate Issues

```bash
# Check certificate validity
openssl x509 -in ./certbot/conf/live/stranger.social/fullchain.pem -noout -dates

# Check certificate dates match hostname
openssl x509 -in ./certbot/conf/live/stranger.social/fullchain.pem -noout -subject

# If expired, renew
sudo certbot renew
sudo cp /etc/letsencrypt/live/stranger.social/* ./certbot/conf/live/stranger.social/
docker-compose restart nginx
```

### Database Connection Issues

```bash
# Test direct connection
psql -h localhost -U mastodon -d mastodon_production

# If connection fails:
# 1. Check PostgreSQL is running on volume
# 2. Verify credentials: user=mastodon, password=timelord42
# 3. Check volume is mounted: df -h /mnt/stranger_social_20251021_1400

# Restart PostgreSQL if needed (may require volume remount)
```

### Redis Issues

```bash
# Check Redis health
docker-compose exec redis redis-cli ping

# Should return: PONG

# If not responding:
docker-compose restart redis
docker-compose logs redis
```

### Media Upload Issues

```bash
# Check S3 configuration
docker-compose exec web rails console
> Mastodon::Settings.storage

# Check file permissions
ls -la /mnt/stranger_social_20251021_1400/mastodon-public-system/

# Check disk space
df -h /mnt/stranger_social_20251021_1400

# Check S3 bucket access
# Try uploading media from web interface and check logs
docker-compose logs web | grep -i upload
```

### Revert to Kubernetes (if needed)

```bash
# 1. Stop Docker services
cd /opt/stranger-social-docker
docker-compose down

# 2. Backup current database
pg_dump -h localhost -U mastodon mastodon_production > /tmp/final-backup.sql

# 3. All data remains on Linode volume
# 4. Restore to Kubernetes cluster from backup
```

## Emergency Procedures

### Emergency Backup

```bash
# Full backup with compression
pg_dump -h localhost -U mastodon mastodon_production | gzip > /tmp/emergency-backup-$(date +%s).sql.gz

# Move to safe location
sudo scp /tmp/emergency-backup-*.sql.gz user@safe-host:/backups/
```

### Emergency Stop

```bash
# Stop all services immediately
docker-compose down

# This is safe - no data loss for PostgreSQL (on volume)
```

### Emergency Restore

```bash
# If catastrophic failure:
# 1. Delete corrupted containers
docker-compose down -v

# 2. Restore from backup
cd /opt/stranger-social-docker
./maintenance.sh restore /path/to/backup.sql.gz

# 3. Restart
docker-compose up -d

# 4. Verify
./maintenance.sh health-check
```

## Performance Tuning

### For High Load

```bash
# In .env, increase:
PUMA_WORKERS=4
PUMA_MIN_THREADS=5
PUMA_MAX_THREADS=10

# In docker-compose.yml, add more sidekiq workers:
# - Duplicate sidekiq services with different names
# - Or increase concurrency in existing workers

# Restart
docker-compose restart
```

### For Low Resource Machines

```bash
# In .env, decrease:
PUMA_WORKERS=1
PUMA_MIN_THREADS=3
PUMA_MAX_THREADS=3

# In docker-compose.yml:
# - Reduce resources in healthchecks
# - Remove one sidekiq worker if needed

# Restart
docker-compose restart
```

## Additional Notes

### Data Integrity

- PostgreSQL data is persistent on Linode volume
- Media files are in S3 bucket (or on Linode volume)
- Redis data is ephemeral (recreated on restart)
- Configuration is in Docker images (pulled from registry)

### Security Considerations

- Never commit `.env` file to version control
- Keep backups encrypted and secure
- Regularly update Docker images: `docker-compose pull`
- Monitor logs for security issues
- Keep host system updated: `apt-get update && apt-get upgrade`

### Monitoring

Consider adding:
- Prometheus for metrics
- Alerting for service failures
- Log aggregation (ELK stack, Papertrail, etc.)
- Uptime monitoring (UptimeRobot, Pingdom, etc.)

## Support Resources

- Mastodon Documentation: https://docs.joinmastodon.org/
- Docker Documentation: https://docs.docker.com/
- PostgreSQL Documentation: https://www.postgresql.org/docs/
- Linode Documentation: https://www.linode.com/docs/

## Summary

Your Mastodon instance has been successfully migrated to Docker Compose with:

- ✅ Mastodon v4.4.8
- ✅ PostgreSQL 15 (on Linode volume)
- ✅ Redis caching
- ✅ Proper reverse proxy with TLS
- ✅ Streaming server for real-time updates
- ✅ Multiple Sidekiq workers for job processing
- ✅ S3 support for media storage
- ✅ Automated maintenance scripts
- ✅ Systemd integration
- ✅ Complete documentation

**Next Steps:**
1. Follow the detailed setup steps above
2. Complete the PRE_MIGRATION_CHECKLIST.md
3. Deploy using docker-compose
4. Monitor in the first 24 hours
5. Set up regular backups

Good luck! 🎉
