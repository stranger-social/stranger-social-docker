# Architecture Overview

System design, services, and data storage for Mastodon Docker deployment.

## System Architecture

```
┌─────────────────────────────────────────────────────┐
│                   External Users                     │
│              (Internet / Fediverse)                  │
└────────────────────┬────────────────────────────────┘
                     │ HTTPS (80/443)
                     ▼
        ┌────────────────────────┐
        │    Nginx (Reverse      │
        │    Proxy / SSL Term.)   │
        └────────────────────────┘
          │                    │
          ├─ Port 3000 ───────┤
          │                   │
          ▼                   ▼
    ┌──────────┐        ┌───────────┐
    │   Web    │        │ Streaming │
    │ (Puma)   │        │ (Node.js) │
    └──────────┘        └───────────┘
          │                   │
          └──────────┬────────┘
                     │
    ┌────────────────┼────────────────┐
    │                │                │
    ▼                ▼                ▼
┌────────────┐  ┌────────────┐  ┌────────────┐
│ PostgreSQL │  │   Redis    │  │ Sidekiq    │
│  Database  │  │ (Cache &   │  │ (Async     │
│            │  │  Queues)   │  │  Jobs)     │
└────────────┘  └────────────┘  └────────────┘
                                       │
    ┌──────────────────────────────────┘
    │
    ▼
┌────────────┐
│ S3-compat. │
│  Storage   │
│(Media/Docs)│
└────────────┘
```

## Services

### Nginx (Reverse Proxy)
- **Purpose:** Front-facing HTTP/HTTPS proxy
- **Ports:** 80 (HTTP), 443 (HTTPS)
- **Configuration:** `nginx/conf.d/default.conf`, `nginx/nginx.conf`
- **SSL:** Certificates at `certbot/live/stranger.social/`
- **Upstream Targets:** Web (3000), Streaming (4000)

### Web (Mastodon Rails App)
- **Purpose:** Main Mastodon application (Puma server)
- **Port:** 3000 (internal only)
- **Image:** `ghcr.io/mastodon/mastodon:v4.5.3`
- **Key Tasks:**
  - Handle HTTP requests
  - Serve web UI and API endpoints
  - Process account authentication
  - Manage media uploads
- **Workers:** Configurable via `PUMA_WORKERS` env var

### Streaming (WebSocket Server)
- **Purpose:** Real-time WebSocket streaming
- **Port:** 4000 (internal only)
- **Language:** Node.js
- **Key Tasks:**
  - Timeline updates
  - Notification streaming
  - Conversation updates
  - Live UI updates

### Sidekiq (Background Job Processor)
- **Purpose:** Asynchronous job processing
- **Multiple Instances:** 
  - `sidekiq` (default queue)
  - `sidekiq-ingress` (ingress/federation queue)
- **Key Tasks:**
  - Email delivery
  - Activity Pub federation
  - Media processing
  - Report handling
  - Cleanup tasks

### PostgreSQL Database
- **Purpose:** Primary data storage
- **Port:** 5432 (internal only)
- **Version:** 15
- **Volume:** `postgres-data`
- **Data Includes:**
  - Accounts and profiles
  - Statuses (posts)
  - Relationships and follows
  - Preferences and settings
  - Encryption keys

### Redis
- **Purpose:** Caching and job queue storage
- **Port:** 6379 (internal only)
- **Version:** 7
- **Volume:** `redis-data`
- **Key Purposes:**
  - Sidekiq job queue
  - Session cache
  - Rate limiting
  - Timeline caching
  - Temporary locks

## Data Storage

### Volumes (Docker Managed)

| Volume | Service | Purpose | Persistence |
|--------|---------|---------|-------------|
| `/var/lib/postgresql/data` | postgres | Database files (local disk) | Permanent |
| `redis-data` | redis | Cache database | Temporary (can rebuild) |
| `mastodon-public` | web | Precompiled assets | Permanent |

**Note:** The postgres service uses a bind mount to local disk (`/var/lib/postgresql/data`) for better performance and easier backup management, rather than a Docker-managed volume.

### External Storage

**S3-Compatible Object Storage:**
- **Purpose:** Media files, uploads, backups
- **Provider Agnostic:** Works with AWS S3, Linode Objects, MinIO, etc.
- **Configuration:** `S3_BUCKET`, `S3_HOSTNAME`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`
- **Contents:**
  - User avatars
  - Header images
  - Media attachments
  - Custom emojis
  - Backup archives

## Network Architecture

### Internal Docker Network
- Services communicate via container names (DNS resolution)
- Web connects to: postgres, redis, sidekiq
- Streaming connects to: redis
- Sidekiq connects to: postgres, redis
- No services exposed externally except nginx

### Port Mapping
- **External:** nginx binds to host ports 80/443
- **Internal:** Web (3000), Streaming (4000), postgres (5432), redis (6379) bound only to 127.0.0.1 for internal access

### Service Discovery
- Container names used as hostnames
- `.env` variables reference container names: `DB_HOST=postgres`, `REDIS_HOST=redis`

## Data Flow

### User Request Flow
1. User browser connects to nginx on 443 (HTTPS)
2. Nginx terminates SSL/TLS
3. Routes to appropriate service:
   - `/api/*` → Web (3000)
   - `/streaming` → Streaming (4000)
   - Static files → Nginx cache
4. Web service queries PostgreSQL and Redis
5. Response returned through nginx to user

### Background Job Flow
1. Web application enqueues job to Redis
2. Sidekiq monitors Redis queue
3. Sidekiq processes job (email, federation, media, etc.)
4. Updates PostgreSQL with results
5. Signals streaming service if needed for live updates

### Media Upload Flow
1. User uploads file through web interface
2. Web stores file in S3-compatible storage
3. Records reference in PostgreSQL
4. Returns media URL to user
5. CDN or direct S3 access serves media files

## Environment Separation

All configuration via `.env` file:
- Secrets (keys, passwords) never committed
- Same image used for all environments
- Configuration determines behavior

## Scaling Considerations

### Horizontal Scaling
- Multiple web instances possible (load balance across them)
- Multiple Sidekiq instances for different queues
- Separate Redis for Sidekiq if high queue volume

### Vertical Scaling
- Increase `PUMA_WORKERS` for more web concurrency
- Increase container resource limits for more memory
- Database tuning for large instances

### Performance Optimization
- Redis for caching reduces database load
- Sidekiq for async tasks prevents web blocking
- Streaming server handles many concurrent connections
- Database indexing for common queries

## Backup & Disaster Recovery

### Critical Data
- **PostgreSQL database:** User data, relationships, configuration
- **Redis:** Can be rebuilt from PostgreSQL
- **S3 storage:** Media files (loss = missing images)

### Backup Strategy
- PostgreSQL: Daily backups using `pg_dump`
- S3 files: Sync regularly or use provider backup
- Redis: Not critical (can rebuild from database)

### Recovery Procedure
1. Restore PostgreSQL from backup
2. Run database migrations if needed
3. Verify S3 storage intact
4. Restart services
5. Validate system health

---

**Last Updated:** October 23, 2025
