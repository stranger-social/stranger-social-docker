#!/bin/sh
set -e

echo "Installing Powerpipe plugins..."
powerpipe plugin install mastodon rss || echo "Plugin installation failed, continuing anyway..."

echo "Starting Powerpipe dashboard..."
exec powerpipe dashboard --listen localhost:9033
