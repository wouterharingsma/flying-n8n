#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Print banner
print_banner() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}    ${BOLD}n8n on Fly.io${NC} - Deployment Manager    ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════╝${NC}"
    echo ""
}

# Print step
step() {
    echo -e "${BLUE}▸${NC} $1"
}

# Print success
success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Print error
error() {
    echo -e "${RED}✗${NC} $1"
}

# Print warning
warn() {
    echo -e "${YELLOW}!${NC} $1"
}

# Get app name from fly.toml
get_app_name() {
    grep "^app = " fly.toml 2>/dev/null | sed "s/app = '\(.*\)'/\1/" | tr -d '"'
}

# Check prerequisites
check_prerequisites() {
    step "Checking prerequisites..."
    
    if ! command -v flyctl &> /dev/null; then
        error "flyctl is not installed"
        echo ""
        echo "  Install it with:"
        echo "    curl -L https://fly.io/install.sh | sh"
        echo ""
        echo "  Or visit: https://fly.io/docs/hands-on/install-flyctl/"
        exit 1
    fi
    
    if ! flyctl auth whoami &> /dev/null; then
        error "Not logged in to Fly.io"
        echo ""
        echo "  Run: flyctl auth login"
        exit 1
    fi
    
    if [ ! -f "fly.toml" ]; then
        error "fly.toml not found. Are you in the right directory?"
        exit 1
    fi
    
    success "All prerequisites met"
}

# Setup or update secrets
setup_secrets() {
    local app_name=$1
    
    step "Checking URL configuration..."
    
    EXISTING=$(flyctl secrets list -a "$app_name" 2>/dev/null | grep -c "N8N_HOST" || echo "0")
    
    if [ "$EXISTING" -eq "0" ]; then
        echo ""
        warn "URL secrets not configured yet"
        echo ""
        echo -e "  ${BOLD}What URL will you use to access n8n?${NC}"
        echo -e "  ${CYAN}Example: https://${app_name}.fly.dev${NC}"
        echo ""
        read -p "  Enter URL: " N8N_HOST
        
        # Ensure https://
        if [[ ! "$N8N_HOST" =~ ^https?:// ]]; then
            N8N_HOST="https://$N8N_HOST"
        fi
        
        # Remove trailing slash
        N8N_HOST="${N8N_HOST%/}"
        
        echo ""
        step "Saving secrets..."
        flyctl secrets set \
            N8N_HOST="$N8N_HOST" \
            WEBHOOK_URL="$N8N_HOST" \
            -a "$app_name" --stage
        
        success "Secrets configured"
    else
        success "URL secrets already configured"
    fi
}

# Configure auto-sleep
configure_autosleep() {
    local app_name=$1
    local first_time=$2
    
    step "Checking auto-sleep configuration..."
    
    # Get current setting from fly.toml
    CURRENT_SETTING=$(grep "auto_stop_machines" fly.toml | head -1 | sed "s/.*= *'\?\([^']*\)'\?/\1/" | tr -d ' ')
    
    if [ "$first_time" = "true" ]; then
        echo ""
        echo -e "  ${BOLD}Enable auto-sleep?${NC}"
        echo ""
        echo -e "  ${GREEN}Yes${NC} - App sleeps when idle (saves money, ~5s cold start)"
        echo -e "  ${YELLOW}No${NC}  - App stays running 24/7 (faster, costs more)"
        echo ""
        read -p "  Enable auto-sleep? (Y/n): " AUTOSLEEP_CHOICE
        
        if [[ "$AUTOSLEEP_CHOICE" =~ ^[Nn]$ ]]; then
            set_autosleep "false"
            success "Auto-sleep disabled (always-on)"
        else
            set_autosleep "true"
            success "Auto-sleep enabled (cost-saving)"
        fi
    else
        if [ "$CURRENT_SETTING" = "true" ] || [ "$CURRENT_SETTING" = "'stop'" ]; then
            success "Auto-sleep is enabled"
        else
            success "Auto-sleep is disabled (always-on)"
        fi
    fi
}

# Update fly.toml with auto-sleep setting
set_autosleep() {
    local enabled=$1
    
    if [ "$enabled" = "true" ]; then
        # Enable auto-sleep
        sed -i '' "s/auto_stop_machines = .*/auto_stop_machines = 'stop'/" fly.toml
        sed -i '' "s/min_machines_running = .*/min_machines_running = 0/" fly.toml
    else
        # Disable auto-sleep (always on)
        sed -i '' "s/auto_stop_machines = .*/auto_stop_machines = false/" fly.toml
        sed -i '' "s/min_machines_running = .*/min_machines_running = 1/" fly.toml
    fi
}

# Check/create volume
setup_volume() {
    local app_name=$1
    local region=$2
    
    step "Checking persistent storage..."
    
    VOLUME_EXISTS=$(flyctl volumes list -a "$app_name" 2>/dev/null | grep -c "n8n_vol" || echo "0")
    
    if [ "$VOLUME_EXISTS" -eq "0" ]; then
        warn "No volume found, creating one..."
        flyctl volumes create n8n_vol --size 1 --region "$region" -a "$app_name" -y
        success "Volume created in $region"
    else
        success "Volume exists"
    fi
}

# Deploy
deploy() {
    local app_name=$1
    
    echo ""
    echo -e "${BOLD}Deploying to Fly.io...${NC}"
    echo ""
    
    flyctl deploy -a "$app_name"
}

# Show status
show_status() {
    local app_name=$1
    
    # Get current auto-sleep setting
    AUTOSLEEP=$(grep "auto_stop_machines" fly.toml | head -1 | sed "s/.*= *'\?\([^']*\)'\?/\1/" | tr -d ' ')
    if [ "$AUTOSLEEP" = "stop" ] || [ "$AUTOSLEEP" = "true" ]; then
        SLEEP_STATUS="enabled"
    else
        SLEEP_STATUS="disabled"
    fi
    
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}         ${BOLD}Deployment Complete! 🚀${NC}           ${GREEN}║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${BOLD}Your n8n instance:${NC}"
    echo -e "  ${CYAN}https://${app_name}.fly.dev${NC}"
    echo ""
    echo -e "  ${BOLD}Auto-sleep:${NC} ${SLEEP_STATUS}"
    echo ""
    echo -e "  ${BOLD}Useful commands:${NC}"
    echo -e "  ${BLUE}./deploy.sh logs${NC}        View logs"
    echo -e "  ${BLUE}./deploy.sh status${NC}      Check status"
    echo -e "  ${BLUE}./deploy.sh autosleep${NC}   Toggle auto-sleep"
    echo ""
}

# Show help
show_help() {
    print_banner
    echo "Usage: ./deploy.sh [command]"
    echo ""
    echo "Commands:"
    echo "  (none)      Full deployment (setup + deploy)"
    echo "  setup       Configure app without deploying"
    echo "  secrets     Update URL secrets"
    echo "  autosleep   Toggle auto-sleep on/off"
    echo "  logs        Stream application logs"
    echo "  status      Show app status"
    echo "  ssh         SSH into the running container"
    echo "  help        Show this help message"
    echo ""
}

# Main
main() {
    cd "$(dirname "$0")"
    
    case "${1:-}" in
        help|--help|-h)
            show_help
            exit 0
            ;;
        logs)
            APP_NAME=$(get_app_name)
            flyctl logs -a "$APP_NAME"
            exit 0
            ;;
        status)
            APP_NAME=$(get_app_name)
            flyctl status -a "$APP_NAME"
            exit 0
            ;;
        ssh)
            APP_NAME=$(get_app_name)
            flyctl ssh console -a "$APP_NAME"
            exit 0
            ;;
        secrets)
            print_banner
            APP_NAME=$(get_app_name)
            check_prerequisites
            echo ""
            echo -e "  ${BOLD}Enter new URL for n8n:${NC}"
            read -p "  URL: " N8N_HOST
            if [[ ! "$N8N_HOST" =~ ^https?:// ]]; then
                N8N_HOST="https://$N8N_HOST"
            fi
            N8N_HOST="${N8N_HOST%/}"
            flyctl secrets set N8N_HOST="$N8N_HOST" WEBHOOK_URL="$N8N_HOST" -a "$APP_NAME"
            success "Secrets updated! Restart with: flyctl apps restart $APP_NAME"
            exit 0
            ;;
        autosleep)
            print_banner
            APP_NAME=$(get_app_name)
            check_prerequisites
            
            # Get current setting
            CURRENT=$(grep "auto_stop_machines" fly.toml | head -1 | sed "s/.*= *'\?\([^']*\)'\?/\1/" | tr -d ' ')
            
            echo ""
            if [ "$CURRENT" = "stop" ] || [ "$CURRENT" = "true" ]; then
                echo -e "  Auto-sleep is currently: ${GREEN}enabled${NC}"
                echo ""
                read -p "  Disable auto-sleep (keep app always running)? (y/N): " TOGGLE
                if [[ "$TOGGLE" =~ ^[Yy]$ ]]; then
                    set_autosleep "false"
                    success "Auto-sleep disabled"
                    echo ""
                    warn "Run ./deploy.sh to apply changes"
                fi
            else
                echo -e "  Auto-sleep is currently: ${YELLOW}disabled${NC} (always-on)"
                echo ""
                read -p "  Enable auto-sleep (saves money)? (Y/n): " TOGGLE
                if [[ ! "$TOGGLE" =~ ^[Nn]$ ]]; then
                    set_autosleep "true"
                    success "Auto-sleep enabled"
                    echo ""
                    warn "Run ./deploy.sh to apply changes"
                fi
            fi
            exit 0
            ;;
        setup)
            print_banner
            APP_NAME=$(get_app_name)
            REGION=$(grep "primary_region" fly.toml | sed "s/primary_region = '\(.*\)'/\1/" | tr -d '"')
            check_prerequisites
            setup_secrets "$APP_NAME"
            setup_volume "$APP_NAME" "$REGION"
            configure_autosleep "$APP_NAME" "true"
            echo ""
            success "Setup complete! Run ./deploy.sh to deploy"
            exit 0
            ;;
        *)
            print_banner
            APP_NAME=$(get_app_name)
            REGION=$(grep "primary_region" fly.toml | sed "s/primary_region = '\(.*\)'/\1/" | tr -d '"')
            
            echo -e "  App:    ${BOLD}$APP_NAME${NC}"
            echo -e "  Region: ${BOLD}$REGION${NC}"
            echo ""
            
            check_prerequisites
            
            # Check if this is first-time setup
            EXISTING=$(flyctl secrets list -a "$APP_NAME" 2>/dev/null | grep -c "N8N_HOST" || echo "0")
            FIRST_TIME="false"
            if [ "$EXISTING" -eq "0" ]; then
                FIRST_TIME="true"
            fi
            
            setup_secrets "$APP_NAME"
            setup_volume "$APP_NAME" "$REGION"
            configure_autosleep "$APP_NAME" "$FIRST_TIME"
            deploy "$APP_NAME"
            show_status "$APP_NAME"
            ;;
    esac
}

main "$@"
