# Security Guide

Best practices and security considerations for Mastodon Docker deployment.

## Secrets Management

### Never Commit Secrets

Secrets protected by `.gitignore`:

```bash
# Check .gitignore includes
cat .gitignore | grep -E "\.env|certbot"
```

Never commit:
- `.env` file (use `.env.example` as template only)
- `certbot/live/` (generated certificates)
- SSL private keys
- Database backups

### Secret Generation Best Practices

#### SECRET_KEY_BASE and OTP_SECRET

Generate strong, unique secrets:

```bash
docker run --rm -it ghcr.io/mastodon/mastodon:v4.4.8 \
  bundle exec rails secret
```

Store in `.env` only, never in code

#### VAPID Keys (Web Push Notifications)

```bash
docker run --rm -it ghcr.io/mastodon/mastodon:v4.4.8 \
  bundle exec rails mastodon:webpush:generate_vapid_key
```

These are per-instance and shouldn't be shared

#### Active Record Encryption Keys

```bash
docker run --rm -it ghcr.io/mastodon/mastodon:v4.4.8 \
  bundle exec rails db:encryption:init
```

**Critical:** Keys cannot be changed without data loss

### Password Standards

- **Database Password:** 32+ characters, alphanumeric + symbols
- **Redis Password:** 32+ characters, alphanumeric + symbols
- **SMTP Password:** Use app-specific password if available (Gmail, etc.)

Generate strong passwords:

```bash
openssl rand -base64 32
```

### Secret Rotation

**Monthly rotation recommended:**

```bash
# Export current secrets
grep -E "SECRET_KEY_BASE|OTP_SECRET" .env > secrets-backup.txt

# Generate new secrets
docker run --rm -it ghcr.io/mastodon/mastodon:v4.4.8 \
  bundle exec rails secret

# Update .env with new values
nano .env

# Restart services
docker compose restart web streaming sidekiq
```

**Note:** This will log out all users. Plan during low-activity time.

## Access Control

### SSH Security

Limit SSH access to deployment hosts:

```bash
# Use SSH keys only, no passwords
sudo nano /etc/ssh/sshd_config

# Recommended settings:
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
Protocol 2
```

### Firewall Rules

```bash
# Only open necessary ports
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw enable
```

### Admin Account Security

```bash
# Create strong admin password on first login
docker exec mastodon-web bin/tootctl accounts modify admin --reset-password

# Enable 2FA for admin account (through web UI)
# At: https://stranger.social/settings/two_factor_authentication
```

### Database Access

```bash
# Restrict PostgreSQL connections to localhost
# In docker-compose.yml
postgres:
  environment:
    POSTGRES_INIT_ARGS: "-c shared_preload_libraries=pg_stat_statements"
  ports:
    - "127.0.0.1:5432:5432"  # Only localhost
```

## SSL/TLS Configuration

### Certificate Best Practices

```bash
# Use Let's Encrypt (free, automated)
certbot certonly --standalone -d stranger.social

# Set up auto-renewal
certbot renew --quiet --no-eff-email

# Monitor expiration (alert if < 30 days)
openssl x509 -in nginx/ssl/fullchain.pem -text -noout | grep -A2 Validity
```

### Nginx SSL Configuration

```nginx
# In nginx/conf.d/default.conf

# Force HTTPS
if ($scheme != "https") {
    return 301 https://$server_name$request_uri;
}

# Strict Transport Security
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

# Security headers
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
```

### TLS Versions

```nginx
# Disable old protocols, require TLS 1.2+
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers HIGH:!aNULL:!MD5;
ssl_prefer_server_ciphers on;
```

## Network Security

### Environment Isolation

```yaml
# In docker-compose.yml - create isolated network
networks:
  mastodon-net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16

services:
  nginx:
    networks:
      - mastodon-net
  web:
    networks:
      - mastodon-net
  postgres:
    networks:
      - mastodon-net
```

### No Internet Access for Database

```yaml
# PostgreSQL only communicates with local services
postgres:
  ports:
    - "127.0.0.1:5432:5432"  # Not exposed to network
```

### API Rate Limiting

Nginx rate limiting:

```nginx
# In nginx/nginx.conf
limit_req_zone $binary_remote_addr zone=api:10m rate=30r/m;

# In server block for API endpoints
location /api/ {
    limit_req zone=api burst=100 nodelay;
    proxy_pass http://web:3000;
}
```

## Database Security

### Authentication

```yaml
# docker-compose.yml - Force auth
postgres:
  environment:
    POSTGRES_USER: mastodon
    POSTGRES_PASSWORD: ${DB_PASSWORD}  # From .env
```

### Encryption at Rest

PostgreSQL encryption:

```bash
# Use encrypted volumes
sudo cryptsetup luksFormat /dev/sdX
sudo cryptsetup luksOpen /dev/sdX mastodon-data
sudo mkfs.ext4 /dev/mapper/mastodon-data

# Mount encrypted volume
sudo mount /dev/mapper/mastodon-data /var/lib/docker/volumes/postgres-data/
```

### Backups Encryption

```bash
# Encrypt backup before storage
docker exec mastodon-postgres pg_dump -U mastodon mastodon_production | \
  gzip | openssl enc -aes-256-cbc -salt -out backup-$(date +%Y%m%d).sql.gz.enc
```

### Principle of Least Privilege

```bash
# Database user should only have necessary permissions
docker exec mastodon-postgres psql -U postgres -d mastodon_production \
  -c "GRANT CONNECT ON DATABASE mastodon_production TO mastodon;"
```

## Application Security

### Mastodon Security Settings

In admin panel (`/admin/settings/security`):

1. **Enable OAuth 2.0 Token Validation**
2. **Set Authorized Fetch** (prevent unauthorized scraping)
3. **Enable OTEL if monitoring** (security logs)
4. **Set Media Proxy** (hide user IPs from media requests)

### AUTHORIZED_FETCH

```env
AUTHORIZED_FETCH=true
```

Prevents:
- Scraping public statuses without authentication
- Account enumeration
- Federated instances bypassing auth

### Force Email Verification

```env
EMAIL_DOMAIN_ALLOWLIST="domain1.com,domain2.com"
```

Or restrict registration:

```env
REGISTRATION_MODE=manual  # Admin approval required
```

## Monitoring & Logging

### Enable Audit Logging

```env
RAILS_LOG_TO_STDOUT=true
RAILS_LOG_LEVEL=info
```

Monitor for suspicious activity:

```bash
docker logs mastodon-web 2>&1 | grep -i "error\|unauthorized\|failed"
```

### Log Retention

```bash
# Keep logs for investigation (7-90 days depending on storage)
docker logs --since 30d mastodon-web > audit-log-$(date +%Y%m%d).txt

# Archive old logs
tar -czf logs-archive-$(date +%Y%m%d).tar.gz audit-log-*.txt
```

### Security Event Monitoring

Set up alerts for:
- Failed login attempts (pattern of failures = attack)
- Administrative actions (user creation, suspension)
- Database errors (unauthorized access attempt)
- Rate limit violations (DDoS attempt)

## Backup Security

### Backup Encryption

Always encrypt backups:

```bash
# Backup with encryption
docker exec mastodon-postgres pg_dump -U mastodon mastodon_production | \
  gzip | openssl enc -aes-256-cbc -salt -out backup.sql.gz.enc

# Restore from encrypted backup
openssl enc -d -aes-256-cbc -in backup.sql.gz.enc | gunzip | \
  docker exec -i mastodon-postgres psql -U mastodon -d mastodon_production
```

### Backup Storage

- Store backups off-site (S3, separate server)
- Use encrypted transport (HTTPS, SFTP)
- Restrict access to backups (permissions 0600)
- Test restoration regularly (verify backup integrity)

### Backup Frequency

```bash
# Daily automated backup
0 2 * * * docker exec mastodon-postgres pg_dump -U mastodon mastodon_production | gzip | openssl enc -aes-256-cbc -salt -out /backups/backup-$(date +\%Y\%m\%d).sql.gz.enc

# Weekly rotation (keep 4 weeks)
0 3 1 * * find /backups -name "backup-*.sql.gz.enc" -mtime +28 -delete
```

## Incident Response

### Breach Response Plan

1. **Isolate** affected services
2. **Analyze** logs for scope
3. **Rotate** credentials/secrets
4. **Patch** vulnerabilities
5. **Verify** all systems secure
6. **Communicate** transparently with users

### Security Headers Verification

```bash
# Check headers are present
curl -I https://stranger.social | grep -E "Strict-Transport-Security|X-Frame-Options|X-Content-Type"
```

### SSL Certificate Security

```bash
# Verify certificate chain
openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt \
  nginx/ssl/fullchain.pem

# Check for certificate pinning bypass vulnerabilities
openssl x509 -in nginx/ssl/fullchain.pem -noout -pubkey | \
  openssl pkey -pubin -outform DER | openssl dgst -sha256 -binary | base64
```

## References

- **OWASP Top 10:** https://owasp.org/www-project-top-ten/
- **Mastodon Security:** https://docs.joinmastodon.org/admin/follow-recommendations/
- **Docker Security:** https://docs.docker.com/engine/security/
- **PostgreSQL Security:** https://www.postgresql.org/docs/current/sql-syntax.html

---

**Last Updated:** October 23, 2025
