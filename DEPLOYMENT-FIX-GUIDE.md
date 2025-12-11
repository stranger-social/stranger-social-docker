# Deployment Guide for Critical Nginx/Connection Pool Fixes

## ⚠️ Important: This guide fixes the intermittent 10+ second response times and nginx "offline" issues

### What Was Wrong
- Database connection pool was exhausted (only 5 connections, but app needed 20+)
- Nginx appeared offline because Puma was queuing requests, proxy timeouts kicked in
- Rate limiting wasn't implemented, making the instance vulnerable to abuse
- Nginx worker connections were under-provisioned (768 limit)

### What's Fixed
- ✅ Database connection pool increased to 30 (matches app thread usage)
- ✅ Nginx optimized for higher concurrency (2048 connections per worker)
- ✅ Rate limiting added (30 req/sec per IP, 10 req/sec for writes)
- ✅ Proxy timeouts reduced from 60s to 30s for faster failure detection
- ✅ Connection limits per IP (max 50 simultaneous)

---

## Deployment Steps

### Step 1: Backup Current Configuration (Optional but Recommended)
```bash
cd /opt/stranger-social-docker

# Backup key files
cp docker-compose.yml docker-compose.yml.backup.2025-12-11
cp nginx/nginx.conf nginx/nginx.conf.backup.2025-12-11
cp nginx/conf.d/default.conf nginx/conf.d/default.conf.backup.2025-12-11
```

### Step 2: Verify Configuration Files Are Updated
```bash
# Check DB_POOL setting was added
grep -n "DB_POOL" docker-compose.yml

# Check nginx worker_connections was updated
grep "worker_connections" nginx/nginx.conf

# Check rate limiting zones were added
grep "limit_req_zone" nginx/conf.d/default.conf
```

Expected output:
- `docker-compose.yml`: `- DB_POOL=30`
- `nginx.conf`: `worker_connections 2048;`
- `default.conf`: `limit_req_zone...rate=30r/s` and `rate=10r/s`

### Step 3: Stop Current Services
```bash
docker-compose down

# Verify services stopped
docker-compose ps
# Should show all stopped or empty
```

### Step 4: Start Services with New Configuration
```bash
docker-compose up -d

# Watch startup logs
docker-compose logs -f
```

Wait 30-60 seconds for all services to be healthy (green status checks).

### Step 5: Verify All Services Are Running
```bash
docker-compose ps

# Expected output: All containers should show "Up (healthy)" or "Up"
# - mastodon-nginx: Up (healthy)
# - mastodon-web: Up (healthy)
# - mastodon-streaming: Up (healthy)
# - mastodon-redis: Up (healthy)
# - mastodon-postgres: Up (healthy)
# - mastodon-sidekiq-*: Up (healthy)
```

### Step 6: Quick Health Check
```bash
# Test the main endpoint
curl -i https://stranger.social/api/v1/instance | head -20

# Expected: HTTP/1.1 200 OK (should respond in <1 second)

# Test user page
curl -i https://stranger.social/@admin | head -20

# Expected: HTTP/1.1 200 OK or 302 Redirect
```

### Step 7: Check for Errors
```bash
# Should show minimal or no errors
docker logs mastodon-web --since 5m | grep -i error | head -5

# Should show no connection pool timeouts
docker logs mastodon-web --since 5m | grep "ConnectionPool" | head -5

# Should be empty (no upstream timeouts)
docker logs mastodon-nginx --since 5m | grep "upstream timed out" | head -5
```

---

## Validation Tests

### Test 1: Response Time Under Load
```bash
# Simple load test (30 concurrent, 100 total requests)
ab -n 100 -c 30 https://stranger.social/api/v1/instance

# Expected:
# - Mean response time: <1000ms
# - Failed requests: 0
# - Requests per second: >30
```

### Test 2: Rate Limiting Works
```bash
# Simulate many requests from a test IP
for i in {1..50}; do
  curl -s -o /dev/null -w "%{http_code}\n" https://stranger.social/api/v1/instance
done

# Expected:
# - First ~30 requests: 200 OK
# - Requests 31+: 429 Too Many Requests
```

### Test 3: Database Connection Health
```bash
# Check connection pool isn't exhausted
docker exec mastodon-web curl -s http://localhost:3000/health

# Expected: OK

# No connection pool timeouts in logs
docker logs mastodon-web --since 1h | grep -c "ConnectionPool::TimeoutError"

# Expected: 0 (or very low, <5)
```

### Test 4: Nginx Worker Health
```bash
docker exec mastodon-nginx ps aux | grep "nginx: worker"

# Expected: Should show multiple worker processes
# nginx      22  0:01 nginx: worker process
# nginx      23  2:15 nginx: worker process
```

---

## Rollback Instructions (If Issues Occur)

If you need to rollback:

```bash
cd /opt/stranger-social-docker

# Stop current services
docker-compose down

# Restore backup files
cp docker-compose.yml.backup.2025-12-11 docker-compose.yml
cp nginx/nginx.conf.backup.2025-12-11 nginx/nginx.conf
cp nginx/conf.d/default.conf.backup.2025-12-11 nginx/conf.d/default.conf

# Start with old configuration
docker-compose up -d

# Verify
docker-compose ps
```

---

## Monitoring After Deployment

### First Hour: Watch Closely
```bash
# Terminal 1: Watch nginx logs for errors
docker logs mastodon-nginx -f

# Terminal 2: Watch web logs for connection pool errors
docker logs mastodon-web -f | grep -E "error|timeout|Connection"

# Terminal 3: Monitor resource usage
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
```

### First 24 Hours: Check Status Periodically
```bash
# Every 4 hours, run:
docker logs mastodon-web --since 4h | grep "ConnectionPool" | wc -l
# Should be: 0

docker logs mastodon-nginx --since 4h | grep "429" | wc -l
# Should be: <10 (legitimate rate limiting)

docker-compose ps
# Should all show: Up (healthy)
```

### After 24 Hours: Review Metrics
See [docs/Monitoring-and-Diagnostics.md](Monitoring-and-Diagnostics.md) for comprehensive monitoring commands.

---

## FAQ

**Q: Will this require downtime?**
A: Yes, ~1-2 minutes while services restart. Best done during low-traffic hours.

**Q: Will this affect existing users?**
A: No, configuration changes are backward compatible. Current connections will be dropped and users will reconnect automatically.

**Q: What if rate limiting blocks legitimate traffic?**
A: Rate limits are generous (30 req/sec per IP). Legitimate federation servers and users shouldn't hit them. See monitoring guide to adjust if needed.

**Q: Do I need to restart PostgreSQL or migrate data?**
A: No, `DB_POOL` is just a Rails application setting. No database changes needed.

**Q: What if response times are still slow?**
A: Check [docs/Monitoring-and-Diagnostics.md](Monitoring-and-Diagnostics.md) troubleshooting section. Most likely causes:
1. PostgreSQL under-resourced (increase `max_connections`)
2. Redis under stress
3. Sidekiq queues backing up
4. Disk I/O bottleneck

---

## Support & Troubleshooting

For detailed monitoring, diagnostics, and troubleshooting:
- See [docs/Monitoring-and-Diagnostics.md](Monitoring-and-Diagnostics.md)

For Mastodon-specific issues:
- See [docs/Troubleshooting.md](Troubleshooting.md)

For performance tuning:
- See [docs/Performance.md](Performance.md)

---

**Deployment Version:** 5.1.1  
**Date:** December 11, 2025  
**Target Instance:** stranger.social
