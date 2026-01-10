#!/bin/bash
# Quick test of the fixed condition
HEALTH_RESPONSE=$(curl -s http://localhost:3000/api/health)
if echo "$HEALTH_RESPONSE" | grep -q 'healthy'; then
    echo "✅ Health check PASSED"
else
    echo "❌ Health check FAILED"
fi
