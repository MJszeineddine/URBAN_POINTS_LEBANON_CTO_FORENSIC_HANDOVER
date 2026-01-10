#!/bin/bash

# Urban Points Lebanon - Production Management Script
# This script provides easy commands for managing the production API server

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Function to show usage
show_usage() {
    echo "════════════════════════════════════════════════════════════════"
    echo "  Urban Points Lebanon - Production API Manager"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "Usage: $0 {command}"
    echo ""
    echo "Commands:"
    echo "  status       - Show PM2 process status"
    echo "  start        - Start the API server"
    echo "  stop         - Stop the API server"
    echo "  restart      - Restart the API server"
    echo "  reload       - Zero-downtime reload"
    echo "  logs         - Show real-time logs"
    echo "  logs-error   - Show error logs only"
    echo "  monitor      - Open PM2 monitoring dashboard"
    echo "  health       - Test API health endpoint"
    echo "  info         - Show detailed process information"
    echo "  save         - Save current PM2 configuration"
    echo "  test         - Run comprehensive API tests"
    echo "  cleanup      - Clean old logs"
    echo ""
    echo "Examples:"
    echo "  $0 status           # Check if API is running"
    echo "  $0 restart          # Restart the API server"
    echo "  $0 logs             # View real-time logs"
    echo "  $0 health           # Test API health"
    echo ""
}

# Function to check if PM2 process is running
check_running() {
    pm2 describe urban-points-api &>/dev/null
    return $?
}

# Command: Status
cmd_status() {
    print_status "Checking PM2 process status..."
    pm2 status urban-points-api
    echo ""
    
    if check_running; then
        print_success "Urban Points API is RUNNING"
    else
        print_warning "Urban Points API is NOT running"
    fi
}

# Command: Start
cmd_start() {
    if check_running; then
        print_warning "Urban Points API is already running"
        pm2 status urban-points-api
    else
        print_status "Starting Urban Points API..."
        pm2 start ecosystem.config.js
        sleep 2
        pm2 status urban-points-api
        print_success "API started successfully"
    fi
}

# Command: Stop
cmd_stop() {
    if check_running; then
        print_status "Stopping Urban Points API..."
        pm2 stop urban-points-api
        print_success "API stopped successfully"
    else
        print_warning "Urban Points API is not running"
    fi
}

# Command: Restart
cmd_restart() {
    print_status "Restarting Urban Points API..."
    if check_running; then
        pm2 restart urban-points-api
    else
        pm2 start ecosystem.config.js
    fi
    sleep 2
    pm2 status urban-points-api
    print_success "API restarted successfully"
}

# Command: Reload (zero-downtime)
cmd_reload() {
    print_status "Reloading Urban Points API (zero-downtime)..."
    pm2 reload urban-points-api
    sleep 2
    pm2 status urban-points-api
    print_success "API reloaded successfully"
}

# Command: Logs
cmd_logs() {
    print_status "Showing real-time logs (Ctrl+C to exit)..."
    pm2 logs urban-points-api --lines 50
}

# Command: Error Logs
cmd_logs_error() {
    print_status "Showing error logs..."
    pm2 logs urban-points-api --err --lines 100 --nostream
}

# Command: Monitor
cmd_monitor() {
    print_status "Opening PM2 monitoring dashboard..."
    pm2 monit
}

# Command: Health Check
cmd_health() {
    print_status "Testing API health endpoint..."
    
    HEALTH_RESPONSE=$(curl -s http://localhost:3000/api/health || echo '{"error":"connection_failed"}')
    
    echo "$HEALTH_RESPONSE" | python3 -m json.tool
    
    if echo "$HEALTH_RESPONSE" | grep -q 'healthy'; then
        print_success "✅ API Health Check PASSED"
        
        # Extract key information
        echo ""
        echo "Key Information:"
        echo "$HEALTH_RESPONSE" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if 'data' in data:
    d = data['data']
    print(f\"  • Status: {d.get('status', 'N/A')}\")
    print(f\"  • Database: {d.get('database', 'N/A')}\")
    print(f\"  • Timezone: {d.get('tz', 'N/A')}\")
    print(f\"  • Payments Enabled: {d.get('PAYMENTS_ENABLED', 'N/A')}\")
    print(f\"  • Version: {d.get('version', 'N/A')}\")
"
    else
        print_error "❌ API Health Check FAILED"
        echo "$HEALTH_RESPONSE"
    fi
}

# Command: Info
cmd_info() {
    print_status "Detailed process information..."
    pm2 describe urban-points-api
}

# Command: Save
cmd_save() {
    print_status "Saving PM2 configuration..."
    pm2 save
    print_success "Configuration saved successfully"
}

# Command: Test
cmd_test() {
    print_status "Running comprehensive API tests..."
    
    if [ -f "./test_api.sh" ]; then
        bash ./test_api.sh
    else
        print_warning "test_api.sh not found, running basic health test only"
        cmd_health
    fi
}

# Command: Cleanup
cmd_cleanup() {
    print_status "Cleaning old logs..."
    
    # Keep only last 1000 lines of each log file
    if [ -f "./logs/pm2-out.log" ]; then
        tail -n 1000 ./logs/pm2-out.log > ./logs/pm2-out.log.tmp
        mv ./logs/pm2-out.log.tmp ./logs/pm2-out.log
        print_success "Cleaned pm2-out.log"
    fi
    
    if [ -f "./logs/pm2-error.log" ]; then
        tail -n 1000 ./logs/pm2-error.log > ./logs/pm2-error.log.tmp
        mv ./logs/pm2-error.log.tmp ./logs/pm2-error.log
        print_success "Cleaned pm2-error.log"
    fi
    
    pm2 flush urban-points-api
    print_success "PM2 logs flushed"
}

# Main script logic
case "${1:-}" in
    status)
        cmd_status
        ;;
    start)
        cmd_start
        ;;
    stop)
        cmd_stop
        ;;
    restart)
        cmd_restart
        ;;
    reload)
        cmd_reload
        ;;
    logs)
        cmd_logs
        ;;
    logs-error)
        cmd_logs_error
        ;;
    monitor)
        cmd_monitor
        ;;
    health)
        cmd_health
        ;;
    info)
        cmd_info
        ;;
    save)
        cmd_save
        ;;
    test)
        cmd_test
        ;;
    cleanup)
        cmd_cleanup
        ;;
    *)
        show_usage
        exit 1
        ;;
esac

exit 0
