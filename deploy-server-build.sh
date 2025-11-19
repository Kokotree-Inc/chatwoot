#!/bin/bash

# ============================================================================
# CHATWOOT SERVER-SIDE DEPLOYMENT SCRIPT
# ============================================================================
#
# This script deploys Chatwoot to a production server by:
# 1. Syncing code to server
# 2. Building Docker image (includes SDK build automatically)
# 3. Starting services and running migrations
#
# ============================================================================
# HOW SDK BUILD WORKS AUTOMATICALLY
# ============================================================================
#
# The SDK (pnpm run build:sdk) is built automatically during Docker image build.
# You do NOT need to manually run it!
#
# Build Flow:
#   deploy-server-build.sh → build_image_on_server() function
#       ↓
#   docker build (executes Dockerfile)
#       ↓
#   Dockerfile → rake assets:precompile
#       ↓
#   lib/tasks/build.rake → enhances assets:precompile
#       ↓
#   before_assets_precompile task → pnpm run build:sdk ✅
#
# The Rake task hook ensures SDK is built before asset precompilation.
# See: lib/tasks/build.rake for the hook implementation.
#
# ============================================================================

# Exit on any error
set -e

# Configuration
CHATWOOT_IMAGE="chatwoot/chatwoot"
TAG="latest"
REMOTE_HOST="kokotree-prod-server"  # SSH hostname from ~/.ssh/config
DEPLOY_DIR="/var/www/apaya/chatwoot"  # Deployment directory on server
COMPOSE_FILE="docker-compose.production.yaml"
TIMESTAMP=$(date +%s)
LOG_DIR="./deploy"
LOG_FILE="$LOG_DIR/deploy_server_build_$TIMESTAMP.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_step() {
    echo -e "${BLUE}🔵 $1${NC}"
}

log_progress() {
    echo -e "${PURPLE}⏳ $1${NC}"
}

log_success() {
    echo -e "${GREEN}🎉 $1${NC}"
}

log_header() {
    echo -e "${WHITE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}  $1${NC}"
    echo -e "${WHITE}════════════════════════════════════════════════════════════════${NC}"
}

log_subheader() {
    echo -e "${CYAN}──────────────────────────────────────────────────────────────${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}──────────────────────────────────────────────────────────────${NC}"
}

# Start time for duration calculation
START_TIME=$(date +%s)

# Create log directory
mkdir -p "$LOG_DIR"

# Start logging
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

log_header "🚀 CHATWOOT SERVER-SIDE DEPLOYMENT"
echo -e "${GRAY}Started at: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${GRAY}Host: $REMOTE_HOST${NC}"
echo -e "${GRAY}Deploy directory: $DEPLOY_DIR${NC}"
echo -e "${GRAY}Log file: $LOG_FILE${NC}"
echo -e "${GRAY}Strategy: Build Docker image directly on server${NC}"
echo ""

# Check if required files exist
check_required_files() {
    log_step "Checking required files..."
    
    # Check if Dockerfile exists
    if [ ! -f "docker/Dockerfile" ]; then
        log_error "docker/Dockerfile not found in current directory"
        exit 1
    fi
    
    # Check if compose file exists
    if [ ! -f "$COMPOSE_FILE" ]; then
        log_error "$COMPOSE_FILE not found in current directory"
        exit 1
    fi
    
    # Check if .env file exists (warn if not)
    if [ ! -f ".env" ]; then
        log_warn ".env file not found - ensure environment variables are set on server"
    fi
    
    # Check if .dockerignore exists
    if [ ! -f ".dockerignore" ]; then
        log_warn ".dockerignore not found - this may increase build time"
    fi
    
    log_success "All required files found"
}

# Sync code to server
sync_code_to_server() {
    log_subheader "📁 SYNCING CODE TO SERVER"
    
    log_progress "Syncing application code to server..."
    SYNC_START=$(date +%s)
    
    # Create deployment directory on server
    ssh $REMOTE_HOST "mkdir -p $DEPLOY_DIR"
    
    # Sync all necessary files (excluding large directories and sensitive files)
    rsync -avz --delete \
        --exclude='node_modules/' \
        --exclude='.git/' \
        --exclude='tmp/' \
        --exclude='log/' \
        --exclude='storage/' \
        --exclude='public/packs/' \
        --exclude='public/vite/' \
        --exclude='coverage/' \
        --exclude='.env*' \
        --exclude='deploy/' \
        --exclude='spec/' \
        --exclude='*.log' \
        --exclude='.overmind.sock' \
        --exclude='tmp/pids/' \
        ./ $REMOTE_HOST:$DEPLOY_DIR/
    
    SYNC_END=$(date +%s)
    SYNC_DURATION=$((SYNC_END - SYNC_START))
    log_success "Code synced to server in ${SYNC_DURATION}s"
}

# Build Docker image on server
build_image_on_server() {
    log_subheader "🔨 BUILDING DOCKER IMAGE ON SERVER"
    
    log_progress "Building Docker image on server (this includes asset precompilation and SDK build)..."
    log_info "This may take several minutes as it builds assets, SDK, and compiles Ruby gems..."
    BUILD_START=$(date +%s)
    
    # Build the image directly on the server
    # The Dockerfile automatically runs assets:precompile which includes SDK build
    ssh $REMOTE_HOST "cd $DEPLOY_DIR && \
        docker build -t ${CHATWOOT_IMAGE}:${TAG} -f docker/Dockerfile . && \
        docker images ${CHATWOOT_IMAGE}:${TAG} --format '{{.Size}}'"
    
    BUILD_END=$(date +%s)
    BUILD_DURATION=$((BUILD_END - BUILD_START))
    MINUTES=$((BUILD_DURATION / 60))
    SECONDS=$((BUILD_DURATION % 60))
    log_success "Docker image built on server in ${MINUTES}m ${SECONDS}s"
}

# Stop existing services
stop_existing_services() {
    log_subheader "🛑 STOPPING EXISTING SERVICES"
    
    log_progress "Stopping existing Docker containers..."
    
    # Stop and remove existing containers (but keep volumes)
    ssh $REMOTE_HOST "cd $DEPLOY_DIR && \
        docker compose -f $COMPOSE_FILE down --remove-orphans || true"
    
    log_success "Existing services stopped"
}

# Start database services first
start_database_services() {
    log_subheader "🗄️  STARTING DATABASE SERVICES"
    
    log_progress "Starting PostgreSQL and Redis..."
    
    # Start only postgres and redis first
    ssh $REMOTE_HOST "cd $DEPLOY_DIR && \
        docker compose -f $COMPOSE_FILE up -d postgres redis"
    
    log_progress "Waiting for database to be ready..."
    sleep 10
    
    log_success "Database services started"
}

# Run database migrations
run_migrations() {
    log_subheader "🗄️  RUNNING DATABASE MIGRATIONS"
    
    log_progress "Running database migrations..."
    
    # Run migrations using docker compose run (automatically uses correct network)
    ssh $REMOTE_HOST "cd $DEPLOY_DIR && \
        docker compose -f $COMPOSE_FILE run --rm \
        -e RAILS_ENV=production \
        -e POSTGRES_STATEMENT_TIMEOUT=600s \
        rails \
        bundle exec rails db:chatwoot_prepare"
    
    log_success "Database migrations completed"
}

# Start new services
start_new_services() {
    log_subheader "🚀 STARTING APPLICATION SERVICES"
    
    log_progress "Starting Rails and Sidekiq..."
    
    # Start the application containers
    ssh $REMOTE_HOST "cd $DEPLOY_DIR && \
        docker compose -f $COMPOSE_FILE up -d rails sidekiq"
    
    log_success "Application services started"
}

# Verify deployment
verify_deployment() {
    log_subheader "🔍 VERIFYING DEPLOYMENT"
    
    log_progress "Waiting for services to start..."
    sleep 15
    
    # Check if containers are running
    log_progress "Checking container status..."
    ssh $REMOTE_HOST "cd $DEPLOY_DIR && docker compose -f $COMPOSE_FILE ps"
    
    # Check Rails logs for errors
    log_progress "Checking Rails logs for errors..."
    RAILS_LOGS=$(ssh $REMOTE_HOST "cd $DEPLOY_DIR && docker compose -f $COMPOSE_FILE logs --tail=30 rails" 2>/dev/null)
    
    if echo "$RAILS_LOGS" | grep -qi "error\|fatal\|exception"; then
        log_warn "Potential errors found in Rails logs:"
        echo "$RAILS_LOGS" | grep -i "error\|fatal\|exception" | head -5
    else
        log_success "No critical errors found in Rails logs"
    fi
    
    # Check if Rails is responding
    log_progress "Testing Rails application..."
    sleep 5
    
    # Try to curl the health endpoint or root
    HTTP_CODE=$(ssh $REMOTE_HOST "curl -s -o /dev/null -w '%{http_code}' http://localhost:3080/" 2>/dev/null || echo "000")
    
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "301" ]; then
        log_success "Rails application is responding (HTTP $HTTP_CODE)"
    else
        log_warn "Rails application may not be responding correctly (HTTP $HTTP_CODE)"
        log_info "Check logs with: ssh $REMOTE_HOST 'cd $DEPLOY_DIR && docker compose logs rails'"
    fi
    
    # Verify SDK file exists
    log_progress "Verifying SDK file..."
    SDK_CHECK=$(ssh $REMOTE_HOST "docker exec \$(docker ps -q -f name=chatwoot-rails) ls -lh /app/public/packs/js/sdk.js 2>/dev/null" || echo "")
    if [ -n "$SDK_CHECK" ]; then
        log_success "SDK file verified in container"
        echo -e "${GREEN}   $SDK_CHECK${NC}"
    else
        log_warn "SDK file not found - this may cause widget loading issues"
    fi
}

# Cleanup old images
cleanup_old_images() {
    log_subheader "🧹 CLEANING UP OLD IMAGES"
    
    log_progress "Removing unused Docker images..."
    
    # Remove unused images (keep last 2 versions)
    ssh $REMOTE_HOST "docker image prune -f && \
        docker images ${CHATWOOT_IMAGE} --format '{{.Repository}}:{{.Tag}}' | \
        tail -n +3 | xargs -r docker rmi || true"
    
    log_success "Cleanup completed"
}

# Show deployment summary
show_summary() {
    log_header "🎉 DEPLOYMENT COMPLETED SUCCESSFULLY"
    
    END_TIME=$(date +%s)
    TOTAL_DURATION=$((END_TIME - START_TIME))
    MINUTES=$((TOTAL_DURATION / 60))
    SECONDS=$((TOTAL_DURATION % 60))
    
    echo -e "${GREEN}✅ Deployment finished at: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo -e "${GREEN}⏱️  Total duration: ${MINUTES}m ${SECONDS}s${NC}"
    echo -e "${GREEN}📦 Image: ${CHATWOOT_IMAGE}:${TAG}${NC}"
    echo -e "${GREEN}🧳 Server: ${REMOTE_HOST}${NC}"
    echo -e "${GREEN}🌐 Application URL: http://${REMOTE_HOST}:3080${NC}"
    echo -e "${GREEN}📋 Log file: ${LOG_FILE}${NC}"
    echo ""

    # Helpful commands section
    log_subheader "🔧 HELPFUL COMMANDS"

    echo -e "${CYAN}📋 View Rails logs:${NC}"
    echo "   ssh ${REMOTE_HOST} 'cd ${DEPLOY_DIR} && docker compose -f ${COMPOSE_FILE} logs -f rails'"
    echo ""

    echo -e "${CYAN}📋 View Sidekiq logs:${NC}"
    echo "   ssh ${REMOTE_HOST} 'cd ${DEPLOY_DIR} && docker compose -f ${COMPOSE_FILE} logs -f sidekiq'"
    echo ""

    echo -e "${CYAN}🔄 Restart all services:${NC}"
    echo "   ssh ${REMOTE_HOST} 'cd ${DEPLOY_DIR} && docker compose -f ${COMPOSE_FILE} restart'"
    echo ""

    echo -e "${CYAN}🔄 Restart Rails only:${NC}"
    echo "   ssh ${REMOTE_HOST} 'cd ${DEPLOY_DIR} && docker compose -f ${COMPOSE_FILE} restart rails'"
    echo ""

    echo -e "${CYAN}🛑 Stop all services:${NC}"
    echo "   ssh ${REMOTE_HOST} 'cd ${DEPLOY_DIR} && docker compose -f ${COMPOSE_FILE} stop'"
    echo ""

    echo -e "${CYAN}▶️  Start all services:${NC}"
    echo "   ssh ${REMOTE_HOST} 'cd ${DEPLOY_DIR} && docker compose -f ${COMPOSE_FILE} start'"
    echo ""

    echo -e "${CYAN}🔁 Check service status:${NC}"
    echo "   ssh ${REMOTE_HOST} 'cd ${DEPLOY_DIR} && docker compose -f ${COMPOSE_FILE} ps'"
    echo ""

    echo -e "${CYAN}🗄️  Run database migrations:${NC}"
    echo "   ssh ${REMOTE_HOST} 'cd ${DEPLOY_DIR} && docker compose -f ${COMPOSE_FILE} run --rm -e RAILS_ENV=production rails bundle exec rails db:chatwoot_prepare'"
    echo ""

    echo -e "${CYAN}🔍 Rails console:${NC}"
    echo "   ssh ${REMOTE_HOST} 'cd ${DEPLOY_DIR} && docker compose -f ${COMPOSE_FILE} exec rails bundle exec rails console'"
    echo ""

    echo -e "${CYAN}📊 Check container stats:${NC}"
    echo "   ssh ${REMOTE_HOST} 'docker stats --no-stream'"
    echo ""

    echo -e "${CYAN}🧹 Clean up old images:${NC}"
    echo "   ssh ${REMOTE_HOST} 'docker image prune -f'"
    echo ""

    echo -e "${CYAN}🔍 View recent Rails logs (last 50 lines):${NC}"
    echo "   ssh ${REMOTE_HOST} 'cd ${DEPLOY_DIR} && docker compose -f ${COMPOSE_FILE} logs --tail=50 rails'"
    echo ""

    echo -e "${CYAN}🌐 Test application health:${NC}"
    echo "   ssh ${REMOTE_HOST} 'curl -s -o /dev/null -w \"%{http_code}\" http://localhost:3080/'"
    echo ""

    echo -e "${CYAN}📦 Check SDK file in container:${NC}"
    echo "   ssh ${REMOTE_HOST} 'docker exec \$(docker ps -q -f name=chatwoot-rails) ls -lh /app/public/packs/js/sdk.js'"
    echo ""

    echo -e "${WHITE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}🚀 Happy coding! Your Chatwoot instance is live and ready! 🎉${NC}"
    echo -e "${WHITE}════════════════════════════════════════════════════════════════${NC}"
}

# Main deployment flow
main() {
    check_required_files
    sync_code_to_server
    stop_existing_services
    build_image_on_server
    start_database_services
    run_migrations
    start_new_services
    verify_deployment
    cleanup_old_images
    show_summary
}

# Run main function
main "$@"

