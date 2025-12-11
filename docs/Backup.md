# PostgreSQL Backup & Restore Guide

This guide explains how to use the built-in backup service (`postgres-backup`) in your Mastodon Docker stack to safely back up and restore your PostgreSQL database.

## Overview

- Automated daily backups using `prodrigestivill/postgres-backup-local` Docker image
- Manual backups on demand
- Local backup retention (only the most recent backups are kept)
- Easy restore process

## Backup Service Details

The backup service is defined in `docker-compose.yml` as:

```yaml
  postgres-backup:
    image: prodrigestivill/postgres-backup-local
    container_name: mastodon-postgres-backup
    restart: always
    environment:
      - POSTGRES_HOST=postgres
      - POSTGRES_DB=${DB_NAME}
      - POSTGRES_USER=${DB_USER}
      - POSTGRES_PASSWORD=${DB_PASSWORD}
      - SCHEDULE=@daily           # daily backup at midnight
      - BACKUP_KEEP_DAYS=3        # keep backups for 3 days
      - BACKUP_KEEP_FILES=3       # keep only 3 backup files
      - BACKUP_DIR=/backups
      - TZ=UTC
    volumes:
      - ./pgbackups:/backups   # host directory for backups
    depends_on:
      - postgres
    networks:
      - mastodon
```

Backups are stored in `pgbackups/` on your host. Only the latest backups are retained to save disk space.

## Automated Backups

Backups are created automatically every day at midnight (UTC) by default. You can change the schedule by editing the `SCHEDULE` environment variable in `docker-compose.yml`.

## Manual Backup

To trigger a manual backup at any time:

```bash
docker exec mastodon-postgres-backup /backup.sh
```

This will immediately create a new backup in `pgbackups/last/`.

## Backup Retention

- Only the most recent backups are kept (see `BACKUP_KEEP_DAYS` and `BACKUP_KEEP_FILES`)
- Backups are organized in subfolders:
  - `pgbackups/last/` — all backups
  - `pgbackups/daily/` — latest backup for each day
  - `pgbackups/weekly/` — latest backup for each week
  - `pgbackups/monthly/` — latest backup for each month
- Symlinks are created for easy access to the latest backup:
  - `pgbackups/last/DB-latest.sql.gz`

## Restore from Backup

To restore the latest backup:

```bash
zcat pgbackups/last/DB-latest.sql.gz | docker exec -i mastodon-postgres psql -U mastodon -d mastodon_production --clean
```

To restore a specific backup file:

```bash
zcat pgbackups/last/DB-YYYYMMDD-HHmmss.sql.gz | docker exec -i mastodon-postgres psql -U mastodon -d mastodon_production --clean
```

## Best Practices

- Monitor available disk space in `pgbackups/` regularly
- Test restores periodically to ensure backup integrity
- Consider offsite or cloud backup for disaster recovery
- Never commit backup files to git (use `.gitignore`)

## References

- [prodrigestivill/docker-postgres-backup-local](https://github.com/prodrigestivill/docker-postgres-backup-local)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)

---

For troubleshooting and advanced options, see the official backup image documentation and your instance's `docs/Troubleshooting.md`.
