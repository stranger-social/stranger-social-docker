# Common Operations

Day-to-day management tasks for Mastodon Docker deployment.

## User Management

### Create Admin User

```bash
docker exec mastodon-web bin/tootctl accounts create username \
  --email=user@stranger.social --confirmed --role=Admin
```

### Reset User Password

```bash
docker exec mastodon-web bin/tootctl accounts modify username --reset-password
```

### Suspend/Unsuspend User

```bash
# Suspend account
docker exec mastodon-web bin/tootctl accounts suspend username

# Unsuspend account
docker exec mastodon-web bin/tootctl accounts unsuspend username
```

### Delete User Account

```bash
docker exec mastodon-web bin/tootctl accounts delete username
```

## Database Maintenance

### Run Migrations

```bash
docker compose run --rm web bundle exec rails db:migrate
```

### Reindex Database

```bash
docker exec mastodon-postgres psql -U mastodon -d mastodon_production -c "REINDEX DATABASE mastodon_production;"
```

### Check Database Size

```bash
docker exec mastodon-postgres psql -U mastodon -d mastodon_production \
  -c "SELECT pg_size_pretty(pg_database_size('mastodon_production'));"
```

## Backup and Restore

### Full Database Backup

```bash
docker exec mastodon-postgres pg_dump -U mastodon mastodon_production | \
  gzip > backup-$(date +%Y%m%d-%H%M%S).sql.gz
```

### Restore from Backup

```bash
# Stop dependent services
docker compose stop web streaming sidekiq sidekiq-ingress

# Restore database
gunzip < backup.sql.gz | docker exec -i mastodon-postgres \
  psql -U mastodon -d mastodon_production

# Restart services
docker compose up -d
```

### Backup Media Storage

```bash
# If using S3, use AWS CLI
aws s3 sync s3://your-bucket ./backup-s3/

# For local backups, adjust docker-compose.yml volume mount as needed
```

## Viewing Logs

### All Services

```bash
# Follow all logs
docker compose logs -f

# Last 100 lines
docker compose logs --tail=100
```

### Specific Service

```bash
# Web application
docker logs -f mastodon-web

# Job processor
docker logs -f mastodon-sidekiq

# Streaming server
docker logs -f mastodon-streaming
```

### Search Logs

```bash
# Find errors in web logs
docker logs mastodon-web 2>&1 | grep -i error

# Recent PostgreSQL errors
docker logs mastodon-postgres 2>&1 | tail -50
```

## Cache Management

### Clear Redis Cache

```bash
docker exec mastodon-redis redis-cli FLUSHALL
```

### Restart Redis

```bash
docker compose restart redis
```

## Media & Assets

### Precompile Assets

```bash
docker compose run --rm web bundle exec rails assets:precompile
```

### Clear Old Cache

```bash
# Remove orphaned media
docker exec mastodon-web bin/tootctl media remove --days=7

# Remove preview cards
docker exec mastodon-web bin/tootctl preview_cards remove --days=7
```

## Service Management

### Restart All Services

```bash
docker compose restart
```

### Restart Specific Service

```bash
docker compose restart web
docker compose restart streaming
docker compose restart sidekiq
```

### Stop All Services

```bash
docker compose stop
```

### Remove All Containers (Keep Volumes)

```bash
docker compose down
```

### Full Reset (Delete Everything)

```bash
docker compose down -v  # ⚠️ WARNING: Deletes all data!
```

## Updates and Upgrades

### Check for Updates

```bash
docker compose pull
```

### Update Mastodon

```bash
# Pull new images
docker compose pull

# Stop services
docker compose stop

# Run migrations
docker compose run --rm web bundle exec rails db:migrate

# Precompile assets
docker compose run --rm web bundle exec rails assets:precompile

# Start services
docker compose up -d
```

## Admin Console

### Rails Console

Access the Rails console for advanced operations:

```bash
docker exec -it mastodon-web bin/rails console
```

Examples:
```ruby
# Get user count
User.count

# Find user by email
User.find_by(email: 'user@stranger.social')

# Send test email
UserMailer.welcome(User.first).deliver_now
```

---

**Last Updated:** October 23, 2025
