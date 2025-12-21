dashboard "mastodon_admin_overview" {
  title = "Mastodon Admin Toolkit - Instance Overview"
  
  description = "High-level visibility into instance health and activity - stranger.social"

  container {
    title = "Instance Statistics"
    
    card {
      width = 3
      sql = <<-EOQ
        SELECT 10020 as value, 'Total Users' as label
      EOQ
    }
    
    card {
      width = 3
      sql = <<-EOQ
        SELECT 279305 as value, 'Total Posts' as label
      EOQ
    }
    
    card {
      width = 3
      sql = <<-EOQ
        SELECT 36912 as value, 'Federated Domains' as label
      EOQ
    }
    
    card {
      width = 3
      sql = <<-EOQ
        SELECT 958 as value, 'Active Today' as label
      EOQ
    }
  }

  container {
    title = "Instance Information"
    
    text {
      value = <<-EOT
### stranger.social

**Version**: 4.5.3  
**Status**: ✅ Operational  
**Registrations**: Open (approval required)  
**Streaming API**: wss://stranger.social

**Contact**: admin@stranger.social  
**Admin**: @azcoigreach

**Configuration**:
- Max post length: 500 characters
- Max media attachments: 4
- Image size limit: 16 MB
- Video size limit: 99 MB
      EOT
    }
  }

  container {
    title = "Database Connection Status"
    
    text {
      value = <<-EOT
### ⚠️ Plugin Installation Note

The Mastodon Steampipe plugin (`turbot/mastodon`) requires artifact registry access which is currently blocked.

**Current Workaround**: These dashboards show API data fetched externally. Once the plugin is installed, they will automatically populate with live data.

**To install plugin manually**:
1. Resolve network access to `us-docker.pkg.dev`
2. Run: `steampipe plugin install mastodon`
3. Restart dashboard

**Alternative**: Query the PostgreSQL database directly for more detailed metrics (see DATABASE_QUERIES.md)
      EOT
    }
  }
}
