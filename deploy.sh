#!/bin/bash

# ============================================================================
# CHATWOOT REGISTRY-BASED DEPLOYMENT SCRIPT
# ============================================================================
#
# Industry-standard deployment approach:
# 1. Build Docker image locally
# 2. Push image to Docker registry (Docker Hub, GitHub Container Registry, etc.)
# 3. Pull image on server
# 4. Deploy containers
#
# This is faster than building on server (2-5 min vs 15-30 min)
# and follows industry best practices.
#
# ============================================================================
# HOW SDK BUILD WORKS AUTOMATICALLY
# ============================================================================
#
# The SDK (pnpm run build:sdk) is built automatically during Docker image build.
# You do NOT need to manually run it!
#
# Build Flow:
#   deploy.sh → build_image_locally()
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
# .ENV FILE VARIABLES THAT GET CHANGED FOR PRODUCTION
# ============================================================================
#
# Before syncing .env to server, these variables are automatically updated:
#
# 1. FRONTEND_URL
#    - If contains localhost/0.0.0.0 → Changed to: https://chat.apaya.com
#    - Or use PRODUCTION_FRONTEND_URL if set in .env
#    - Example: http://0.0.0.0:3100 → https://chat.apaya.com
#
# 2. RAILS_ENV
#    - Always set to: production
#    - Example: development → production
#
# 3. NODE_ENV
#    - Always set to: production
#    - Example: development → production
#
# All other variables in .env are synced as-is (passwords, keys, etc.)
#
# ============================================================================

# Exit on any error
set -e

# Load configuration from .env file if it exists
# These are deployment-specific variables (not Chatwoot app variables)
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | grep -E '^DOCKER_USERNAME=|^REMOTE_HOST=|^DOCKER_REGISTRY=|^IMAGE_NAME=|^IMAGE_TAG=|^SKIP_ENV_SYNC=|^DEPLOY_DIR=|^PRODUCTION_FRONTEND_URL=' | xargs)
fi

# Configuration (must be set via .env file or environment variables)
DOCKER_REGISTRY="${DOCKER_REGISTRY:-docker.io}"  # docker.io, ghcr.io, or your registry
IMAGE_NAME="${IMAGE_NAME:-chatwoot}"
IMAGE_TAG="${IMAGE_TAG:-latest}"                  # Use git SHA, version, or 'latest'

# Required configuration - must be set
if [ -z "$DOCKER_USERNAME" ]; then
    echo "❌ ERROR: DOCKER_USERNAME is not set!"
    echo "   Please set it in .env file or environment variable:"
    echo "   DOCKER_USERNAME=your-dockerhub-username"
    exit 1
fi

if [ -z "$REMOTE_HOST" ]; then
    echo "❌ ERROR: REMOTE_HOST is not set!"
    echo "   Please set it in .env file or environment variable:"
    echo "   REMOTE_HOST=your-ssh-hostname"
    exit 1
fi

FULL_IMAGE_NAME="${DOCKER_USERNAME}/${IMAGE_NAME}:${IMAGE_TAG}"
DEPLOY_DIR="${DEPLOY_DIR:-/var/www/apaya/chatwoot}"  # Deployment directory on server (can be set in .env)
COMPOSE_FILE="docker-compose.production.yaml"

TIMESTAMP=$(date +%s)
LOG_DIR="./deploy"
LOG_FILE="$LOG_DIR/deploy_registry_${TIMESTAMP}.log"

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

log_header "🚀 CHATWOOT REGISTRY-BASED DEPLOYMENT"
echo -e "${GRAY}Started at: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${GRAY}Host: $REMOTE_HOST${NC}"
echo -e "${GRAY}Deploy directory: $DEPLOY_DIR${NC}"
echo -e "${GRAY}Log file: $LOG_FILE${NC}"
echo -e "${GRAY}Image: $FULL_IMAGE_NAME${NC}"
echo -e "${GRAY}Registry: $DOCKER_REGISTRY${NC}"
echo -e "${GRAY}Strategy: Build locally → Push to registry → Pull on server${NC}"
if [ "${SKIP_ENV_SYNC:-no}" = "yes" ]; then
    echo -e "${YELLOW}⚠️  SKIP_ENV_SYNC=yes - .env file will NOT be synced${NC}"
fi
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
    
    # Check if Docker is running
    if ! docker info > /dev/null 2>&1; then
        log_error "Docker is not running. Please start Docker and try again."
        exit 1
    fi
    
    log_success "All required files found"
}

# Generate image tag from git (optional)
generate_image_tag() {
    if [ "$IMAGE_TAG" = "latest" ] && [ -d ".git" ]; then
        GIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "latest")
        if [ "$GIT_SHA" != "latest" ]; then
            IMAGE_TAG="$GIT_SHA"
            FULL_IMAGE_NAME="${DOCKER_USERNAME}/${IMAGE_NAME}:${IMAGE_TAG}"
            log_info "Using git SHA as image tag: $IMAGE_TAG"
        fi
    fi
}

# Build Docker image locally
build_image_locally() {
    log_subheader "🔨 BUILDING DOCKER IMAGE LOCALLY"
    
    log_progress "Building Docker image (this includes asset precompilation and SDK build)..."
    log_info "This may take 15-30 minutes for first build, 5-10 minutes for subsequent builds..."
    BUILD_START=$(date +%s)
    
    # Generate .git_sha file locally (for Dockerfile)
    if [ -d ".git" ]; then
        GIT_SHA=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
        echo "$GIT_SHA" > .git_sha
        log_info "Git SHA: $(echo $GIT_SHA | cut -c1-7)"
    else
        echo "unknown" > .git_sha
        log_warn "No .git directory found, using 'unknown' for git SHA"
    fi
    
    # Build the image
    docker build -t "$FULL_IMAGE_NAME" -f docker/Dockerfile .
    
    # Cleanup .git_sha
    rm -f .git_sha
    
    BUILD_END=$(date +%s)
    BUILD_DURATION=$((BUILD_END - BUILD_START))
    MINUTES=$((BUILD_DURATION / 60))
    SECONDS=$((BUILD_DURATION % 60))
    
    # Get image size
    IMAGE_SIZE=$(docker images "$FULL_IMAGE_NAME" --format '{{.Size}}')
    
    log_success "Docker image built locally in ${MINUTES}m ${SECONDS}s"
    log_info "Image size: $IMAGE_SIZE"
}

# Push image to registry
push_image_to_registry() {
    log_subheader "📤 PUSHING IMAGE TO REGISTRY"
    
    log_progress "Pushing image to $DOCKER_REGISTRY/$FULL_IMAGE_NAME..."
    log_info "You may need to login: docker login $DOCKER_REGISTRY"
    
    PUSH_START=$(date +%s)
    
    # Check if logged in
    if ! docker info | grep -q "Username"; then
        log_warn "Not logged into Docker registry. Attempting login..."
        if [ "$DOCKER_REGISTRY" = "docker.io" ]; then
            log_info "Please login to Docker Hub:"
            docker login
        else
            log_info "Please login to $DOCKER_REGISTRY:"
            docker login "$DOCKER_REGISTRY"
        fi
    fi
    
    # Push image
    docker push "$FULL_IMAGE_NAME"
    
    PUSH_END=$(date +%s)
    PUSH_DURATION=$((PUSH_END - PUSH_START))
    
    log_success "Image pushed to registry in ${PUSH_DURATION}s"
    log_info "Image available at: $DOCKER_REGISTRY/$FULL_IMAGE_NAME"
}

# Sync docker-compose file to server
sync_compose_file() {
    log_subheader "📁 SYNCING DOCKER COMPOSE FILE"
    
    log_progress "Syncing docker-compose.production.yaml to server..."
    
    # Create deployment directory on server
    ssh $REMOTE_HOST "mkdir -p $DEPLOY_DIR"
    
    # Sync compose file
    scp "$COMPOSE_FILE" ${REMOTE_HOST}:${DEPLOY_DIR}/${COMPOSE_FILE}
    
    # Sync .env file to server (default behavior, can be disabled with SKIP_ENV_SYNC=yes)
    if [ "${SKIP_ENV_SYNC:-no}" = "yes" ]; then
        log_info "Skipping .env sync (SKIP_ENV_SYNC=yes)"
        if ! ssh $REMOTE_HOST "test -f ${DEPLOY_DIR}/.env"; then
            log_warn ".env file not found on server!"
            log_info "You need to create .env file manually on the server."
        fi
    else
        if [ -f ".env" ]; then
            log_progress "Preparing .env file for production..."
            
            # Create temporary production .env file
            TEMP_ENV=$(mktemp)
            cp .env "$TEMP_ENV"
            
            # Replace production-specific values
            # FRONTEND_URL - use PRODUCTION_FRONTEND_URL if set, otherwise auto-detect and replace
            if [ -n "$PRODUCTION_FRONTEND_URL" ]; then
                # Use provided production URL
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    sed -i '' "s|^FRONTEND_URL=.*|FRONTEND_URL=$PRODUCTION_FRONTEND_URL|" "$TEMP_ENV"
                else
                    sed -i "s|^FRONTEND_URL=.*|FRONTEND_URL=$PRODUCTION_FRONTEND_URL|" "$TEMP_ENV"
                fi
                log_info "Updated FRONTEND_URL to: $PRODUCTION_FRONTEND_URL"
            else
                # Auto-detect: if FRONTEND_URL contains localhost/0.0.0.0, replace with production URL
                EXISTING_URL=$(grep "^FRONTEND_URL=" "$TEMP_ENV" | cut -d'=' -f2- | tr -d '"' | tr -d "'" || echo "")
                if [ -z "$EXISTING_URL" ] || [[ "$EXISTING_URL" == *"0.0.0.0"* ]] || [[ "$EXISTING_URL" == *"localhost"* ]] || [[ "$EXISTING_URL" == *"127.0.0.1"* ]]; then
                    PROD_URL="https://chat.apaya.com"
                    if [[ "$OSTYPE" == "darwin"* ]]; then
                        sed -i '' "s|^FRONTEND_URL=.*|FRONTEND_URL=$PROD_URL|" "$TEMP_ENV" 2>/dev/null || echo "FRONTEND_URL=$PROD_URL" >> "$TEMP_ENV"
                    else
                        sed -i "s|^FRONTEND_URL=.*|FRONTEND_URL=$PROD_URL|" "$TEMP_ENV" 2>/dev/null || echo "FRONTEND_URL=$PROD_URL" >> "$TEMP_ENV"
                    fi
                    log_info "Updated FRONTEND_URL from '$EXISTING_URL' to: $PROD_URL"
                else
                    log_info "Keeping existing FRONTEND_URL: $EXISTING_URL"
                fi
            fi
            
            # Ensure RAILS_ENV and NODE_ENV are set to production
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s|^RAILS_ENV=.*|RAILS_ENV=production|" "$TEMP_ENV" 2>/dev/null || echo "RAILS_ENV=production" >> "$TEMP_ENV"
                sed -i '' "s|^NODE_ENV=.*|NODE_ENV=production|" "$TEMP_ENV" 2>/dev/null || echo "NODE_ENV=production" >> "$TEMP_ENV"
            else
                sed -i "s|^RAILS_ENV=.*|RAILS_ENV=production|" "$TEMP_ENV" 2>/dev/null || echo "RAILS_ENV=production" >> "$TEMP_ENV"
                sed -i "s|^NODE_ENV=.*|NODE_ENV=production|" "$TEMP_ENV" 2>/dev/null || echo "NODE_ENV=production" >> "$TEMP_ENV"
            fi
            
            log_progress "Syncing production .env file to server..."
            scp "$TEMP_ENV" ${REMOTE_HOST}:${DEPLOY_DIR}/.env
            rm -f "$TEMP_ENV"
            
            # Set secure permissions
            ssh $REMOTE_HOST "chmod 600 ${DEPLOY_DIR}/.env"
            log_success ".env file synced to server (with production values and secure permissions)"
        else
            log_warn ".env file not found locally - skipping sync"
            if ! ssh $REMOTE_HOST "test -f ${DEPLOY_DIR}/.env"; then
                log_warn ".env file not found on server either!"
                log_info "You need to create .env file manually on the server."
            fi
        fi
    fi
    
    log_success "Docker compose file synced"
}

# Update docker-compose to use the new image
update_compose_image() {
    log_subheader "🔄 UPDATING DOCKER COMPOSE IMAGE"
    
    log_progress "Updating image reference in docker-compose file on server..."
    
    # Update image name in docker-compose file on server
    ssh $REMOTE_HOST "cd $DEPLOY_DIR && \
        sed -i 's|image:.*chatwoot.*|image: $FULL_IMAGE_NAME|g' $COMPOSE_FILE && \
        echo '✅ Updated image to: $FULL_IMAGE_NAME'"
    
    log_success "Docker compose file updated with new image"
}

# Pull image on server
pull_image_on_server() {
    log_subheader "📥 PULLING IMAGE ON SERVER"
    
    log_progress "Pulling image $FULL_IMAGE_NAME on server..."
    
    PULL_START=$(date +%s)
    
    # Pull image on server
    ssh $REMOTE_HOST "docker pull $FULL_IMAGE_NAME"
    
    PULL_END=$(date +%s)
    PULL_DURATION=$((PULL_END - PULL_START))
    
    log_success "Image pulled on server in ${PULL_DURATION}s"
}

# Stop existing services
stop_existing_services() {
    log_subheader "🛑 STOPPING EXISTING SERVICES"
    
    log_progress "Stopping existing Docker containers..."
    
    # Stop and remove existing containers (but keep volumes)
    ssh $REMOTE_HOST "cd $DEPLOY_DIR && \
        docker compose -f $COMPOSE_FILE down --remove-orphans 2>/dev/null || true"
    
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
    
    # Run migrations using docker compose run
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
    
    log_progress "Removing unused Docker images on server..."
    
    # Remove unused images (keep last 2 versions)
    ssh $REMOTE_HOST "docker image prune -f && \
        docker images ${DOCKER_USERNAME}/${IMAGE_NAME} --format '{{.Repository}}:{{.Tag}}' | \
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
    echo -e "${GREEN}📦 Image: $FULL_IMAGE_NAME${NC}"
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

    echo -e "${CYAN}🔄 Rollback to previous image:${NC}"
    echo "   # Update IMAGE_TAG in this script or docker-compose file"
    echo "   ssh ${REMOTE_HOST} 'cd ${DEPLOY_DIR} && docker pull ${DOCKER_USERNAME}/${IMAGE_NAME}:PREVIOUS_TAG'"
    echo "   ssh ${REMOTE_HOST} 'cd ${DEPLOY_DIR} && docker compose -f ${COMPOSE_FILE} up -d'"
    echo ""

    echo -e "${WHITE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}🚀 Happy coding! Your Chatwoot instance is live and ready! 🎉${NC}"
    echo -e "${WHITE}════════════════════════════════════════════════════════════════${NC}"
}

# Main deployment flow
main() {
    check_required_files
    generate_image_tag
    build_image_locally
    push_image_to_registry
    sync_compose_file
    update_compose_image
    stop_existing_services
    pull_image_on_server
    start_database_services
    run_migrations
    start_new_services
    verify_deployment
    cleanup_old_images
    show_summary
}

# Run main function
main "$@"

