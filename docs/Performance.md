# Performance Tuning

Optimization strategies for different Mastodon instance sizes.

## Instance Sizing Guidelines

### Small Instance (<1000 users)

**Use Case:** Personal instances, small communities, testing

**Recommended `.env` Settings:**

```env
PUMA_WORKERS=2
PUMA_MAX_THREADS=5
SIDEKIQ_CONCURRENCY=5
```

**Docker Compose Resource Limits:**

```yaml
services:
  web:
    deploy:
      resources:
        limits:
          memory: 1G
        reservations:
          memory: 512M
  sidekiq:
    deploy:
      resources:
        limits:
          memory: 1G
        reservations:
          memory: 512M
  postgres:
    deploy:
      resources:
        limits:
          memory: 2G
        reservations:
          memory: 1G
```

**Database Configuration:**

```env
DB_POOL=10
REDIS_IDLE_TIMEOUT=10
```

**Hardware Requirements:**
- CPU: 2 cores minimum
- RAM: 4GB minimum
- Storage: 50GB SSD

### Medium Instance (1000-10000 users)

**Use Case:** Regional servers, communities, corporate instances

**Recommended `.env` Settings:**

```env
PUMA_WORKERS=4
PUMA_MAX_THREADS=10
PUMA_MIN_THREADS=8
SIDEKIQ_CONCURRENCY=10
```

**Docker Compose Resource Limits:**

```yaml
services:
  web:
    deploy:
      resources:
        limits:
          memory: 2G
        reservations:
          memory: 1G
  sidekiq:
    deploy:
      resources:
        limits:
          memory: 2G
        reservations:
          memory: 1G
  postgres:
    deploy:
      resources:
        limits:
          memory: 4G
        reservations:
          memory: 2G
```

**Database Configuration:**

```env
DB_POOL=20
REDIS_IDLE_TIMEOUT=5
```

**Recommended Deployment:**

```yaml
# docker-compose.yml - Scale services
services:
  web:
    replicas: 2
  sidekiq:
    replicas: 2
  postgres:
    # Single instance with regular backups
```

**Hardware Requirements:**
- CPU: 4 cores
- RAM: 8GB
- Storage: 200GB SSD
- Network: 100 Mbps

### Large Instance (>10000 users)

**Use Case:** Public servers, research institutions, large communities

**Recommended `.env` Settings:**

```env
PUMA_WORKERS=6
PUMA_MAX_THREADS=15
PUMA_MIN_THREADS=12
SIDEKIQ_CONCURRENCY=20
SINGLE_USER_MODE=false
```

**Deployment Strategy - Horizontal Scaling:**

```yaml
# Split into multiple docker-compose instances on different hosts
# Load balance across web instances with nginx/HAProxy

# Host 1: Web instances
services:
  web1:
    ports: "127.0.0.1:3001:3000"
  web2:
    ports: "127.0.0.1:3002:3000"
  streaming1:
    ports: "127.0.0.1:4001:4000"

# Host 2: Sidekiq instances (different queues)
services:
  sidekiq-default:
    concurrency: 25
  sidekiq-ingress:
    concurrency: 15
  sidekiq-push:
    concurrency: 10

# Host 3: Database & Cache
services:
  postgres: {}  # Main database
  redis: {}     # Main cache
  postgres-replica: {}  # Read replica
```

**Database Configuration:**

```env
DB_POOL=30
REDIS_IDLE_TIMEOUT=3
DB_SLAVE_REPLICA_1=postgres-replica  # For read scaling
```

**Hardware Requirements Per Host:**
- **Web Hosts:** 8 cores, 16GB RAM each (x2-3)
- **Sidekiq Hosts:** 8 cores, 16GB RAM each (x2-3)
- **Database Host:** 16+ cores, 32GB+ RAM
- **Storage:** 1TB+ SSD with snapshots

## Database Optimization

### Connection Pooling

```env
# For small instances
DB_POOL=10
PUMA_WORKERS=2  # Usually: workers * (threads - 1) + threads

# For large instances
DB_POOL=30
PUMA_WORKERS=6  # 6 * (15 - 1) + 15 = 99 connections
```

### Indexes

Verify important indexes exist:

```bash
docker exec mastodon-postgres psql -U mastodon -d mastodon_production \
  -c "SELECT schemaname, tablename, indexname FROM pg_indexes 
      WHERE schemaname = 'public' ORDER BY tablename;"
```

Key indexes to verify:
- `accounts_lower_username_domain_index`
- `statuses_account_id_id_index`
- `local_index_statuses` (for local timeline)
- `public_index_statuses` (for public timeline)

### Vacuum and Analyze

```bash
# Schedule weekly
docker exec mastodon-postgres psql -U mastodon -d mastodon_production \
  -c "VACUUM ANALYZE;"
```

### Query Monitoring

```bash
# Find slow queries
docker exec mastodon-postgres psql -U mastodon -d mastodon_production \
  -c "SELECT query, mean_time, calls FROM pg_stat_statements 
      ORDER BY mean_time DESC LIMIT 20;"
```

## Redis Optimization

### Memory Management

```env
# Redis max memory (avoid swapping)
REDIS_MAXMEMORY=2gb
REDIS_MAXMEMORY_POLICY=allkeys-lru

# Check current usage
docker exec mastodon-redis redis-cli INFO memory
```

### Key Expiration

Redis automatically expires:
- Session keys (default: 2 weeks)
- Rate limit keys (1 minute)
- Cache keys (configurable)

Check expiration policy:

```bash
docker exec mastodon-redis redis-cli CONFIG GET timeout
```

### Database Persistence

For performance, trade safety for speed:

```yaml
# In docker-compose.yml - add to redis service
command: redis-server --save ""  # Disable RDB snapshots
```

Or safer approach:

```yaml
command: redis-server --save 900 1 --appendonly yes
```

## Caching Strategy

### HTML Caching

```env
# Cache HTML fragments (default: 1 day)
RAILS_CACHE_STORE=redis_store
CACHE_BACKEND=redis
```

### Asset Caching

```bash
# Enable Nginx caching for static assets
# In nginx/conf.d/default.conf
location ~ ^/packs/ {
    expires 7d;
    add_header Cache-Control "public, immutable";
}
```

## Sidekiq Optimization

### Worker Distribution

For large instances, separate job queues:

```yaml
services:
  sidekiq-default:
    environment:
      SIDEKIQ_QUEUES: "default"
  sidekiq-ingress:
    environment:
      SIDEKIQ_QUEUES: "ingress"
  sidekiq-push:
    environment:
      SIDEKIQ_QUEUES: "push,pull,mailers,scheduler"
```

### Concurrency Settings

```env
# Small instance
SIDEKIQ_CONCURRENCY=5

# Medium instance
SIDEKIQ_CONCURRENCY=10

# Large instance with multiple workers
SIDEKIQ_CONCURRENCY=25

# Rule of thumb: RAM / 50MB per job
# 2GB RAM = ~40 concurrency
```

### Job Monitoring

```bash
docker exec mastodon-web bin/tootctl sidekiq queue

# Output shows:
# - Queue name
# - Job count
# - Processing count
# - Average time
```

## Network Optimization

### CDN for Assets

Configure CloudFlare or similar:

```env
# Nginx headers for CDN caching
# In default.conf
add_header X-Content-Type-Options "nosniff";
add_header Cache-Control "public, max-age=31536000";
```

### Compression

Ensure nginx compression enabled:

```nginx
gzip on;
gzip_types text/plain text/css text/javascript 
           application/json application/javascript 
           text/xml application/xml;
gzip_comp_level 6;
```

## Monitoring Performance

### Key Metrics

Track over time:

```bash
# Response times
curl -w "@curl-time.txt" https://stranger.social/

# Database connections
docker exec mastodon-postgres psql -U mastodon -d mastodon_production \
  -c "SELECT count(*) FROM pg_stat_activity;"

# Redis memory
docker exec mastodon-redis redis-cli INFO memory

# Sidekiq job times
docker exec mastodon-web bin/tootctl sidekiq queue
```

### Alerting

Set up alerts for:
- High database connection count (> 80% of pool)
- Redis memory approaching limit
- Sidekiq queue backlog growing
- Web response times > 1 second (p95)
- 5xx error rate > 0.1%

## Load Testing

Before production deployment:

```bash
# Install Apache Bench or wrk
ab -n 1000 -c 50 https://stranger.social/

# Monitor during test
watch -n 1 docker stats
docker logs -f mastodon-web
```

## Troubleshooting Performance

### High Database Latency

```bash
# Check slow queries
docker logs --since 1h mastodon-postgres 2>&1 | grep -i slow

# Check indexes exist
docker exec mastodon-postgres psql -U mastodon -d mastodon_production \
  -c "REINDEX DATABASE mastodon_production;"
```

### High Memory Usage

```bash
# Check Sidekiq concurrency
grep SIDEKIQ_CONCURRENCY .env

# Monitor per-process memory
docker stats
```

### Slow API Responses

```bash
# Enable Rails query logging
RAILS_LOG_LEVEL=debug

# Profile request
docker exec -it mastodon-web bin/rails console
User.count  # Check if query is slow
```

---

**Last Updated:** October 23, 2025
