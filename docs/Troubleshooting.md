# Troubleshooting Guide

Common issues and solutions for Mastodon Docker deployment.

## 500 Errors / Missing Assets

**Symptom:** Blank pages, missing CSS/JS, 500 errors  
**Cause:** Incorrect volume mounts hiding precompiled assets

**Solution:**

1. Check `docker-compose.yml` volume paths are `/opt/mastodon/...` not `/mastodon/...`
2. Verify assets exist:
   ```bash
   docker exec mastodon-web ls -la /opt/mastodon/public/packs
   ```
3. Precompile assets if missing:
   ```bash
   docker compose run --rm web bundle exec rails assets:precompile
   ```
4. Restart web service:
   ```bash
   docker compose restart web
   ```

## 502 Bad Gateway

**Symptom:** Nginx returns 502 errors  
**Cause:** Web container IPs changed after restart, nginx cached old IPs

**Solution:**

```bash
docker compose restart nginx
```

Check nginx is connecting to web:
```bash
docker logs mastodon-nginx | grep -i upstream
```

## Authentication Failures / Invalid Tokens

**Symptom:** Users can't login, "invalid token" errors, authentication problems  
**Cause:** Mismatched encryption keys between environments or after reload

**Solution:**

1. Verify SECRET_KEY_BASE, OTP_SECRET match exactly in `.env`:
   ```bash
   grep SECRET_KEY_BASE .env
   grep OTP_SECRET .env
   ```

2. Check ACTIVE_RECORD_ENCRYPTION_* keys match (if applicable):
   ```bash
   grep ACTIVE_RECORD_ENCRYPTION .env
   ```

3. If migrating from Kubernetes:
   - Extract from Kubernetes: `kubectl get secret mastodon-secrets -n mastodon -o yaml`
   - Ensure all keys match exactly

4. Clear sessions and restart:
   ```bash
   docker exec mastodon-redis redis-cli FLUSHALL
   docker compose restart redis web
   ```

## Database Index Corruption

**Symptom:** `PG::IndexCorrupted` errors in logs  
**Cause:** Database volume restoration or unclean shutdown

**Solution:**

```bash
# Stop services
docker compose stop web streaming sidekiq sidekiq-ingress

# Reindex corrupted tables
docker exec mastodon-postgres psql -U mastodon -d mastodon_production \
  -c "REINDEX TABLE users;"
docker exec mastodon-postgres psql -U mastodon -d mastodon_production \
  -c "REINDEX TABLE accounts;"
docker exec mastodon-postgres psql -U mastodon -d mastodon_production \
  -c "REINDEX TABLE statuses;"

# Restart services
docker compose up -d

# Monitor logs for errors
docker compose logs -f web
```

## Email Not Sending

**Symptom:** Password resets not arriving, no email delivery  
**Cause:** SMTP misconfiguration or credentials issue

**Solution:**

1. Check SMTP credentials in `.env`:
   ```bash
   grep SMTP .env
   ```

2. For Gmail: Use app-specific password, not regular password
   - Enable 2-factor authentication first
   - Generate app password at https://myaccount.google.com/apppasswords

3. Test SMTP connection:
   ```bash
   docker exec -it mastodon-web bin/rails console
   ```
   
   Then in console:
   ```ruby
   require 'net/smtp'
   Net::SMTP.start('smtp.gmail.com', 587, :enable_starttls_auto => true) do |smtp|
     smtp.authenticate('your-email@gmail.com', 'app-password')
     puts "Success!"
   end
   ```

4. Send test email:
   ```bash
   docker exec -it mastodon-web bin/rails console
   ```
   
   In console:
   ```ruby
   UserMailer.reset_password_instructions(User.first, 'token').deliver_now
   ```

## High Memory Usage

**Symptom:** Services consuming excessive RAM, system running out of memory  
**Cause:** Sidekiq job accumulation, memory leaks, or insufficient worker limits

**Solution:**

1. Monitor Sidekiq queues:
   ```bash
   docker exec mastodon-web bin/tootctl sidekiq queue
   ```
   
   Or check web UI at `https://stranger.social/sidekiq`

2. Check actual memory usage:
   ```bash
   docker stats mastodon-web mastodon-sidekiq
   ```

3. Adjust worker count in `.env`:
   ```bash
   PUMA_WORKERS=2
   PUMA_MAX_THREADS=5
   ```

4. Increase container memory limits in `docker-compose.yml`:
   ```yaml
   services:
     web:
       deploy:
         resources:
           limits:
             memory: 2G
   ```

5. Restart services:
   ```bash
   docker compose restart
   ```

## Connection Refused Errors

**Symptom:** Services can't connect to database or Redis  
**Cause:** Hostname/port mismatch, services not running, networking issues

**Solution:**

1. Verify all services are running:
   ```bash
   docker compose ps
   ```

2. Check environment variables in `.env`:
   ```bash
   grep -E "DB_HOST|REDIS_HOST" .env
   ```
   
   Should reference service names (`postgres`, `redis`) not IP addresses

3. Test connectivity from web container:
   ```bash
   docker exec mastodon-web nslookup postgres
   docker exec mastodon-web redis-cli -h redis ping
   ```

4. Check logs for specific errors:
   ```bash
   docker logs mastodon-web 2>&1 | grep -i "connection\|refused\|error"
   ```

## Sidekiq Not Processing Jobs

**Symptom:** Jobs accumulating in queue, background tasks not running  
**Cause:** Sidekiq crashed, memory issues, or misconfiguration

**Solution:**

1. Check Sidekiq status:
   ```bash
   docker ps | grep sidekiq
   ```

2. View Sidekiq logs:
   ```bash
   docker logs mastodon-sidekiq
   ```

3. Check queue status:
   ```bash
   docker exec mastodon-web bin/tootctl sidekiq queue
   ```

4. Restart Sidekiq:
   ```bash
   docker compose restart sidekiq
   ```

5. If stuck, clear jobs (⚠️ WARNING: Loses jobs):
   ```bash
   docker exec mastodon-redis redis-cli
   > FLUSHALL
   > exit
   docker compose restart sidekiq
   ```

## SSL Certificate Issues

**Symptom:** HTTPS errors, certificate warnings, "net::ERR_CERT_*" errors  
**Cause:** Missing certificates, expired certificates, or mismatched domain

**Solution:**

1. Check certificate exists:
   ```bash
   ls -la nginx/ssl/
   ```

2. Verify certificate validity:
   ```bash
   openssl x509 -in nginx/ssl/fullchain.pem -text -noout | grep -E "Subject|Issuer|Not Before|Not After"
   ```

3. Check certificate matches domain:
   ```bash
   openssl x509 -in nginx/ssl/fullchain.pem -text -noout | grep "DNS:"
   ```

4. Renew with Certbot:
   ```bash
   certbot renew --quiet
   docker compose restart nginx
   ```

## Disk Space Issues

**Symptom:** Services crash, "no space left on device" errors  
**Cause:** Full disk from logs, media, or database growth

**Solution:**

1. Check disk usage:
   ```bash
   df -h
   docker system df
   ```

2. Check Docker volume sizes:
   ```bash
   du -sh /var/lib/docker/volumes/*/
   ```

3. Clean up old logs:
   ```bash
   docker system prune -a
   ```

4. Remove old media (keep 30+ days):
   ```bash
   docker exec mastodon-web bin/tootctl media remove --days=30
   ```

5. Archive PostgreSQL logs:
   ```bash
   docker exec mastodon-postgres bash -c 'cd /var/log/postgresql && gzip *.log'
   ```

## Database Connection Pool Exhausted

**Symptom:** "PG::ConnectionBad - could not connect to server" in logs  
**Cause:** Too many connections, misconfigured pool size

**Solution:**

1. Check current connections:
   ```bash
   docker exec mastodon-postgres psql -U mastodon -d mastodon_production \
     -c "SELECT count(*) FROM pg_stat_activity;"
   ```

2. Increase connection pool in `.env`:
   ```bash
   DB_POOL=25
   ```

3. Restart web services:
   ```bash
   docker compose restart web streaming sidekiq
   ```

---

**Last Updated:** October 23, 2025
