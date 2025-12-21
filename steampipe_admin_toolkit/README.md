# Mastodon Admin Toolkit (Steampipe)

A **safe-by-design** monitoring and administration toolkit for Mastodon instances, powered by [Steampipe](https://steampipe.io) and [Powerpipe](https://powerpipe.io).

**Mission:** Provide admins with high-level visibility into instance health, federation status, and content analysis—**without exposing sensitive user data**.

---

## 🎯 Current Status

**Version:** 1.0.0  
**Last Updated:** December 20, 2025  
**Status:** ✅ Operational

### What's Working

- ✅ **Steampipe v1.1.4** with embedded PostgreSQL
- ✅ **Powerpipe v1.4.2** dashboard server on port 8080
- ✅ **Mastodon Plugin v1.3.0** - 26 API tables, 56 queries
- ✅ **RSS Plugin v1.2.0** - RSS feed integration
- ✅ **Mastodon Insights Mod** - Official Turbot mod for Mastodon reading/analysis
- ✅ **Network Access** to Mastodon API

### Architecture

```
┌──────────────────────────────────────┐
│  Powerpipe Server (Port 8080)        │
│  - Mastodon Insights Mod             │
│  - Dashboard UI                      │
└───────────────┬──────────────────────┘
                │
                ▼
┌──────────────────────────────────────┐
│  Steampipe Service (Port 9193)       │
│  - Embedded PostgreSQL               │
│  - Plugin Manager                    │
└───────────────┬──────────────────────┘
                │
        ┌───────┴────────┐
        ▼                ▼
  ┌──────────┐     ┌─────────┐
  │ Mastodon │     │   RSS   │
  │  Plugin  │     │ Plugin  │
  │  v1.3.0  │     │ v1.2.0  │
  └────┬─────┘     └─────────┘
       │
       ▼
┌──────────────────────────────────────┐
│ Mastodon Instance API                │
│ https://stranger.social              │
└──────────────────────────────────────┘
```

---

## 🚀 Quick Start

### Prerequisites

- Docker & Docker Compose
- Mastodon admin account with API token
- Network access to your Mastodon instance
- ~2GB disk space for Steampipe plugins/cache

### 1. Copy Configuration

```bash
cd steampipe_admin_toolkit/
cp .env.example .env
```

### 2. Get Mastodon API Token

Log in to your Mastodon instance as an admin user:

1. Navigate to **Settings → Development → New Application**
2. Name: "Steampipe Admin Toolkit"
3. Scopes: `read:accounts`, `read:reports`, `read:statuses`, `read:federation`
4. Click "Submit"
5. **Copy the Access Token**

### 3. Configure Environment

Edit `.env` and configure:

```env
# Mastodon API Configuration
MASTODON_SERVER=https://stranger.social
MASTODON_ADMIN_API_TOKEN=your_token_from_step_2

# Optional: Direct database access
MASTODON_DB_HOST=postgres
MASTODON_DB_PASSWORD=your_db_password  # From main .env
```

### 4. Start Services

```bash
docker compose up -d
```

Wait for services to initialize (~30 seconds):

```bash
docker compose logs steampipe -f
```

Look for:
```
Starting Steampipe...
Plugins: mastodon (v1.3.0), rss (v1.2.0)
Dashboard server started at: http://localhost:8080
```

### 5. Access Dashboard

Open your browser to: **http://localhost:8080**

Available views from the **Mastodon Insights** mod:
- Home timeline feed
- Local & remote timelines
- Notifications, favorites, bookmarks
- Search (people, statuses, tags)
- Federation graphs & relationships
- Server statistics

---

## 🔍 Using the Toolkit

### Via Dashboard (Recommended)

1. Open **http://localhost:8080**
2. Browse available dashboards in the **Mastodon Insights** mod
3. View timelines, search, analyze federation

The dashboard provides a "Bloomberg terminal for Mastodon" - text-only, focused on content and analysis.

### Via Command Line

**List available tables:**
```bash
docker compose exec -u steampipe steampipe steampipe query ".tables"
```

**Query Mastodon data:**
```bash
# Get account count
docker compose exec -u steampipe steampipe steampipe query \
  "SELECT COUNT(*) as accounts FROM mastodon_account;"

# Find top federated instances
docker compose exec -u steampipe steampipe steampipe query \
  "SELECT domain, COUNT(*) FROM mastodon_account WHERE domain IS NOT NULL GROUP BY domain ORDER BY COUNT(*) DESC LIMIT 10;"

# Get server info
docker compose exec -u steampipe steampipe steampipe query \
  "SELECT * FROM mastodon_server;"
```

**Export to JSON/CSV:**
```bash
docker compose exec -u steampipe steampipe steampipe query \
  --output json \
  "SELECT * FROM mastodon_server;" > server_info.json
```

---

## 📊 Available Mastodon Tables

The Mastodon plugin provides access to **26 API tables**:

### Account & Social
- `mastodon_account` - Account information
- `mastodon_account_field` - Custom profile fields
- `mastodon_follow_request` - Pending follows
- `mastodon_block`, `mastodon_mute` - Blocked/muted users
- `mastodon_bookmark` - Bookmarked posts

### Content
- `mastodon_status` - Posts/statuses
- `mastodon_media_attachment` - Media files
- `mastodon_mention` - Mentions in posts
- `mastodon_search_account` - Account search results

### Federation & Instance
- `mastodon_instance` - Instance information
- `mastodon_peer` - Federated peers
- `mastodon_domain_block` - Domain blocks (admin)

### Moderation & Safety
- `mastodon_report` - Abuse reports (admin)
- `mastodon_announcement` - Instance announcements
- `mastodon_rule` - Instance rules
- `mastodon_custom_emoji` - Custom emojis

### Lists & Organization
- `mastodon_list` - User-created lists
- `mastodon_featured_tag` - Featured hashtags
- `mastodon_filter` - Content filters

### Other
- `mastodon_notification` - Notifications
- `mastodon_conversation` - Direct messages
- `mastodon_app` - OAuth applications
- `mastodon_marker`, `mastodon_preference`, `mastodon_push_subscription`

**See:** [Mastodon Plugin Documentation](https://hub.steampipe.io/plugins/turbot/mastodon)

---

## 🔧 Configuration Reference

### Environment Variables

#### Mastodon API (Required)

```env
MASTODON_SERVER=https://stranger.social
MASTODON_ADMIN_API_TOKEN=your_api_token_here
```

#### Database Connection (Optional)

```env
MASTODON_DB_HOST=postgres
MASTODON_DB_PORT=5432
MASTODON_DB_NAME=mastodon_production
MASTODON_DB_USER=mastodon
MASTODON_DB_PASSWORD=your_db_password
MASTODON_DB_SSLMODE=disable
```

#### Safety Controls

```env
# Enable safe mode - restricts queries to aggregate-only
ADMIN_TOOLKIT_SAFE_MODE=true

# Redact remote IP addresses
ADMIN_TOOLKIT_REDACT_REMOTE_IPS=true
```

#### Service Behavior

```env
# Log level
STEAMPIPE_LOG_LEVEL=info

# Disable update checks
STEAMPIPE_UPDATE_CHECK=false
```

---

## 🐛 Troubleshooting

### Services Won't Start

```bash
# Check logs
docker compose logs steampipe

# Restart services
docker compose restart steampipe
```

### Dashboard Not Loading

```bash
# Check if port 8080 is accessible
curl http://localhost:8080

# If fails: Check firewall/proxy settings
```

### API Token Issues

```bash
# Verify token is configured
docker compose exec steampipe env | grep MASTODON_ACCESS_TOKEN

# If empty: Update .env and restart
docker compose restart steampipe
```

### Plugins Not Working

```bash
# Check installed plugins
docker compose exec -u steampipe steampipe steampipe plugin list

# Should show: mastodon (v1.3.0), rss (v1.2.0)
```

### Permission Denied Errors

```bash
# Always run as steampipe user, not root:
docker compose exec -u steampipe steampipe steampipe query "..."
```

---

## 🔄 Maintenance

### Update Plugins

```bash
docker compose exec -u steampipe steampipe steampipe plugin update mastodon
docker compose exec -u steampipe steampipe steampipe plugin update rss
docker compose restart steampipe
```

### Update Mods

```bash
# The Mastodon Insights mod is automatically updated
# To manually pull latest:
cd workspace/mods/mastodon_insights
git pull origin main
docker compose restart steampipe
```

### Backup Configuration

```bash
# Backup .env configuration
cp .env .env.backup-$(date +%Y%m%d)

# Backup volumes
docker compose down
tar czf steampipe-backup-$(date +%Y%m%d).tar.gz \
  steampipe_plugins/ steampipe_db/ steampipe_cache/
docker compose up -d
```

### Monitor Service Health

```bash
# Check container status
docker compose ps

# View recent logs
docker compose logs steampipe --tail 50 -f

# Check plugin status
docker compose exec -u steampipe steampipe steampipe plugin list
```

---

## 🔒 Security & Privacy

This toolkit is designed with **privacy-first principles**:

✅ **API-Based Access** - Uses read-only API tokens, not direct database access  
✅ **Safe by Default** - Safe mode enabled to restrict sensitive queries  
✅ **No PII Exposure** - Queries designed for aggregate analysis only  
✅ **Transparent** - All queries visible and auditable  
✅ **Configurable** - Safety controls via environment variables

**See [SECURITY.md](SECURITY.md) for complete security policy.**

### Best Practices

1. **Restrict API Token Scopes** - Only grant needed permissions
2. **Enable Safe Mode** - `ADMIN_TOOLKIT_SAFE_MODE=true` (default)
3. **Firewall Access** - Limit port 8080 to trusted IPs only
4. **Review Queries** - Audit custom queries before deployment
5. **Rotate Tokens** - Periodically regenerate API tokens

---

## 📚 Additional Resources

### Documentation
- [SECURITY.md](SECURITY.md) - Security policy and safe query guidelines
- [DEPLOYMENT_SUCCESS.md](DEPLOYMENT_SUCCESS.md) - Deployment reference

### External Links
- **Mastodon Insights Mod:** https://github.com/turbot/steampipe-mod-mastodon-insights
- **Mastodon Plugin:** https://hub.steampipe.io/plugins/turbot/mastodon
- **Steampipe Docs:** https://steampipe.io/docs
- **Powerpipe Docs:** https://powerpipe.io/docs
- **Mastodon Admin Guide:** https://docs.joinmastodon.org/admin/

---

## 🤝 Support & Contributing

### Getting Help

```bash
# Check service status
docker compose ps

# View logs
docker compose logs steampipe

# Test configuration
docker compose exec -u steampipe steampipe steampipe query "SELECT version()"
```

### Report Issues

Found a bug or have a feature request?

1. **Do not open a public issue** for security vulnerabilities
2. **Email:** security@stranger.social
3. **Include:** Issue description, steps to reproduce, impact

---

## 📄 License

Part of the [stranger-social/mastodon-docker](https://github.com/stranger-social/mastodon-docker) project.

---

## Version History

**1.0.0** (December 2025)
- Steampipe v1.1.4 with embedded PostgreSQL
- Powerpipe v1.4.2 dashboard server
- Mastodon Plugin v1.3.0 (26 tables, 56 queries)
- RSS Plugin v1.2.0
- Mastodon Insights mod integration
- Safe-by-design security policy

---

**Built for privacy. Designed for admins. Powered by Steampipe.**
