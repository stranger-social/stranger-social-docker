# Configuration Reference

Environment variables, ports, and service configuration for Mastodon Docker deployment.

## Environment Variables

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `LOCAL_DOMAIN` | Your Mastodon domain | `stranger.social` |
| `SECRET_KEY_BASE` | Rails secret key (64+ hex chars) | (generate with `rails secret`) |
| `OTP_SECRET` | One-time password secret (64+ hex chars) | (generate with `rails secret`) |
| `VAPID_PRIVATE_KEY` | Web push private key (base64) | (generate with `rails mastodon:webpush:generate_vapid_key`) |
| `VAPID_PUBLIC_KEY` | Web push public key (base64) | (generate with `rails mastodon:webpush:generate_vapid_key`) |

### Database Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `DB_HOST` | PostgreSQL hostname | `postgres` |
| `DB_PORT` | PostgreSQL port | `5432` |
| `DB_USER` | PostgreSQL username | `mastodon` |
| `DB_PASSWORD` | PostgreSQL password | *(required)* |
| `DB_NAME` | Database name | `mastodon_production` |

### Redis Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `REDIS_HOST` | Redis hostname | `redis` |
| `REDIS_PORT` | Redis port | `6379` |
| `REDIS_PASSWORD` | Redis password | *(optional)* |
| `REDIS_DB` | Redis database number | `0` |

### Storage Configuration

| Variable | Description |
|----------|-------------|
| `S3_BUCKET` | S3 bucket name for media storage |
| `S3_REGION` | AWS region or S3-compatible region |
| `S3_HOSTNAME` | S3 endpoint (for S3-compatible services) |
| `AWS_ACCESS_KEY_ID` | S3 access key |
| `AWS_SECRET_ACCESS_KEY` | S3 secret key |

### SMTP Configuration

| Variable | Description | Example |
|----------|-------------|---------|
| `SMTP_SERVER` | SMTP server hostname | `smtp.gmail.com` |
| `SMTP_PORT` | SMTP port | `587` |
| `SMTP_LOGIN` | SMTP username | `noreply@stranger.social` |
| `SMTP_PASSWORD` | SMTP password | *(required)* |
| `SMTP_AUTH_METHOD` | Authentication method | `plain` |
| `SMTP_TLS` | Enable TLS | `true` |
| `SMTP_OPENSSL_VERIFY_MODE` | SSL verification | `peer` |

### Active Record Encryption

Generate keys with:
```bash
docker run --rm -it ghcr.io/mastodon/mastodon:v4.5.3 bundle exec rails db:encryption:init
```

| Variable | Description |
|----------|-------------|
| `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY` | Primary encryption key |
| `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY` | Deterministic encryption key |
| `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` | Key derivation salt |

### Performance Tuning

| Variable | Default | Description |
|----------|---------|-------------|
| `PUMA_WORKERS` | `2` | Number of web workers |
| `PUMA_MAX_THREADS` | `5` | Max threads per worker |
| `RAILS_LOG_LEVEL` | `info` | Log level |

See [Performance Tuning](Performance.md) for recommendations by instance size.

## Service Ports

| Service | Internal | External | Purpose |
|---------|----------|----------|---------|
| nginx | - | 80, 443 | HTTP/HTTPS |
| web | 3000 | 127.0.0.1:3000 | Web application |
| streaming | 4000 | 127.0.0.1:4000 | WebSocket streams |
| postgres | 5432 | 127.0.0.1:5432 | Database |
| redis | 6379 | 127.0.0.1:6379 | Cache/queues |

## Docker Volumes

| Volume | Purpose | Container Path |
|--------|---------|-----------------|
| `postgres-data` | PostgreSQL database | `/var/lib/postgresql/data` |
| `redis-data` | Redis database | `/data` |
| `mastodon-public` | Precompiled assets | `/opt/mastodon/public` |

## Nginx Configuration

Key nginx configuration locations:
- Virtual host: `nginx/conf.d/default.conf`
- Main config: `nginx/nginx.conf`

Uses `stranger.social` as the domain.

## Security Keys Generation

### SECRET_KEY_BASE and OTP_SECRET

```bash
docker run --rm -it ghcr.io/mastodon/mastodon:v4.5.3 \
  bundle exec rails secret
```

### VAPID Keys (Web Push)

```bash
docker run --rm -it ghcr.io/mastodon/mastodon:v4.5.3 \
  bundle exec rails mastodon:webpush:generate_vapid_key
```

### Active Record Encryption Keys

```bash
docker run --rm -it ghcr.io/mastodon/mastodon:v4.5.3 \
  bundle exec rails db:encryption:init
```

---

**Last Updated:** October 23, 2025
