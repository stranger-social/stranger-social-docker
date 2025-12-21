# Security & Safe Query Policy

## Overview

The **Mastodon Admin Toolkit** is designed as a **safe-by-design** monitoring solution that provides high-level visibility into instance health, federation status, and safety signals—**without exposing sensitive user data**.

This policy explicitly defines what queries are allowed, what data they can expose, and what is strictly forbidden.

## Core Principles

### 1. Privacy First
- No query output contains personally identifiable information (PII)
- No user emails, usernames, or personal details in any query result
- No direct user behavioral tracking or timelines

### 2. Aggregate Only
- All metrics are aggregated counts or statistical summaries
- No per-user or per-post analysis
- Domain-level federation analysis, never individual account inspection

### 3. Transparent Configuration
- All access is controlled via environment variables
- Admins can toggle strict "safe mode" to disable any potentially sensitive queries
- Configuration is documented and auditable

### 4. No Content Exposure
- No status text, DM content, or post content in query results
- No raw access logs or full SQL text of long-running queries

---

## Allowed Query Categories

### ✅ Adoption & Activity Metrics

**Safe metrics:**
- Daily/weekly active user counts (aggregate)
- New user signup counts (aggregate)
- Post creation volumes (no content inspection)
- Media attachment counts and types
- Follow relationships (counts only, no user details)

**Example queries:**
- "Active users per day (last 90 days)"
- "New signups by confirmation status"
- "Posts created per day by visibility level"
- "Media uploads by type (image/video/audio)"

**Why safe:** These queries show instance vitality without revealing who did what.

---

### ✅ Federation Health

**Safe metrics:**
- Remote instance domain names and account counts
- Remote status volume by domain (not by user)
- "Dead instance" heuristics (domains with old data)
- New federated domains discovered
- Domain block status and severity

**Example queries:**
- "Top 50 remote instances by account count"
- "Remote domain activity (last 7/30 days)"
- "Potentially inactive instances (no activity in 90 days)"
- "New federated domains added"

**Why safe:** Federation happens at the domain level; analyzing it this way is safe and useful.

**NOT allowed in federation queries:**
- ❌ Per-remote-user activity traces
- ❌ Individual account discovery from remote domains
- ❌ Detailed interaction graphs (who follows whom)

---

### ✅ Safety & Moderation Signals

**Safe metrics:**
- Abuse report volume (counts only, no content)
- Account suspension/silencing counts
- Domain block inventory
- Signup rate trends (abuse pattern detection)
- Approval queue summary (pending, aging, resolved)
- Block/mute aggregate counts

**Example queries:**
- "Reports submitted per day (last 30 days)"
- "Suspended/silenced account counts"
- "New signups spike detection (by domain)"
- "Pending approval queue aging"

**Why safe:** Aggregate counts help detect abuse patterns without exposing victim/reporter details.

**NOT allowed in safety queries:**
- ❌ Report content or context
- ❌ Reporter identity or email
- ❌ Reported user identity or email
- ❌ Full report investigation data

---

### ✅ Database Health & Performance

**Safe metrics:**
- Table sizes and row counts
- Index usage and bloat indicators
- Autovacuum activity stats
- Connection pool status
- Cache hit ratios
- Replication lag (if applicable)
- Database size summary

**Example queries:**
- "Largest tables by disk usage"
- "Table row counts and growth"
- "Index health and usage patterns"
- "Database cache hit ratio"
- "Autovacuum activity"

**Why safe:** These are pure infrastructure metrics with zero user data exposure.

**NOT allowed in DB queries:**
- ❌ Full SQL text of long-running queries (preview OK, redacted)
- ❌ User-specific data (e.g., user_id joins, per-account stats)

---

### ✅ Infrastructure Visibility

**Safe metrics:**
- CPU, memory, disk usage (overall)
- Docker container status and resource use
- Top processes by resource consumption
- Network connection aggregates (by state)
- Disk usage by mount point
- Open listening ports
- System load average

**Example queries:**
- "System resource usage summary"
- "Docker container status"
- "Top processes by CPU/memory"
- "Disk usage by mount point"
- "Active listening ports"

**Why safe:** These are standard sysadmin metrics that do not expose user data.

**NOT allowed in infra queries:**
- ❌ Full remote IP lists or per-client connections
- ❌ User session IP addresses
- ❌ Detailed network packet inspection

---

## Forbidden Query Patterns

### ❌ Status/Post Content Access
```sql
-- FORBIDDEN: Exposes post text
SELECT statuses.text FROM statuses;

-- FORBIDDEN: Analyzes post content for keywords
SELECT * FROM statuses WHERE text ILIKE '%banned-word%';

-- ALLOWED: Counts posts only
SELECT COUNT(*) FROM statuses WHERE created_at >= NOW() - INTERVAL '7 days';
```

### ❌ Direct Message Content
```sql
-- FORBIDDEN: Any query touching DM content
SELECT * FROM statuses WHERE visibility = 'direct';
```

### ❌ Email & Account Details
```sql
-- FORBIDDEN: Exposes email addresses
SELECT users.email FROM users;

-- FORBIDDEN: Links accounts to personal info
SELECT accounts.username, accounts.display_name FROM accounts;

-- ALLOWED: Aggregate user counts
SELECT COUNT(*) FROM users WHERE local = true;
```

### ❌ Per-User Activity Trails
```sql
-- FORBIDDEN: User X timeline
SELECT statuses.* FROM statuses WHERE account_id = 123;

-- FORBIDDEN: User X followers
SELECT accounts.* FROM follows WHERE target_account_id = 123;

-- ALLOWED: Follower count (aggregate)
SELECT COUNT(*) FROM follows WHERE target_account_id = 123;
```

### ❌ User IP Addresses Tied to Accounts
```sql
-- FORBIDDEN: Expose user IP + identity
SELECT users.current_sign_in_ip, users.email FROM users;

-- FORBIDDEN: Remote IP per account
SELECT accounts.*, connection_ip FROM accounts;

-- ALLOWED: Aggregate IPs by country/ASN (if available)
SELECT remote_ips_aggregated FROM network_stats WHERE period = '7d';
```

### ❌ Raw Access Log Dumps
```sql
-- FORBIDDEN: Full request logs
SELECT * FROM access_logs;

-- ALLOWED: Aggregate request counts
SELECT COUNT(*) FROM access_logs WHERE created_at >= NOW() - INTERVAL '24 hours';
```

### ❌ Internal Hostnames/IPs in Public Outputs
```sql
-- FORBIDDEN: If running queries that expose internal IPs
SELECT * FROM network_config WHERE internal_ip IS NOT NULL;

-- ALLOWED: If running behind a reverse proxy and hiding internals
SELECT 'Safe: All traffic through reverse proxy' as status;
```

---

## Safe Mode Configuration

### Enabling Strict Safe Mode

By default, **all queries in this toolkit are safe**. However, if you want additional restrictions:

```bash
# In .env:
ADMIN_TOOLKIT_SAFE_MODE=true          # Enable (default)
ADMIN_TOOLKIT_REDACT_REMOTE_IPS=true  # Redact IP addresses (default)
```

**When ADMIN_TOOLKIT_SAFE_MODE=true:**
- Queries that could be misused are disabled or further sanitized
- Results are automatically redacted (e.g., IP addresses aggregated to /24)
- Error handling is more conservative

### Disabling Safe Mode (Advanced)

For trusted admins in fully-private deployments, you can disable safe mode:

```bash
# ONLY in fully-private, security-hardened environments:
ADMIN_TOOLKIT_SAFE_MODE=false
```

**Warning:** This is not recommended for public-facing instances.

---

## IP Address Handling

### When Showing Network Data

If displaying remote IP addresses in network-related queries:

1. **Default (Redacted):** Aggregate to `/24` CIDR blocks
   ```
   ✅ 192.168.1.0/24 (count: 42)
   ```

2. **Alternative:** Show ASN + country instead
   ```
   ✅ AS12345 (United States): 42 connections
   ```

3. **Never:** Show individual IPs tied to user sessions
   ```
   ❌ 192.168.1.42 (username: alice@example.com)
   ```

---

## Adding New Queries

### Checklist for Safe Queries

Before adding a new query, verify:

- [ ] **No PII:** Does it output email, username, or personal details? → ❌ **Not allowed**
- [ ] **No Content:** Does it access post text, DM content, or report data? → ❌ **Not allowed**
- [ ] **No Per-User Trails:** Does it link activity to individuals? → ❌ **Not allowed**
- [ ] **Aggregated:** Is the result a count, average, or category? → ✅ **Allowed**
- [ ] **Documented:** Is the purpose clear and safety rationale documented? → ✅ **Required**
- [ ] **Configuration:** Can the query be toggled via env vars if sensitive? → ✅ **Preferred**

### Query Template

```sql
-- Query Name: [descriptive-name]
-- Category: [adoption|federation|safety|db|infra]
-- Safe: [brief safety justification]
-- No PII: [Yes/No] | No Content: [Yes/No] | Aggregated: [Yes/No]

query "[descriptive_name]" {
  title       = "Human-readable title"
  description = "What this query shows and why it's safe"
  sql         = <<-EOT
    SELECT ...
  EOT
}
```

---

## Audit & Compliance

### Regular Review

- All new queries are code-reviewed against this policy
- Queries are tagged with their category (adoption, federation, safety, db, infra)
- Queries can be enabled/disabled via configuration

### Transparency

- This policy is public and documented
- Users can inspect the query definitions in `queries/`
- Environment variables control what is collected and exposed

### Incident Response

If a query accidentally exposes sensitive data:

1. **Immediate:** Disable the query via configuration
2. **Investigation:** Review logs to determine scope
3. **Remediation:** Update the query or remove it
4. **Notification:** Inform admins if user data was exposed

---

## Questions & Escalation

### Is this query safe?

Use the **Forbidden Query Patterns** section above. If unsure:

1. Check if it exposes **PII** (email, username, IP tied to user)
2. Check if it reads **content** (posts, DMs, reports)
3. Check if it shows **per-user activity trails**
4. Check if it includes **raw logs or internal IPs**

If any of the above: ❌ **Not safe**

Otherwise: ✅ **Likely safe** (but review with team)

### Can I add a custom query?

Yes! Follow the **Adding New Queries** checklist and submit a PR or issue.

### What if my instance has custom requirements?

Environment variables allow customization:

```bash
# .env
ADMIN_TOOLKIT_SAFE_MODE=true/false
ADMIN_TOOLKIT_REDACT_REMOTE_IPS=true/false
```

---

## References

- [Mastodon Official Documentation](https://docs.joinmastodon.org/)
- [Mastodon Admin Guide](https://docs.joinmastodon.org/admin/)
- [Steampipe Documentation](https://steampipe.io/docs/)

---

**Last Updated:** December 2025  
**Version:** 1.0  
**Status:** Safe-by-design, production-ready
