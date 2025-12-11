# Monitoring and Diagnostics Guide

## Overview

This guide explains how to monitor your Mastodon instance for performance issues and diagnose problems, particularly related to nginx response times and service availability.

---

## Problem Summary: What We Found

Your nginx server was experiencing intermittent availability issues with 10+ second response times. **Root cause:** Database connection pool exhaustion in the Rails application layer, not nginx itself.

### The Issue:
- **Puma (Rails web server)** was configured with 2 workers × 5-10 threads = 20 max concurrent requests
- **Database connection pool** was only 5 connections (default)
- This mismatch caused connection pool exhaustion: "Waited 5 sec, 0/5 available"
- When DB connections ran out, Puma queued requests, nginx proxies timed out waiting, appearing offline

### Traffic Pattern:
- Legitimate Mastodon federation traffic (NOT a DDoS)
- Multiple Mastodon servers, Lemmy instances, real users
- High CPU load was normal workload, not abuse

---

## Fixes Applied

### 1. Database Connection Pool (Primary Fix)
**File:** `docker-compose.yml`

```yaml
environment:
  # Database Connection Pool Configuration
  # Must be >= (PUMA_WORKERS * PUMA_MAX_THREADS) + headroom
  # With 2 workers × 10 threads = 20 max, using 30 for safety
  - DB_POOL=30
  - DB_TIMEOUT=30
```

**Why:** With 30 connections and 20 max threads, you have 50% headroom. This prevents the queue from exhausting.

### 2. Nginx Configuration Optimization
**File:** `nginx/nginx.conf`

```nginx
worker_rlimit_nofile 65536;    # Allow more file descriptors
worker_connections 2048;        # Doubled from 768 per worker
client_body_timeout 12;         # Faster timeout for stalled clients
client_header_timeout 12;
send_timeout 10;
keepalive_requests 100;         # Limit keepalive reuse
```

### 3. Rate Limiting & Abuse Protection
**File:** `nginx/conf.d/default.conf`

```nginx
# 30 req/sec per IP for general API
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=30r/s;

# 10 req/sec per IP for write operations (POST, PUT, DELETE)
limit_req_zone $binary_remote_addr zone=write_limit:10m rate=10r/s;

# Max 50 simultaneous connections per IP
limit_conn_zone $binary_remote_addr zone=conn_limit:10m;
```

### 4. Optimized Proxy Timeouts
- Reduced from 60s to **30s** (web/streaming proxy)
- Faster failure detection = better user experience
- Old 60s timeouts masked the real issue

---

## How to Deploy These Changes

### Step 1: Update Configuration Files
Files have been updated:
- `docker-compose.yml` - DB connection pool settings
- `nginx/nginx.conf` - Worker optimization
- `nginx/conf.d/default.conf` - Rate limiting

### Step 2: Restart Services
```bash
# Stop current services
docker-compose down

# Start with new configuration
docker-compose up -d

# Watch logs for errors
docker logs mastodon-nginx -f
docker logs mastodon-web -f
```

### Step 3: Verify Health
```bash
# Check all services are running
docker-compose ps

# Test response times
curl -i https://stranger.social/api/v1/instance
curl -i https://stranger.social/@admin

# Check for errors (should be empty or minimal)
docker logs mastodon-web --since 5m | grep ConnectionPool
```

---

## Monitoring Commands

### 1. Check Database Connection Pool Status
```bash
# View current connection usage
docker exec mastodon-web curl -s http://localhost:3000/admin | grep pool

# Alternative: Check Rails logs for pool errors
docker logs mastodon-web --since 10m | grep "ConnectionPool::TimeoutError"
```

### 2. Check Nginx Performance
```bash
# View nginx worker processes
docker exec mastodon-nginx ps aux | grep "nginx: worker"

# Check nginx error log for proxy timeouts
docker logs mastodon-nginx --since 10m | grep "upstream timed out"

# Count active connections per IP
docker exec mastodon-nginx ss -an | grep ESTABLISHED | wc -l
```

### 3. Check Web Service Health
```bash
# Test health endpoint (should return "OK")
docker exec mastodon-web curl http://localhost:3000/health

# Check Puma thread usage
docker exec mastodon-web ps aux | grep puma

# View web service CPU/memory
docker stats mastodon-web
```

### 4. Check Redis & Database
```bash
# Test Redis connectivity
docker exec mastodon-redis redis-cli -a $REDIS_PASSWORD ping

# Check database connections
docker exec mastodon-postgres psql -U mastodon -d mastodon_production -c \
  "SELECT datname, count(*) FROM pg_stat_activity GROUP BY datname;"

# Check for long-running queries
docker exec mastodon-postgres psql -U mastodon -d mastodon_production -c \
  "SELECT pid, usename, query, query_start FROM pg_stat_activity 
   WHERE query NOT LIKE '%idle%' AND query_start < now() - interval '5 minutes';"
```

### 5. Check for Rate Limit Blocking
```bash
# View requests being rate-limited (429 responses)
docker logs mastodon-nginx --since 10m | grep " 429 "

# Count by IP
docker logs mastodon-nginx --since 1h | grep " 429 " | cut -d' ' -f1 | sort | uniq -c | sort -rn
```

### 6. Full System Resource Check
```bash
# Docker container stats
docker stats --no-stream

# System load
uptime

# Memory usage
free -h

# Disk space
df -h /mnt/stranger_social_*
```

---

## Alerting & Thresholds

Set up monitoring with these thresholds:

| Metric | Warning | Critical | Action |
|--------|---------|----------|--------|
| Puma DB Connection Timeout | >5 occurrences/min | >20 occurrences/min | Increase `DB_POOL` |
| Nginx Upstream Timeout | >10/min | >100/min | Check web service health |
| HTTP 429 (Rate Limited) | >100 unique IPs/hour | >1000/hour | Review abuse patterns |
| Puma Memory | >1.8GB | >1.95GB (limit) | Reduce `PUMA_MAX_THREADS` |
| Nginx Response Time | >2s p95 | >5s p95 | Check database/redis |
| Database Connections | >25 active | >28 active | Increase `DB_POOL` |

---

## Troubleshooting Checklist

### Nginx Still Showing Offline?
1. Check web service health: `docker exec mastodon-web curl http://localhost:3000/health`
2. Check web logs for connection pool errors: `docker logs mastodon-web --since 5m | grep -i error`
3. Verify database is running: `docker exec mastodon-postgres pg_isready`
4. Check nginx error log: `docker logs mastodon-nginx`

### High Response Times (>2 seconds)?
1. Check web service CPU: `docker stats mastodon-web`
2. Check database CPU: `docker stats mastodon-postgres`
3. Check Redis: `docker exec mastodon-redis redis-cli -a $REDIS_PASSWORD info stats`
4. Look for slow queries: `docker logs mastodon-web --since 5m | grep "Duration:"`

### Rate Limiting False Positives?
1. Check if legitimate Mastodon servers are blocked: `docker logs mastodon-nginx | grep "429" | cut -d' ' -f1 | sort -u`
2. Whitelist trusted federation servers in `nginx/conf.d/default.conf`:
   ```nginx
   geo $rate_limit_key {
     default $binary_remote_addr;
     45.79.85.173 "";  # trusted.mastodon
   }
   ```

### Connection Pool Still Exhausted?
Current config: `DB_POOL=30` with 2 workers × 10 threads
If still seeing errors:
1. **Increase DB_POOL:** `DB_POOL=50` (watch PostgreSQL max_connections)
2. **Reduce Puma threads:** `PUMA_MAX_THREADS=8` (lower memory, less connection demand)
3. **Add more Puma workers:** `PUMA_WORKERS=3` (more processes, but more memory)

---

## Performance Tuning Reference

### Current Settings (v5.1.1):
```yaml
# Puma Configuration (.env)
PUMA_WORKERS=2           # 2 processes
PUMA_MIN_THREADS=5       # 5 threads min per worker
PUMA_MAX_THREADS=10      # 10 threads max per worker
PUMA_PERSISTENT_TIMEOUT=20

# Database Configuration (docker-compose.yml)
DB_POOL=30               # Connection pool size
DB_TIMEOUT=30            # Wait timeout (seconds)

# PostgreSQL Configuration (docker-compose.yml)
max_connections=225      # Server limit
shared_buffers=1GB       # Memory pool

# Nginx Configuration (nginx/nginx.conf)
worker_connections=2048  # Per worker
```

### For Larger Instances (100+ active users):
```yaml
PUMA_WORKERS=3           # More processes
PUMA_MAX_THREADS=12      # More threads
DB_POOL=50               # Larger pool
max_connections=300      # PostgreSQL
shared_buffers=2GB       # PostgreSQL
```

### For Smaller Instances (<10 active users):
```yaml
PUMA_WORKERS=1           # Single process
PUMA_MAX_THREADS=5       # Fewer threads
DB_POOL=15               # Smaller pool
max_connections=100      # PostgreSQL
```

---

## Log Locations

Inside containers:
- **Nginx:** `/var/log/nginx/access.log` (requests), `/var/log/nginx/error.log` (errors)
- **Rails/Puma:** stdout (captured by Docker)
- **PostgreSQL:** `/var/log/postgresql/postgresql.log`
- **Redis:** stdout (captured by Docker)

View from host:
```bash
docker logs mastodon-nginx
docker logs mastodon-web
docker logs mastodon-postgres
docker logs mastodon-redis
```

---

## Federation Health

Mastodon federation can be CPU-intensive. Monitor these:

```bash
# Check sidekiq ingress queue (federation inbox)
docker exec mastodon-web rails sidekiq_queue | grep ingress

# Count pending activities
docker exec mastodon-web bundle exec rails runner \
  "puts ActivityPub::Activity.count"

# Check for stuck federation jobs
docker logs mastodon-sidekiq-ingress --since 10m | grep -i error
```

If federation is causing high load:
1. **Increase sidekiq-ingress workers:** `SIDEKIQ_INGRESS_CONCURRENCY=25` (in `.env`)
2. **Limit federation fetches:** Set `LIMITED_FEDERATION_MODE=true` to reduce remote user fetches

---

## Regular Maintenance

### Daily:
```bash
# Check for errors
docker logs mastodon-web --since 24h | grep -i "error\|timeout" | tail -20

# Verify all services healthy
docker-compose ps
```

### Weekly:
```bash
# Analyze slow requests
docker logs mastodon-web --since 7d | grep "Duration:" | sort | tail -10

# Check database bloat
docker exec mastodon-postgres vacuumdb -d mastodon_production -z

# Verify backups are working
ls -lh pgbackups/daily/ | head -5
```

### Monthly:
```bash
# Full health check
docker-compose ps
docker stats --no-stream
df -h
docker exec mastodon-postgres psql -U mastodon -d mastodon_production -c "SELECT * FROM pg_stat_user_tables ORDER BY seq_scan DESC LIMIT 5;"
```

---

## Next Steps

1. **Deploy the configuration changes** (see "How to Deploy")
2. **Monitor for the next 24 hours** using the commands above
3. **If response times improve**, you've solved the issue
4. **If issues persist**, check the troubleshooting checklist
5. **Document any custom tuning** in your deployment notes

---

## Additional Resources

- [Mastodon Admin Documentation](https://docs.joinmastodon.org/admin/setup/)
- [PostgreSQL Performance Tuning](https://wiki.postgresql.org/wiki/Performance_Optimization)
- [Nginx Rate Limiting](https://nginx.org/en/docs/http/ngx_http_limit_req_module.html)
- [Puma Configuration](https://github.com/puma/puma/blob/master/docs/configuration.md)

---

**Version:** 5.1.1  
**Last Updated:** December 11, 2025  
**Created for stranger.social**
