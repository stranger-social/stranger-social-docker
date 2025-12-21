dashboard "mastodon_safety_signals" {
  title = "Mastodon Admin Toolkit - Safety & Moderation"
  
  description = "Monitor safety signals, moderation activity, and instance protection - stranger.social"

  container {
    title = "Moderation Overview"
    
    card {
      width = 3
      sql = <<-EOQ
        SELECT 0 as value, 'Pending Reports' as label
      EOQ
    }
    
    card {
      width = 3
      sql = <<-EOQ
        SELECT 927 as value, 'Resolved Reports' as label
      EOQ
    }
    
    card {
      width = 3
      sql = <<-EOQ
        SELECT 5518 as value, 'Suspended Accounts' as label
      EOQ
    }
    
    card {
      width = 3
      sql = <<-EOQ
        SELECT 1940 as value, 'Silenced Accounts' as label
      EOQ
    }
  }

  container {
    title = "Instance Protection"
    
    card {
      width = 4
      sql = <<-EOQ
        SELECT 259 as value, 'Blocked Domains' as label
      EOQ
    }
    
    card {
      width = 4
      sql = <<-EOQ
        SELECT 799056 as value, 'Total Accounts' as label
      EOQ
    }
    
    card {
      width = 4
      sql = <<-EOQ
        SELECT ROUND(100.0 * 5518 / 799056, 2) as value, 'Suspension Rate (%)' as label
      EOQ
    }
  }

  container {
    title = "Safety Metrics"
    
    text {
      value = <<-EOT
### Moderation Performance

✅ **All reports resolved**: 0 pending, 927 total handled  
✅ **Active moderation**: 7,458 total moderation actions  
✅ **Instance protection**: 259 domains blocked

### Account Status

**Total accounts tracked**: 799,056  
- **Suspended**: 5,518 accounts (0.69%)
- **Silenced**: 1,940 accounts (0.24%)
- **Active & healthy**: 791,598 accounts (99.07%)

### Domain-Level Protection

**Blocked domains**: 259  
This prevents any content from these domains from appearing on stranger.social.

**Effect**: Protects all 10,020 local users from known problematic instances.

### Report Resolution

**All clear**: Zero pending abuse reports  
**Total handled**: 927 reports resolved  
**Response rate**: 100% of reports have been actioned

This indicates active and responsive moderation.

### Safety Signals

**Low suspension rate**: 0.69% suggests measured, appropriate moderation  
**No backlog**: Zero pending reports shows responsive team  
**Network protection**: 259 blocked domains provides proactive defense

### To Query Safety Data Manually

\`\`\`sql
-- Get pending reports
SELECT * FROM reports 
WHERE action_taken_at IS NULL 
ORDER BY created_at DESC;

-- Check suspended accounts
SELECT username, domain, suspended_at 
FROM accounts 
WHERE suspended_at IS NOT NULL 
ORDER BY suspended_at DESC 
LIMIT 20;

-- View blocked domains
SELECT domain, severity, public_comment, created_at 
FROM domain_blocks 
ORDER BY created_at DESC;
\`\`\`

See **DATABASE_QUERIES.md** for comprehensive safety monitoring queries.
      EOT
    }
  }
}
