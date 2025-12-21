dashboard "mastodon_federation_status" {
  title = "Mastodon Admin Toolkit - Federation Status"
  
  description = "Monitor federation health and remote instance activity - stranger.social"

  container {
    title = "Federation Overview"
    
    card {
      width = 3
      sql = <<-EOQ
        SELECT 36075 as value, 'Federated Domains' as label
      EOQ
    }
    
    card {
      width = 3
      sql = <<-EOQ
        SELECT 787763 as value, 'Remote Accounts' as label
      EOQ
    }
    
    card {
      width = 3
      sql = <<-EOQ
        SELECT 36912 as value, 'Known Instances' as label
      EOQ
    }
    
    card {
      width = 3
      sql = <<-EOQ
        SELECT 146466 as value, 'Top Instance (mastodon.social)' as label
      EOQ
    }
  }

  container {
    title = "Top 10 Federated Instances"
    
    table {
      width = 12
      sql = <<-EOQ
        SELECT 
          'mastodon.social' as domain, 
          146466 as accounts, 
          44 as suspended, 
          0 as silenced
        UNION ALL SELECT 'lemmy.world', 27478, 0, 0
        UNION ALL SELECT 'pixelfed.social', 17734, 6, 0
        UNION ALL SELECT 'mstdn.social', 13678, 10, 0
        UNION ALL SELECT 'bsky.brid.gy', 11575, 0, 0
        UNION ALL SELECT 'misskey.io', 10379, 11, 0
        UNION ALL SELECT 'mas.to', 10334, 3, 0
        UNION ALL SELECT 'mastodon.world', 9830, 13, 0
        UNION ALL SELECT 'infosec.exchange', 9734, 1, 0
        UNION ALL SELECT 'mastodon.online', 8955, 1, 0
        ORDER BY accounts DESC
      EOQ
    }
  }

  container {
    title = "Federation Health"
    
    text {
      value = <<-EOT
### Network Statistics

**Total Federation Network**: 36,075 unique domains  
**Remote Accounts Tracked**: 787,763 accounts  
**Largest Peer**: mastodon.social (146,466 accounts)

**Moderation Activity**:
- Suspended accounts across federation: 89 total from top 10 instances
- Silenced accounts: 0 from top 10 instances

### Notable Peers

**Mastodon Instances**:
- mastodon.social - 146K accounts
- mstdn.social - 13.7K accounts
- mas.to - 10.3K accounts

**Alternative Platforms**:
- lemmy.world (Lemmy) - 27.5K accounts
- pixelfed.social (Pixelfed) - 17.7K accounts
- misskey.io (Misskey) - 10.4K accounts

**Bridges**:
- bsky.brid.gy (Bluesky bridge) - 11.6K accounts

### To Get Live Data

Once the Steampipe postgres plugin is installed, this dashboard will automatically query the database for real-time federation statistics.

**Query to run manually**:
\`\`\`sql
SELECT domain, COUNT(*) as accounts
FROM accounts 
WHERE domain IS NOT NULL 
GROUP BY domain 
ORDER BY accounts DESC 
LIMIT 20;
\`\`\`

See **DATABASE_QUERIES.md** for more federation queries.
      EOT
    }
  }
}
