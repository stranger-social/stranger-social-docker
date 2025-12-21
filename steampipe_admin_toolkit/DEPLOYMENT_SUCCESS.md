# Steampipe Admin Toolkit - Deployment Success

**Deployment Date:** December 18, 2025  
**Status:** ✅ Running

## Services Running

### Steampipe Service
- **Status:** Running in foreground mode
- **Database Port:** 9193
- **Database Name:** steampipe
- **User:** steampipe
- **Hosts:** 127.0.0.1, ::1, 172.18.0.11, 172.19.0.3
- **Connection:** `postgres://steampipe@127.0.0.1:9193/steampipe`

### Powerpipe Server
- **Status:** Running
- **Port:** 8080
- **Listen:** network (open)
- **URL:** http://localhost:8080
- **Mod Location:** /workspace (Mastodon Insights)

## Installed Plugins

| Plugin | Version | Status |
|--------|---------|--------|
| turbot/mastodon | 1.3.0 | ✅ Installed |
| turbot/rss | 1.2.0 | ✅ Installed |

## Mastodon Configuration

The Mastodon plugin is configured via environment variables:

- **MASTODON_SERVER:** https://stranger.social
- **MASTODON_ACCESS_TOKEN:** (configured via MASTODON_ADMIN_API_TOKEN)

## Access the Dashboard

1. **Local Access:**
   ```bash
   http://localhost:8080
   ```

2. **From Host Machine:**
   ```bash
   http://<server-ip>:8080
   ```

## Mastodon Insights Mod

The official [Mastodon Insights](https://github.com/turbot/steampipe-mod-mastodon-insights) mod is loaded and ready to use.

### Available Views:
- Home timeline feed
- Local timeline
- Remote (federated) timeline
- Following/Followers
- Notifications
- Search (people, statuses, tags)
- Server information
- User profile ("me")
- Favorites/Boosts
- Lists
- Tag exploration
- Rate limit monitoring

## Architecture

```
┌─────────────────────────────────────────┐
│  Powerpipe Server (Port 8080)           │
│  - Mastodon Insights Mod                │
│  - Dashboard UI                         │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  Steampipe Service (Port 9193)          │
│  - Embedded PostgreSQL                  │
│  - Plugin Manager                       │
└──────────────┬──────────────────────────┘
               │
       ┌───────┴───────┐
       ▼               ▼
┌─────────────┐ ┌─────────────┐
│  Mastodon   │ │  RSS        │
│  Plugin     │ │  Plugin     │
│  v1.3.0     │ │  v1.2.0     │
└──────┬──────┘ └─────────────┘
       │
       ▼
┌─────────────────────────────────────────┐
│  Mastodon Instance API                  │
│  https://stranger.social                │
└─────────────────────────────────────────┘
```

## Technical Details

### Software Versions
- **Steampipe:** v1.1.4 (uses embedded postgres, plugin manager)
- **Powerpipe:** v1.4.2 (dashboard server)
- **Base Image:** debian:bookworm-slim
- **PostgreSQL:** Embedded (provided by Steampipe)

### Container Configuration
- **Image:** steampipe-custom:latest (built from Dockerfile)
- **User:** steampipe (UID 10001, non-root)
- **Working Directory:** /workspace
- **Volumes:**
  - `steampipe_plugins` → `/home/steampipe/.steampipe/plugins`
  - `steampipe_db` → `/home/steampipe/.steampipe/db`
  - `steampipe_cache` → `/home/steampipe/.steampipe/cache`
  - `./mastodon-insights` → `/workspace`

### Resource Limits
- **CPU:** 1-2 cores
- **Memory:** 1-2 GB

## Management Commands

### View Logs
```bash
cd /opt/stranger-social-docker/steampipe_admin_toolkit
docker compose logs -f steampipe
```

### Restart Services
```bash
docker compose restart steampipe
```

### Stop Services
```bash
docker compose down
```

### Update Plugins
```bash
docker compose exec steampipe su -s /bin/sh -c 'steampipe plugin update --all' steampipe
```

### Check Plugin Status
```bash
docker compose exec steampipe su -s /bin/sh -c 'steampipe plugin list' steampipe
```

### Check Service Status
```bash
docker compose exec steampipe su -s /bin/sh -c 'steampipe service status' steampipe
```

## Troubleshooting

### Dashboard Not Loading
1. Check if Powerpipe server is running:
   ```bash
   docker compose logs steampipe | grep "Dashboard server started"
   ```

2. Verify port 8080 is not blocked:
   ```bash
   curl http://localhost:8080
   ```

### Plugin Connection Issues
1. Verify MASTODON_ACCESS_TOKEN is set:
   ```bash
   docker compose exec steampipe env | grep MASTODON
   ```

2. Test API connection:
   ```bash
   docker compose exec steampipe su -s /bin/sh -c 'steampipe query "select * from mastodon_my_account"' steampipe
   ```

### Service Won't Start
1. Check for port conflicts:
   ```bash
   netstat -tlnp | grep -E '(8080|9193)'
   ```

2. Review container logs:
   ```bash
   docker compose logs --tail=100 steampipe
   ```

## Next Steps

1. **Open Dashboard:** Navigate to http://localhost:8080
2. **Explore Mastodon Data:** Browse the Mastodon Insights mod dashboards
3. **Customize:** Add additional plugins or modify queries in `/workspace`
4. **Monitor:** Use `docker compose logs -f steampipe` to watch real-time activity

## Resolution Summary

This deployment successfully resolved multiple technical challenges:

1. **Registry Migration:** Moved from deprecated GCP Artifact Registry to GitHub releases
2. **Version Compatibility:** Pinned Steampipe v1.1.4 (removes dashboard, uses new plugin manager) and Powerpipe v1.4.2 (dashboard server)
3. **Plugin Installation:** Successfully installed Mastodon and RSS plugins from new registry
4. **Service Architecture:** Steampipe runs embedded PostgreSQL, Powerpipe connects to it for dashboard serving
5. **Configuration:** Used environment variables for plugin authentication (avoiding config file parse errors)

The toolkit is now fully operational and ready to provide Mastodon instance insights and monitoring.
