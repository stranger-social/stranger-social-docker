# Server Migration Guide

Migrating Mastodon from any server deployment (Kubernetes, VPS, bare metal, Docker) to Docker Compose.

## Pre-Migration Checklist

Before starting migration, verify you have:

- [ ] Access to current Mastodon server/cluster
- [ ] Database backup created and tested
- [ ] All encryption keys and secrets documented
- [ ] SSL certificates ready or Let's Encrypt domain configured
- [ ] S3/object storage credentials and bucket information
- [ ] SMTP email service credentials
- [ ] Current Mastodon version number
- [ ] List of admin accounts
- [ ] Maintenance window scheduled with users
- [ ] Rollback plan documented

## Gathering Configuration & Secrets

### Find Current Configuration

**From Environment Variables:**
```bash
# If you have SSH/shell access to current server
env | grep -i mastodon
env | grep -i db_
env | grep -i redis_
env | grep -i s3_
env | grep -i smtp_
```

**From Docker Compose (if migrating from Docker):**
```bash
docker exec mastodon-web printenv | grep -E "SECRET_KEY|OTP_SECRET|VAPID|DB_|REDIS_|S3_|SMTP_"
```

**From Kubernetes:**
```bash
# Get all secrets
kubectl get secret mastodon-secrets -n mastodon -o yaml > mastodon-secrets.yaml

# Extract specific secret values (base64 decoded)
kubectl get secret mastodon-secrets -n mastodon -o jsonpath='{.data.SECRET_KEY_BASE}' | base64 -d
```

**From Systemd Service:**
```bash
# If running as systemd service
cat /etc/systemd/system/mastodon.service
grep ^Environment= /etc/systemd/system/mastodon.service
```

**From .env File:**
```bash
# If you have direct file access
cat /home/mastodon/.env.production
cat /etc/mastodon/.env
```

### Required Secrets

Copy these values from your current installation:

| Secret | Purpose | Location |
|--------|---------|----------|
| `SECRET_KEY_BASE` | Rails app key | Environment variable or `.env` |
| `OTP_SECRET` | Two-factor auth | Environment variable or `.env` |
| `VAPID_PRIVATE_KEY` | Web push notifications | Environment variable or `.env` |
| `VAPID_PUBLIC_KEY` | Web push notifications | Environment variable or `.env` |
| `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY` | Database encryption | Environment variable or `.env` |
| `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY` | Database encryption | Environment variable or `.env` |
| `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` | Database encryption | Environment variable or `.env` |
| `DB_PASSWORD` | Database password | Environment variable or `.env` |
| `REDIS_PASSWORD` | Redis password (if used) | Environment variable or `.env` |
| `AWS_ACCESS_KEY_ID` | S3 access key | Environment variable or `.env` |
| `AWS_SECRET_ACCESS_KEY` | S3 secret key | Environment variable or `.env` |

### Required Configuration

| Setting | Example | Location |
|---------|---------|----------|
| `LOCAL_DOMAIN` | `stranger.social` | Environment variable |
| `S3_BUCKET` | `mastodon-media` | Environment variable |
| `S3_REGION` | `us-east-1` | Environment variable |
| `S3_HOSTNAME` | `s3.amazonaws.com` | Environment variable |
| `SMTP_SERVER` | `smtp.gmail.com` | Environment variable |
| `SMTP_PORT` | `587` | Environment variable |
| `SMTP_LOGIN` | `noreply@stranger.social` | Environment variable |
| `SMTP_PASSWORD` | (sensitive) | Environment variable |

**Tip:** If you can't find these values, check:
- `/home/mastodon/.env.production`
- `/etc/mastodon/.env`
- Docker environment (docker inspect, docker-compose.yml)
- Kubernetes secrets/configmaps
- Application admin panel configuration

## Database Migration

The most critical part of any migration is transferring your database safely.

### Option 1: Live Database Backup (Recommended)

Minimizes downtime by backing up while services are running:

```bash
# 1. SSH into your current server and create backup
ssh user@current-server
pg_dump -U mastodon mastodon_production | gzip > backup-$(date +%Y%m%d-%H%M%S).sql.gz

# 2. Download backup to Docker host
scp user@current-server:backup-*.sql.gz ./

# 3. Start Docker postgres
docker compose up -d postgres

# 4. Wait for postgres to initialize
sleep 30

# 5. Create database (if needed)
docker exec mastodon-postgres createdb -U mastodon mastodon_production

# 6. Restore backup
gunzip < backup-*.sql.gz | docker exec -i mastodon-postgres \
  psql -U mastodon -d mastodon_production

# 7. Verify restore
docker exec mastodon-postgres psql -U mastodon -d mastodon_production \
  -c "SELECT count(*) FROM accounts;"
```

### Option 2: Backup File Transfer

For large databases or unreliable connections:

```bash
# 1. Create backup on current server and stream to Docker host
ssh user@current-server "pg_dump -U mastodon mastodon_production | gzip" > backup.sql.gz

# 2. Start Docker postgres
docker compose up -d postgres
sleep 30

# 3. Create database and restore
docker exec mastodon-postgres createdb -U mastodon mastodon_production
gunzip < backup.sql.gz | docker exec -i mastodon-postgres \
  psql -U mastodon -d mastodon_production

# 4. Verify
docker exec mastodon-postgres psql -U mastodon -d mastodon_production \
  -c "SELECT pg_size_pretty(pg_database_size('mastodon_production'));"
```

### Verify Database After Restore

```bash
# Check basic tables exist
docker exec mastodon-postgres psql -U mastodon -d mastodon_production -c "\dt"

# Count records
docker exec mastodon-postgres psql -U mastodon -d mastodon_production \
  -c "SELECT 'accounts' as table, count(*) FROM accounts
      UNION ALL SELECT 'statuses', count(*) FROM statuses
      UNION ALL SELECT 'users', count(*) FROM users;"

# Check for corruption
docker exec mastodon-postgres psql -U mastodon -d mastodon_production \
  -c "REINDEX DATABASE mastodon_production;"
```

## Secret Transfer

### 1. Create .env File

```bash
# Copy template
cp .env.example .env

# Edit with values from current server
nano .env
```

Paste extracted secrets and configuration:

```bash
LOCAL_DOMAIN=stranger.social
SECRET_KEY_BASE=<paste-from-current-server>
OTP_SECRET=<paste-from-current-server>
VAPID_PRIVATE_KEY=<paste-from-current-server>
VAPID_PUBLIC_KEY=<paste-from-current-server>
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=<paste-from-current-server>
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=<paste-from-current-server>
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=<paste-from-current-server>
DB_PASSWORD=<paste-from-current-server>
REDIS_PASSWORD=<optional>
S3_BUCKET=<paste-from-current-server>
S3_REGION=<paste-from-current-server>
AWS_ACCESS_KEY_ID=<paste-from-current-server>
AWS_SECRET_ACCESS_KEY=<paste-from-current-server>
SMTP_SERVER=<paste-from-current-server>
SMTP_PORT=<paste-from-current-server>
SMTP_LOGIN=<paste-from-current-server>
SMTP_PASSWORD=<paste-from-current-server>
```

### 2. Verify Secrets Match

```bash
# Compare key hashes with current server to verify they match
sha256sum .env

# Never commit .env to git
echo ".env" >> .gitignore
git add .gitignore
```

### 3. Security Check

```bash
# Ensure file permissions are restrictive
chmod 600 .env

# Verify it's not tracked by git
git status | grep ".env"  # Should show nothing
```

## SSL Certificate Transfer

### Option 1: Current Certificates (Recommended)

Transfer existing Let's Encrypt certificates:

```bash
# 1. Get certificates from current server
scp user@current-server:/etc/letsencrypt/live/stranger.social/fullchain.pem ./
scp user@current-server:/etc/letsencrypt/live/stranger.social/privkey.pem ./

# 2. Place in Docker Certbot structure
mkdir -p certbot/live/stranger.social
cp fullchain.pem certbot/live/stranger.social/
cp privkey.pem certbot/live/stranger.social/

# 3. Verify permissions
ls -la certbot/live/stranger.social/

# 4. Check certificate validity
openssl x509 -in certbot/live/stranger.social/fullchain.pem -text -noout | grep -A2 Validity
```

### Option 2: New Let's Encrypt Certificate

Generate a new certificate on the Docker host:

```bash
# 1. Ensure domain points to new Docker host
# (Wait for DNS propagation: dig stranger.social)

# 2. Use Certbot to generate certificate
certbot certonly --standalone -d stranger.social

# 3. Verify certificate was created
ls -la /etc/letsencrypt/live/stranger.social/

# 4. Copy to Docker structure
mkdir -p certbot/live/stranger.social
cp /etc/letsencrypt/live/stranger.social/fullchain.pem certbot/live/stranger.social/
cp /etc/letsencrypt/live/stranger.social/privkey.pem certbot/live/stranger.social/
```

### Certificate Renewal

After migration, set up auto-renewal:

```bash
# Certbot renewal cron job
certbot renew --quiet --post-hook "docker compose restart nginx"

# Or add to crontab (daily check)
0 3 * * * certbot renew --quiet --post-hook "docker compose restart nginx"
```

## Storage Migration

### S3/Object Storage

The good news: S3 storage is provider-agnostic and doesn't need migration.

```bash
# Option A: Keep same bucket (recommended)
# Just use same credentials in .env
S3_BUCKET=mastodon-media
AWS_ACCESS_KEY_ID=<same-as-before>
AWS_SECRET_ACCESS_KEY=<same-as-before>
S3_HOSTNAME=s3.amazonaws.com  # or your provider's endpoint

# Option B: New bucket (if needed)
# Copy media from old bucket to new bucket
aws s3 sync s3://old-bucket s3://new-bucket

# Update .env with new bucket name
S3_BUCKET=new-bucket-name
```

### Local Media Storage

If you used local filesystem instead of S3:

```bash
# 1. Copy media files from current server
scp -r user@current-server:/mastodon/public/system ./media-backup/

# 2. Create Docker volume and populate
docker volume create mastodon-storage

# 3. Copy files to volume location
sudo cp -r media-backup/* /var/lib/docker/volumes/mastodon-storage/_data/

# 4. Fix permissions
sudo chown -R 991:991 /var/lib/docker/volumes/mastodon-storage/_data/

# 5. Update docker-compose.yml to mount this volume
# (See docker-compose.yml volumes section)
```

## Pre-Deployment Verification

Before starting the cutover, verify everything is ready:

### Database Tests

```bash
# Check restored database exists
docker exec mastodon-postgres psql -U mastodon -d mastodon_production -c "SELECT version();"

# Verify data integrity
docker exec mastodon-postgres psql -U mastodon -d mastodon_production \
  -c "SELECT 'accounts' as table_name, count(*) as rows FROM accounts
      UNION ALL SELECT 'users', count(*) FROM users
      UNION ALL SELECT 'statuses', count(*) FROM statuses
      UNION ALL SELECT 'follows', count(*) FROM follows;"

# Check for indexes
docker exec mastodon-postgres psql -U mastodon -d mastodon_production \
  -c "SELECT count(*) as index_count FROM pg_indexes WHERE schemaname='public';"
```

### Secrets Validation

```bash
# Test that all environment variables are loaded
docker compose run --rm web /bin/bash

# Inside the container, verify secrets
echo $SECRET_KEY_BASE
echo $VAPID_PRIVATE_KEY
echo $S3_BUCKET
exit
```

### Connectivity Tests

```bash
# Test database connection
docker compose run --rm web psql -h postgres -U mastodon -d mastodon_production -c "SELECT now();"

# Test Redis connection (if using)
docker compose run --rm web redis-cli -h redis ping

# Test S3 connectivity
docker compose run --rm web ruby -e "require 'aws-sdk-s3'; puts 'S3 SDK loaded'"
```

### Mastodon-Specific Tests

```bash
# Precompile assets (if not already done)
docker compose run --rm web bundle exec rails assets:precompile

# Run migrations (if version differs from current server)
docker compose run --rm web bundle exec rails db:migrate

# Check health endpoint
docker compose run --rm web bin/rails runner "puts 'Rails environment OK'"
```

## Migration Procedure

### Step 1: Plan Downtime

- [ ] Notify users of maintenance window
- [ ] Choose low-activity time window (1-4 hours recommended)
- [ ] Document current status (version, user count, etc.)
- [ ] Brief administrators on status monitoring
- [ ] Have rollback procedure ready

### Step 2: Final Backups

```bash
# Create final backup from current server
ssh user@current-server "pg_dump -U mastodon mastodon_production | gzip" > final-backup-$(date +%Y%m%d-%H%M%S).sql.gz

# Verify backup size is reasonable
ls -lh final-backup-*.sql.gz
```

### Step 3: Prepare Docker Environment

```bash
# Verify all configs are in place
ls -la .env  # Should exist and have 600 permissions
ls -la nginx/conf.d/default.conf
ls -la certbot/live/stranger.social/

# Check docker-compose.yml is valid
docker compose config > /dev/null && echo "Compose config OK"
```

### Step 4: Stop Current Services

```bash
# SSH into current server
ssh user@current-server

# Stop services (method depends on deployment type)
# For Docker:
docker compose down

# For Kubernetes:
kubectl scale deployment mastodon-web --replicas=0 -n mastodon
kubectl scale deployment mastodon-streaming --replicas=0 -n mastodon
kubectl scale deployment mastodon-sidekiq --replicas=0 -n mastodon

# For Systemd:
sudo systemctl stop mastodon-web
sudo systemctl stop mastodon-streaming
sudo systemctl stop mastodon-sidekiq
```

### Step 5: Restore Database

```bash
# Start postgres service
docker compose up -d postgres

# Wait for startup
sleep 15

# Create database
docker exec mastodon-postgres createdb -U mastodon mastodon_production

# Restore from backup
gunzip < final-backup-*.sql.gz | docker exec -i mastodon-postgres \
  psql -U mastodon -d mastodon_production

# Run any pending migrations
docker compose run --rm web bundle exec rails db:migrate
```

### Step 6: Start Services

```bash
# Start all services
docker compose up -d

# Verify services are running
docker compose ps

# Monitor logs for errors
docker compose logs -f --tail=50 web
```

### Step 7: Update DNS (if needed)

```bash
# If migrating to new host/IP:
# Update DNS records to point to new Docker host

# Verify DNS propagation
nslookup stranger.social
dig stranger.social +short
```

### Step 8: Validation

```bash
# Check web interface
curl -I https://stranger.social/

# Check API
curl https://stranger.social/api/v1/instance | jq .

# Check WebSocket streaming (should connect)
curl -I https://stranger.social/api/v1/streaming/health

# Monitor logs for errors
docker compose logs --since 5m | grep -i error
```

## Post-Migration Checklist

After successful migration:

- [ ] All services running (`docker compose ps`)
- [ ] Web interface accessible and responsive
- [ ] Users can login
- [ ] Timeline loads correctly
- [ ] Federated posts appear
- [ ] Email notifications working (test by resetting password)
- [ ] Media uploads functional
- [ ] Sidekiq processing jobs (`docker exec mastodon-web bin/tootctl sidekiq queue`)
- [ ] Admin panel accessible
- [ ] No error spikes in logs
- [ ] SSL certificate valid
- [ ] Backups automated and tested
- [ ] Old server safely archived

## Troubleshooting During Migration

### Database Connection Failed

```bash
# Check postgres is running
docker compose ps postgres

# Check logs
docker logs mastodon-postgres

# Test connection manually
docker exec mastodon-postgres psql -U mastodon -c "SELECT 1"
```

### Web Service Won't Start

```bash
# Check logs
docker logs mastodon-web

# Verify database is accessible
docker compose run --rm web psql -h postgres -U mastodon -d mastodon_production -c "SELECT 1"

# Check environment variables
docker compose run --rm web env | grep -E "SECRET_KEY|DB_"
```

### Migration Fails - Quick Rollback

If something critical fails, you can quickly rollback:

```bash
# 1. Stop Docker services
docker compose down

# 2. Restart old services on current server
# This depends on your deployment type - check Step 4 for stop procedures

# 3. Redirect traffic back to old server (DNS/load balancer)

# 4. Notify users
# Apologize and provide status update
```

## Common Gotchas

### Secret Keys Must Match Exactly

⚠️ **Critical:** If encryption keys don't match:
- Users cannot login (invalid tokens)
- Web notifications fail
- Admin accounts locked out

**Solution:** Triple-check all encryption keys when copying from current server. Use `sha256sum` to verify exact matches.

### Database Version Mismatch

If migrating from older PostgreSQL version:

```bash
# Check versions
psql --version  # On current server
docker exec mastodon-postgres psql --version  # Docker

# If versions differ significantly, may need migration via pg_dump/restore
# (which is what we're already doing)
```

### Missing Media Files

If using local storage and media doesn't transfer:

```bash
# Check Docker volume has media
docker exec mastodon-web ls -la /opt/mastodon/public/system/

# Restore from backup if needed
# See Storage Migration section above
```

### High Load During Migration

If the Docker host gets overwhelmed:

```bash
# Check resource usage
docker stats

# Reduce Sidekiq concurrency temporarily
# Edit .env: SIDEKIQ_CONCURRENCY=5 (lower than normal)
docker compose restart sidekiq

# Increase after load decreases
```

### DNS Not Updating

If DNS still points to old server:

```bash
# Force DNS flush (varies by OS)
# macOS:
sudo dscacheutil -flushcache

# Linux:
sudo systemctl restart systemd-resolved

# Check propagation
dig stranger.social +short
nslookup stranger.social
```

## Success Indicators

Your migration was successful if:

✅ All Docker containers healthy and stable  
✅ Users report normal operations  
✅ No authentication errors in logs  
✅ Sidekiq queue processing normally  
✅ Email notifications working  
✅ Federation with other instances working  
✅ Media uploads and viewing working  
✅ Admin panel responsive  
✅ SSL certificate valid and trusted  
✅ Backup to S3/storage working automatically  

## After Migration

### Archive Old Server

Once stable for 1-2 weeks:

```bash
# Stop services on old server
ssh user@current-server "docker compose down"

# Or for Kubernetes
ssh user@current-server "kubectl delete namespace mastodon"

# Archive configuration
ssh user@current-server "tar -czf mastodon-config-backup-$(date +%Y%m%d).tar.gz /etc/mastodon/ /home/mastodon/"

# Download to safe location
scp user@current-server:mastodon-config-backup-*.tar.gz ./backups/
```

### Update Documentation

- Update any internal documentation pointing to old server
- Document new connection parameters
- Note any configuration differences from previous setup

---

**Last Updated:** October 23, 2025
