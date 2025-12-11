# Installation Guide

Complete Docker Compose setup for running Mastodon in production.

## Prerequisites

- Docker & Docker Compose installed
- Host meets Mastodon 4.5 runtime minimums: PostgreSQL 14+, Redis 7+; Node.js 20.19+ is required only if you build assets yourself (images ship with precompiled assets)
- Domain name with DNS configured
- S3-compatible object storage (Linode Objects, AWS S3, etc.)
- SMTP email service
- SSL certificates (Let's Encrypt recommended)

## Installation Steps

### 1. Clone and Configure

```bash
git clone <your-repo-url>
cd stranger-social-docker
cp .env.example .env
```

### 2. Generate Security Keys

```bash
# Generate SECRET_KEY_BASE and OTP_SECRET
docker run --rm -it ghcr.io/mastodon/mastodon:v4.5.3 bundle exec rails secret

# Generate VAPID keys for web push
docker run --rm -it ghcr.io/mastodon/mastodon:v4.5.3 bundle exec rails mastodon:webpush:generate_vapid_key
```

### 3. Configure Environment

Edit `.env` and set:
- Database passwords
- Security keys (SECRET_KEY_BASE, OTP_SECRET, VAPID keys)
- Active Record encryption keys
- S3 credentials and bucket info
- SMTP settings
- Your domain name (LOCAL_DOMAIN)

See [Configuration Reference](Configuration.md) for detailed environment variables.

### 4. Setup SSL Certificates

Place SSL certificates in `nginx/ssl/`:
- `fullchain.pem` - Full certificate chain
- `privkey.pem` - Private key

For Let's Encrypt, consider using Certbot:
```bash
certbot certonly --standalone -d stranger.social
```

### 5. Initialize Database (New Installation Only)

```bash
docker compose run --rm web bundle exec rails db:setup
docker compose run --rm web bin/tootctl accounts create admin \
  --email=admin@yourdomain.com --confirmed --role=Admin
```

### 6. Start Services

```bash
docker compose up -d
```

Verify all services are running:
```bash
docker compose ps
```

## Next Steps

- Review [Common Operations](Operations.md) for day-to-day management
- Check [Troubleshooting Guide](Troubleshooting.md) if issues arise
- See [Maintenance Schedule](Maintenance.md) for ongoing tasks

---

**Last Updated:** December 11, 2025
