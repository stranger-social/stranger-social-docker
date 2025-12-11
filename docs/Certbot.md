# Certbot & SSL Certificate Management

This guide explains how to use Certbot to obtain, renew, and manage SSL certificates for your Mastodon Docker deployment.

## Overview

- Certbot automates the process of getting and renewing SSL/TLS certificates from Let's Encrypt
- Certificates are required for secure HTTPS access to your Mastodon instance
- Renewal can be manual or automated via cron/systemd

## Obtaining a New Certificate

1. **Install Certbot**
   - On Ubuntu/Debian:
     ```bash
     sudo apt update && sudo apt install certbot
     ```
   - For Docker-based setups, use the official Certbot image or container.

2. **Request a Certificate**
   - For a single domain:
     ```bash
     sudo certbot certonly --webroot -w /opt/stranger-social-docker/certbot/www -d stranger.social
     ```
   - For multiple domains:
     ```bash
     sudo certbot certonly --webroot -w /opt/stranger-social-docker/certbot/www -d stranger.social -d www.stranger.social
     ```
   - Certbot will place certificates in `/opt/stranger-social-docker/certbot/conf/live/stranger.social/`

3. **Configure Nginx**
   - Point your Nginx config to the certificate and key files:
     ```nginx
     ssl_certificate /etc/letsencrypt/live/stranger.social/fullchain.pem;
     ssl_certificate_key /etc/letsencrypt/live/stranger.social/privkey.pem;
     ```

## Renewing Certificates

- Certificates from Let's Encrypt are valid for 90 days.
- Renewal should be performed at least every 60 days to avoid expiration.

### Manual Renewal

```bash
sudo certbot renew --quiet
# or, if using Docker:
docker run --rm -v /opt/stranger-social-docker/certbot/conf:/etc/letsencrypt -v /opt/stranger-social-docker/certbot/www:/var/www/certbot certbot/certbot renew --quiet
```

After renewal, reload Nginx:
```bash
docker compose restart nginx
```

### Automatic Renewal (Recommended)

Add this cron job to your system (as root):

```cron
0 4 * * * certbot renew --quiet && docker compose -f /opt/stranger-social-docker/docker-compose.yml restart nginx
```

- This runs every day at 4 AM, renews certificates if needed, and reloads Nginx.
- Certbot will only renew certificates that are close to expiration.

## Checking Certificate Expiration

```bash
openssl x509 -in /opt/stranger-social-docker/certbot/conf/live/stranger.social/fullchain.pem -text -noout | grep -A2 "Validity"
```

## Troubleshooting

- Check logs in `/var/log/letsencrypt/` for errors
- Ensure port 80 is open and forwarded to the ACME challenge directory (`certbot/www`)
- For DNS-01 challenges, see Certbot documentation
- For more help: [Certbot Docs](https://certbot.eff.org/docs/)

## Best Practices

- Always monitor certificate expiration and renewal logs
- Use strong permissions on certificate files
- Never commit certificates or private keys to git
- Test renewal before relying on automation

---

**See also:**
- [Maintenance.md](./Maintenance.md) for regular renewal steps
- [Nginx configuration](../nginx/conf.d/default.conf) for SSL setup
