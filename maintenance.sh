#!/bin/bash

# Mastodon Docker Maintenance Script

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions

show_help() {
    cat << EOF
Mastodon Docker Maintenance Script

Usage: ./maintenance.sh [COMMAND] [OPTIONS]

Commands:
  status                 Show status of all services
  logs [SERVICE]         View logs (default: web)
  backup                 Backup the database
  restore [FILE]         Restore database from backup
  update                 Update to latest images
  restart [SERVICE]      Restart a service
  shell [SERVICE]        Open shell in a service container
  clean                  Clean up dangling images and volumes
  health-check           Run health checks
  media-cleanup          Run media cleanup task
  db-migrate             Run database migrations
  assets-precompile      Precompile Mastodon assets
  help                   Show this help message

Examples:
  ./maintenance.sh status
  ./maintenance.sh logs sidekiq
  ./maintenance.sh backup
  ./maintenance.sh restart web
  ./maintenance.sh shell web

EOF
}

cmd_status() {
    echo -e "${GREEN}=== Service Status ===${NC}"
    docker-compose ps
}

cmd_logs() {
    local service=${1:-web}
    docker-compose logs -f --tail=100 "$service"
}

cmd_backup() {
    local backup_file="mastodon-backup-$(date +%Y%m%d_%H%M%S).sql.gz"
    echo -e "${YELLOW}Creating database backup: $backup_file${NC}"
    docker-compose exec -T postgres pg_dump -U mastodon mastodon_production | gzip > "$backup_file"
    echo -e "${GREEN}Backup created: $backup_file${NC}"
    ls -lh "$backup_file"
}

cmd_restore() {
    local backup_file=$1
    
    if [ -z "$backup_file" ]; then
        echo -e "${RED}Error: Backup file not specified${NC}"
        echo "Usage: ./maintenance.sh restore [BACKUP_FILE]"
        exit 1
    fi
    
    if [ ! -f "$backup_file" ]; then
        echo -e "${RED}Error: Backup file not found: $backup_file${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}WARNING: This will overwrite the current database!${NC}"
    read -p "Continue? (yes/no) " -n 3 -r
    echo
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo "Restore cancelled"
        exit 1
    fi
    
    echo -e "${YELLOW}Restoring from backup: $backup_file${NC}"
    gunzip -c "$backup_file" | docker-compose exec -T postgres psql -U mastodon mastodon_production
    echo -e "${GREEN}Database restored${NC}"
}

cmd_update() {
    echo -e "${YELLOW}Pulling latest images...${NC}"
    docker-compose pull
    
    echo -e "${YELLOW}Stopping current services...${NC}"
    docker-compose down
    
    echo -e "${YELLOW}Starting updated services...${NC}"
    docker-compose up -d
    
    echo -e "${GREEN}Update complete${NC}"
    docker-compose ps
}

cmd_restart() {
    local service=${1:-}
    
    if [ -z "$service" ]; then
        echo -e "${YELLOW}Restarting all services...${NC}"
        docker-compose restart
    else
        echo -e "${YELLOW}Restarting $service...${NC}"
        docker-compose restart "$service"
    fi
    
    sleep 5
    docker-compose ps
}

cmd_shell() {
    local service=${1:-web}
    echo -e "${YELLOW}Opening shell in $service container...${NC}"
    docker-compose exec "$service" /bin/bash
}

cmd_clean() {
    echo -e "${YELLOW}Cleaning up Docker resources...${NC}"
    
    echo "Removing dangling images..."
    docker image prune -f
    
    echo "Removing unused networks..."
    docker network prune -f
    
    echo -e "${GREEN}Cleanup complete${NC}"
}

cmd_health_check() {
    echo -e "${GREEN}=== Health Check ===${NC}"
    
    echo -e "\n${YELLOW}Web Server:${NC}"
    if curl -f http://127.0.0.1:3000/health 2>/dev/null; then
        echo -e "${GREEN}✓ Web server is healthy${NC}"
    else
        echo -e "${RED}✗ Web server is not responding${NC}"
    fi
    
    echo -e "\n${YELLOW}Streaming Server:${NC}"
    if curl -f http://127.0.0.1:4000/health 2>/dev/null; then
        echo -e "${GREEN}✓ Streaming server is healthy${NC}"
    else
        echo -e "${RED}✗ Streaming server is not responding${NC}"
    fi
    
    echo -e "\n${YELLOW}Redis:${NC}"
    if docker-compose exec -T redis redis-cli ping | grep -q PONG; then
        echo -e "${GREEN}✓ Redis is healthy${NC}"
    else
        echo -e "${RED}✗ Redis is not responding${NC}"
    fi
    
    echo -e "\n${YELLOW}PostgreSQL:${NC}"
    if docker-compose exec -T postgres psql -h localhost -U mastodon -d mastodon_production -c "SELECT 1;" 2>/dev/null; then
        echo -e "${GREEN}✓ PostgreSQL is healthy${NC}"
    else
        echo -e "${RED}✗ PostgreSQL is not responding${NC}"
    fi
    
    echo -e "\n${YELLOW}Disk Space:${NC}"
    # Get DB_DATA_DIR from .env or use docker-compose volume
    if [ -f ".env" ]; then
        DB_DATA_DIR=$(grep "^DB_DATA_DIR=" .env | cut -d= -f2)
    fi
    DB_DATA_DIR=${DB_DATA_DIR:-docker_postgres-data}
    
    if df -h "$DB_DATA_DIR" &>/dev/null 2>&1; then
        df -h "$DB_DATA_DIR" | tail -1 | awk '{printf "Data: %s / %s (%.1f%% used)\n", $4, $2, ($3/$2)*100}'
    else
        docker volume inspect "$DB_DATA_DIR" &>/dev/null && echo "✓ Database volume is healthy" || echo "! Database volume not found"
    fi
    
    df -h / | tail -1 | awk '{printf "Root: %s / %s (%.1f%% used)\n", $4, $2, ($3/$2)*100}'
}

cmd_media_cleanup() {
    echo -e "${YELLOW}Running media cleanup task...${NC}"
    docker-compose exec -T web bundle exec rake mastodon:media:remove_remote
    echo -e "${GREEN}Media cleanup complete${NC}"
}

cmd_db_migrate() {
    echo -e "${YELLOW}Running database migrations...${NC}"
    docker-compose exec web bundle exec rake db:migrate
    echo -e "${GREEN}Migrations complete${NC}"
}

cmd_assets_precompile() {
    echo -e "${YELLOW}Precompiling assets...${NC}"
    docker-compose exec web bundle exec rake assets:precompile
    echo -e "${GREEN}Assets precompiled${NC}"
}

# Main logic

COMMAND=${1:-help}

case "$COMMAND" in
    status)
        cmd_status
        ;;
    logs)
        cmd_logs "$2"
        ;;
    backup)
        cmd_backup
        ;;
    restore)
        cmd_restore "$2"
        ;;
    update)
        cmd_update
        ;;
    restart)
        cmd_restart "$2"
        ;;
    shell)
        cmd_shell "$2"
        ;;
    clean)
        cmd_clean
        ;;
    health-check)
        cmd_health_check
        ;;
    media-cleanup)
        cmd_media_cleanup
        ;;
    db-migrate)
        cmd_db_migrate
        ;;
    assets-precompile)
        cmd_assets_precompile
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}Unknown command: $COMMAND${NC}"
        echo "Run './maintenance.sh help' for usage information"
        exit 1
        ;;
esac
