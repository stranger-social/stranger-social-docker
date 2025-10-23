# Maintenance Schedule

Regular maintenance tasks for Mastodon Docker deployment.

## Daily Maintenance

### Monitor Logs

```bash
docker compose logs --tail=100 web
```

Look for:
- Error messages or exceptions
- Authentication failures
- Database connection issues
- Sidekiq errors

### Check Sidekiq Queue Health

```bash
docker exec mastodon-web bin/tootctl sidekiq queue
```

Or access web UI at `https://stranger.social/sidekiq` (requires admin login)

Monitor for:
- Queue backlog buildup
- Jobs taking too long to process
- Worker availability

## Weekly Maintenance

### Review Disk Usage

```bash
docker system df
docker compose ps -q | xargs docker inspect --format='{{.Name}}: {{.State.Status}}'
```

Check:
- Docker image sizes
- Volume usage trends
- Any containers that exited unexpectedly

### Check Database Size

```bash
docker exec mastodon-postgres psql -U mastodon -d mastodon_production \
  -c "SELECT pg_size_pretty(pg_database_size('mastodon_production'));"
```

### Review Error Logs

```bash
# Search for errors from past 7 days
docker logs --since 7d mastodon-web 2>&1 | grep -i error | head -20
docker logs --since 7d mastodon-postgres 2>&1 | grep -i error | head -20
```

### Test Backup

```bash
# Verify backup creation works
docker exec mastodon-postgres pg_dump -U mastodon mastodon_production | \
  gzip > test-backup-$(date +%Y%m%d).sql.gz

# Check backup size and integrity
ls -lh test-backup-*.sql.gz
gunzip -t test-backup-*.sql.gz && echo "Backup OK"
```

## Monthly Maintenance

### Full Database Backup

```bash
docker exec mastodon-postgres pg_dump -U mastodon mastodon_production | \
  gzip > backup-$(date +%Y%m%d).sql.gz

# Store in multiple locations
cp backup-*.sql.gz /backup/location1/
```

### Update Docker Images

```bash
docker compose pull
docker image prune -a --filter "until=720h"
```

### Review SSL Certificate Expiration

```bash
openssl x509 -in nginx/ssl/fullchain.pem -text -noout | grep -A2 "Validity"
```

If less than 30 days:
```bash
certbot renew --quiet
docker compose restart nginx
```

### Clean Up Old Media

```bash
# Remove media older than 30 days
docker exec mastodon-web bin/tootctl media remove --days=30

# Remove preview cards
docker exec mastodon-web bin/tootctl preview_cards remove --days=30
```

### Prune Old Docker Images

```bash
docker image prune -a --filter "until=720h"
```

### Review SMTP Delivery Rates

Check with your email provider:
- Delivery success rate
- Bounce rate
- Any sender reputation issues

### Database Optimization

```bash
# Vacuum and analyze
docker exec mastodon-postgres psql -U mastodon -d mastodon_production \
  -c "VACUUM ANALYZE;"

# Check index usage
docker exec mastodon-postgres psql -U mastodon -d mastodon_production \
  -c "SELECT schemaname, tablename, indexname, idx_scan 
      FROM pg_stat_user_indexes ORDER BY idx_scan DESC LIMIT 10;"
```

## Quarterly Maintenance

### Full System Health Check

```bash
# Check all services are healthy
docker compose ps

# Review last 90 days of errors
docker logs --since 90d mastodon-web 2>&1 | grep -i error | wc -l
docker logs --since 90d mastodon-postgres 2>&1 | grep -i error | wc -l

# Check disk usage trends
df -h
du -sh /var/lib/docker/volumes/*/
```

### Performance Review

```bash
# Check average response times (if monitoring enabled)
# Review Sidekiq processing times
# Analyze database slow query logs
docker exec mastodon-postgres psql -U mastodon -d mastodon_production \
  -c "SELECT query, calls, mean_time FROM pg_stat_statements 
      ORDER BY mean_time DESC LIMIT 10;"
```

### Security Audit

- Review `.env.example` for any exposed defaults
- Check Docker image versions are current
- Review SSH/firewall access logs
- Verify backup encryption status
- Audit database user permissions

### Disaster Recovery Test

```bash
# Perform backup to test location
docker exec mastodon-postgres pg_dump -U mastodon mastodon_production | \
  gzip > recovery-test-$(date +%Y%m%d).sql.gz

# Verify backup integrity
gunzip -t recovery-test-*.sql.gz

# Document recovery time needed
time gunzip < recovery-test-*.sql.gz | wc -l
```

## Seasonal Tasks (6-12 months)

### Major Mastodon Upgrade

1. Check release notes: https://github.com/mastodon/mastodon/releases
2. Review breaking changes
3. Backup database
4. Test in staging environment first
5. Plan maintenance window
6. Execute upgrade on production

### Docker Compose Version Update

Check for compatibility and security updates to docker-compose

### Operating System Updates

If self-hosted, apply OS security updates and patches

## Automated Maintenance

Consider implementing cron jobs for regular tasks:

```bash
# Daily backup at 2 AM
0 2 * * * docker exec mastodon-postgres pg_dump -U mastodon mastodon_production | gzip > /backups/backup-$(date +\%Y\%m\%d).sql.gz

# Weekly cleanup at 3 AM Sunday
0 3 * * 0 docker exec mastodon-web bin/tootctl media remove --days=30

# Monthly certificate check on 1st of month
0 4 1 * * certbot renew --quiet && docker compose restart nginx
```

---

**Last Updated:** October 23, 2025
