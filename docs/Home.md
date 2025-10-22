# Mastodon Docker Deployment

Complete Docker Compose setup for running Mastodon in production, designed for easy migration from Kubernetes or fresh installations.

## Quick Start

### Prerequisites
- Docker & Docker Compose installed
- Domain name with DNS configured
- S3-compatible object storage (Linode Objects, AWS S3, etc.)
- SMTP email service
- SSL certificates (Let's Encrypt recommended)

### Installation

1. **Clone and Configure**
   ```bash
   git clone <your-repo-url>
   cd stranger-social-docker
   cp .env.example .env
   ```

2. **Generate Security Keys**
   ```bash
   # Generate SECRET_KEY_BASE and OTP_SECRET
   docker run --rm -it ghcr.io/mastodon/mastodon:v4.4.8 bundle exec rails secret
   
   # Generate VAPID keys for web push
   docker run --rm -it ghcr.io/mastodon/mastodon:v4.4.8 bundle exec rails mastodon:webpush:generate_vapid_key
   ```

3. **Configure Environment**
   Edit `.env` and set:
   - Database passwords
   - Security keys (SECRET_KEY_BASE, OTP_SECRET, VAPID keys)
   - Active Record encryption keys
   - S3 credentials and bucket info
   - SMTP settings
   - Your domain name (LOCAL_DOMAIN)

4. **Setup SSL Certificates**
   Place SSL certificates in `nginx/ssl/`:
   - `fullchain.pem` - Full certificate chain
   - `privkey.pem` - Private key

5. **Initialize Database** (New Installation Only)
   ```bash
   docker compose run --rm web bundle exec rails db:setup
   docker compose run --rm web bin/tootctl accounts create admin --email=admin@yourdomain.com --confirmed --role=Admin
   ```

6. **Start Services**
   ```bash
   docker compose up -d
   ```

## Architecture

### Services
- **postgres** - PostgreSQL 15 database
- **redis** - Redis 7 for caching and queues
- **web** - Mastodon web application (Puma)
- **streaming** - WebSocket streaming server
- **sidekiq** - Background job processor (default queue)
- **sidekiq-ingress** - Background job processor (ingress queue)
- **nginx** - Reverse proxy with SSL termination

### Data Storage
- PostgreSQL data: Docker volume `postgres-data`
- Redis data: Docker volume `redis-data`
- Media files: S3-compatible object storage
- Public assets: Docker volume `mastodon-public`

## Migrating from Kubernetes

### Extract Kubernetes Secrets
```bash
# Extract secrets from running Kubernetes cluster
./extract-k8s-secrets.sh

# Copy values to .env file
# Ensure SECRET_KEY_BASE, OTP_SECRET, VAPID keys match exactly
```

### Database Migration
1. **Backup Kubernetes database**
   ```bash
   kubectl exec -n mastodon mastodon-postgres-0 -- pg_dump -U mastodon mastodon_production > backup.sql
   ```

2. **Restore to Docker**
   ```bash
   # Start only postgres
   docker compose up -d postgres
   
   # Restore database
   cat backup.sql | docker exec -i mastodon-postgres psql -U mastodon -d mastodon_production
   
   # Run any pending migrations
   docker compose run --rm web bundle exec rails db:migrate
   ```

3. **Verify secrets match**
   ```bash
   # Compare encryption keys between environments
   # Mismatched keys will cause authentication failures
   ```

### Volume Migration
If using persistent volumes from Kubernetes:
```bash
# Mount Kubernetes PV data directory
sudo mount /dev/sdX /mnt/k8s_postgres_data

# Copy to Docker volume location
sudo cp -a /mnt/k8s_postgres_data/* /var/lib/docker/volumes/postgres-data/_data/
```

## Common Operations

### Create Admin User
```bash
docker exec mastodon-web bin/tootctl accounts create username \
  --email=user@example.com --confirmed --role=Admin
```

### Reset User Password
```bash
docker exec mastodon-web bin/tootctl accounts modify username --reset-password
```

### Database Maintenance
```bash
# Run migrations
docker compose run --rm web bundle exec rails db:migrate

# Reindex corrupted indexes
docker exec mastodon-postgres psql -U mastodon -d mastodon_production -c "REINDEX INDEX index_name;"

# Clear Redis cache
docker exec mastodon-redis redis-cli -a <redis-password> FLUSHALL
```

### View Logs
```bash
# All services
docker compose logs -f

# Specific service
docker logs -f mastodon-web
docker logs -f mastodon-sidekiq-default
```

### Backup Database
```bash
docker exec mastodon-postgres pg_dump -U mastodon mastodon_production | gzip > backup-$(date +%Y%m%d).sql.gz
```

## Troubleshooting

### 500 Errors / Missing Assets
**Symptom:** Blank pages, missing CSS/JS  
**Cause:** Incorrect volume mounts hiding precompiled assets

**Solution:**
1. Check `docker-compose.yml` volume paths are `/opt/mastodon/...` not `/mastodon/...`
2. Verify assets exist: `docker exec mastodon-web ls -la /opt/mastodon/public/packs`

### 502 Bad Gateway
**Symptom:** Nginx returns 502 errors  
**Cause:** Container IPs changed after restart, nginx cached old IPs

**Solution:**
```bash
docker compose restart nginx
```

### Authentication Failures / Invalid Tokens
**Symptom:** Users can't login, "invalid token" errors  
**Cause:** Mismatched encryption keys between environments

**Solution:**
1. Verify SECRET_KEY_BASE, OTP_SECRET, and ACTIVE_RECORD_ENCRYPTION_* keys match exactly
2. Extract from Kubernetes: `kubectl get secret mastodon-secrets -n mastodon -o yaml`
3. Clear Redis cache and restart: `docker compose restart redis web`

### Database Index Corruption
**Symptom:** PG::IndexCorrupted errors in logs  
**Cause:** Database volume restoration or unclean shutdown

**Solution:**
```bash
# Stop services
docker compose stop web streaming sidekiq sidekiq-ingress

# Reindex corrupted tables
docker exec mastodon-postgres psql -U mastodon -d mastodon_production -c "REINDEX TABLE users;"
docker exec mastodon-postgres psql -U mastodon -d mastodon_production -c "REINDEX TABLE accounts;"

# Restart services
docker compose up -d
```

### Email Not Sending
**Symptom:** Password resets not arriving  
**Cause:** SMTP misconfiguration

**Solution:**
1. Check SMTP credentials in `.env`
2. For Gmail: Use app-specific password, not regular password
3. Test from console:
   ```bash
   docker exec -it mastodon-web bin/rails console
   UserMailer.reset_password_instructions(User.first, 'token').deliver_now
   ```

### High Memory Usage
**Symptom:** Services consuming excessive RAM  
**Cause:** Sidekiq job accumulation

**Solution:**
1. Monitor Sidekiq queues: Check web UI at `/sidekiq`
2. Adjust worker count in `.env`: `PUMA_WORKERS=2`
3. Increase container memory limits in `docker-compose.yml`

## Configuration Reference

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `LOCAL_DOMAIN` | Yes | Your Mastodon domain (e.g., mastodon.example.com) |
| `SECRET_KEY_BASE` | Yes | Rails secret key (64+ hex chars) |
| `OTP_SECRET` | Yes | One-time password secret (64+ hex chars) |
| `VAPID_PRIVATE_KEY` | Yes | Web push private key (base64) |
| `VAPID_PUBLIC_KEY` | Yes | Web push public key (base64) |
| `DB_HOST` | Yes | PostgreSQL hostname (use service name: postgres) |
| `DB_PASSWORD` | Yes | PostgreSQL password |
| `REDIS_HOST` | Yes | Redis hostname (use service name: redis) |
| `REDIS_PASSWORD` | Yes | Redis password |
| `S3_BUCKET` | Yes | S3 bucket name for media storage |
| `AWS_ACCESS_KEY_ID` | Yes | S3 access key |
| `AWS_SECRET_ACCESS_KEY` | Yes | S3 secret key |
| `SMTP_SERVER` | Yes | SMTP server hostname |
| `SMTP_LOGIN` | Yes | SMTP username |
| `SMTP_PASSWORD` | Yes | SMTP password |

### Ports

| Service | Internal | External | Purpose |
|---------|----------|----------|---------|
| nginx | - | 80, 443 | HTTP/HTTPS |
| web | 3000 | 127.0.0.1:3000 | Web application |
| streaming | 4000 | 127.0.0.1:4000 | WebSocket streams |
| postgres | 5432 | 127.0.0.1:5432 | Database |
| redis | 6379 | 127.0.0.1:6379 | Cache/queues |

## Maintenance Schedule

### Daily
- Monitor logs for errors: `docker compose logs --tail=100 web`
- Check Sidekiq queue health at `/sidekiq`

### Weekly
- Review disk usage: `docker system df`
- Check database size: `docker exec mastodon-postgres psql -U mastodon -d mastodon_production -c "SELECT pg_size_pretty(pg_database_size('mastodon_production'));"`

### Monthly
- Backup database: `docker exec mastodon-postgres pg_dump ...`
- Prune old Docker images: `docker image prune -a`
- Review SMTP delivery rates

### Updates
```bash
# Pull new images
docker compose pull

# Stop services
docker compose down

# Run migrations
docker compose run --rm web bundle exec rails db:migrate

# Start with new version
docker compose up -d
```

## Security Considerations

1. **Never commit `.env`** - Use `.env.example` as template
2. **Rotate secrets periodically** - Especially after team changes
3. **Enable AUTHORIZED_FETCH** - Prevent unauthorized scraping
4. **Use strong passwords** - Database and Redis passwords
5. **Keep SSL certificates current** - Monitor expiration dates
6. **Limit SSH access** - Use key-based authentication only
7. **Regular backups** - Test restoration procedures
8. **Monitor logs** - Set up alerting for errors

## Performance Tuning

### For Small Instances (<1000 users)
```env
PUMA_WORKERS=2
PUMA_MAX_THREADS=5
```

### For Medium Instances (1000-10000 users)
```env
PUMA_WORKERS=4
PUMA_MAX_THREADS=10
```

### For Large Instances (>10000 users)
- Scale horizontally with multiple web containers
- Use dedicated Redis for Sidekiq
- Consider read replicas for PostgreSQL

## Support

- **Mastodon Documentation:** https://docs.joinmastodon.org/
- **Docker Compose Docs:** https://docs.docker.com/compose/
- **GitHub Issues:** <your-repo-url>/issues

## License

This deployment configuration is provided as-is for running Mastodon instances. Mastodon itself is licensed under AGPL-3.0.
