#!/bin/bash

###############################################################################
# Cloud Monitoring and Alerting Setup Script
# 
# Purpose: Configure Google Cloud Monitoring, dashboards, and alerting policies
# for Urban Points Lebanon Cloud Functions
# 
# Requirements:
# - gcloud CLI installed and authenticated
# - monitoring.admin IAM role
###############################################################################

set -e

PROJECT_ID="${FIREBASE_PROJECT_ID:-urbangenspark}"
NOTIFICATION_CHANNEL_ID="${NOTIFICATION_CHANNEL_ID:-}"
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
ALERT_EMAIL="${ALERT_EMAIL:-alerts@urbanpoints.lb}"

echo "========================================="
echo "Setting up Cloud Monitoring & Alerting"
echo "Project: $PROJECT_ID"
echo "========================================="

gcloud config set project "$PROJECT_ID"

# ============================================================================
# 1. CREATE NOTIFICATION CHANNELS
# ============================================================================

echo "Creating notification channels..."

# Email notification channel
EMAIL_CHANNEL=$(gcloud alpha monitoring channels create \
    --display-name="Urban Points Alerts Email" \
    --type=email \
    --channel-labels=email_address="$ALERT_EMAIL" \
    --format="value(name)" 2>/dev/null || echo "")

if [ -n "$EMAIL_CHANNEL" ]; then
    echo "✅ Email notification channel created: $EMAIL_CHANNEL"
    NOTIFICATION_CHANNEL_ID="$EMAIL_CHANNEL"
else
    echo "⚠️  Email notification channel already exists or failed to create"
fi

# Slack notification channel (if webhook provided)
if [ -n "$SLACK_WEBHOOK_URL" ]; then
    SLACK_CHANNEL=$(gcloud alpha monitoring channels create \
        --display-name="Urban Points Slack Alerts" \
        --type=slack \
        --channel-labels=url="$SLACK_WEBHOOK_URL" \
        --format="value(name)" 2>/dev/null || echo "")
    
    if [ -n "$SLACK_CHANNEL" ]; then
        echo "✅ Slack notification channel created: $SLACK_CHANNEL"
    fi
fi

# ============================================================================
# 2. CREATE ALERTING POLICIES
# ============================================================================

echo "Creating alerting policies..."

# Alert 1: High Cloud Function Error Rate
cat > /tmp/alert-policy-errors.yaml <<EOF
displayName: "Cloud Functions - High Error Rate"
conditions:
  - displayName: "Error rate > 5%"
    conditionThreshold:
      filter: |
        resource.type="cloud_function"
        metric.type="cloudfunctions.googleapis.com/function/execution_count"
        metric.label.status!="ok"
      aggregations:
        - alignmentPeriod: 300s
          perSeriesAligner: ALIGN_RATE
          crossSeriesReducer: REDUCE_SUM
          groupByFields:
            - resource.function_name
      comparison: COMPARISON_GT
      thresholdValue: 0.05
      duration: 300s
enabled: true
notificationChannels:
  - $NOTIFICATION_CHANNEL_ID
alertStrategy:
  autoClose: 604800s
documentation:
  content: |
    Cloud Function error rate exceeded 5%.
    Check logs: https://console.cloud.google.com/logs
  mimeType: text/markdown
EOF

gcloud alpha monitoring policies create --policy-from-file=/tmp/alert-policy-errors.yaml 2>/dev/null \
    && echo "✅ Alert policy created: High Error Rate" \
    || echo "⚠️  High Error Rate policy may already exist"

# Alert 2: High Function Execution Time
cat > /tmp/alert-policy-latency.yaml <<EOF
displayName: "Cloud Functions - High Latency"
conditions:
  - displayName: "95th percentile latency > 3 seconds"
    conditionThreshold:
      filter: |
        resource.type="cloud_function"
        metric.type="cloudfunctions.googleapis.com/function/execution_times"
      aggregations:
        - alignmentPeriod: 300s
          perSeriesAligner: ALIGN_DELTA
          crossSeriesReducer: REDUCE_PERCENTILE_95
          groupByFields:
            - resource.function_name
      comparison: COMPARISON_GT
      thresholdValue: 3000
      duration: 300s
enabled: true
notificationChannels:
  - $NOTIFICATION_CHANNEL_ID
alertStrategy:
  autoClose: 604800s
documentation:
  content: |
    Cloud Function latency exceeded 3 seconds (95th percentile).
    Investigate slow functions and optimize performance.
  mimeType: text/markdown
EOF

gcloud alpha monitoring policies create --policy-from-file=/tmp/alert-policy-latency.yaml 2>/dev/null \
    && echo "✅ Alert policy created: High Latency" \
    || echo "⚠️  High Latency policy may already exist"

# Alert 3: Scheduler Job Failures
cat > /tmp/alert-policy-scheduler.yaml <<EOF
displayName: "Cloud Scheduler - Job Failures"
conditions:
  - displayName: "Scheduler job failed"
    conditionThreshold:
      filter: |
        resource.type="cloud_scheduler_job"
        metric.type="cloudscheduler.googleapis.com/job/attempt_count"
        metric.label.response_class="5xx"
      aggregations:
        - alignmentPeriod: 300s
          perSeriesAligner: ALIGN_SUM
      comparison: COMPARISON_GT
      thresholdValue: 0
      duration: 60s
enabled: true
notificationChannels:
  - $NOTIFICATION_CHANNEL_ID
alertStrategy:
  autoClose: 86400s
documentation:
  content: |
    Cloud Scheduler job failed with 5xx error.
    Check function logs and ensure scheduled jobs are running correctly.
  mimeType: text/markdown
EOF

gcloud alpha monitoring policies create --policy-from-file=/tmp/alert-policy-scheduler.yaml 2>/dev/null \
    && echo "✅ Alert policy created: Scheduler Failures" \
    || echo "⚠️  Scheduler Failures policy may already exist"

# Alert 4: Firestore Read/Write Spikes
cat > /tmp/alert-policy-firestore.yaml <<EOF
displayName: "Firestore - High Read/Write Operations"
conditions:
  - displayName: "Firestore operations > 10,000/min"
    conditionThreshold:
      filter: |
        resource.type="firestore.googleapis.com/Database"
        metric.type="firestore.googleapis.com/document/read_count"
      aggregations:
        - alignmentPeriod: 60s
          perSeriesAligner: ALIGN_RATE
          crossSeriesReducer: REDUCE_SUM
      comparison: COMPARISON_GT
      thresholdValue: 10000
      duration: 300s
enabled: true
notificationChannels:
  - $NOTIFICATION_CHANNEL_ID
alertStrategy:
  autoClose: 604800s
documentation:
  content: |
    Firestore read operations exceeded 10,000 per minute.
    Monitor for potential runaway queries or attacks.
  mimeType: text/markdown
EOF

gcloud alpha monitoring policies create --policy-from-file=/tmp/alert-policy-firestore.yaml 2>/dev/null \
    && echo "✅ Alert policy created: Firestore Operations" \
    || echo "⚠️  Firestore Operations policy may already exist"

# ============================================================================
# 3. CREATE CUSTOM DASHBOARD
# ============================================================================

echo "Creating custom monitoring dashboard..."

cat > /tmp/dashboard.json <<'EOF'
{
  "displayName": "Urban Points Lebanon - System Health",
  "mosaicLayout": {
    "columns": 12,
    "tiles": [
      {
        "width": 6,
        "height": 4,
        "widget": {
          "title": "Cloud Functions - Execution Count",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "resource.type=\"cloud_function\" metric.type=\"cloudfunctions.googleapis.com/function/execution_count\"",
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "perSeriesAligner": "ALIGN_RATE",
                      "crossSeriesReducer": "REDUCE_SUM",
                      "groupByFields": ["resource.function_name"]
                    }
                  }
                }
              }
            ]
          }
        }
      },
      {
        "xPos": 6,
        "width": 6,
        "height": 4,
        "widget": {
          "title": "Cloud Functions - Error Rate",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "resource.type=\"cloud_function\" metric.type=\"cloudfunctions.googleapis.com/function/execution_count\" metric.label.status!=\"ok\"",
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "perSeriesAligner": "ALIGN_RATE",
                      "crossSeriesReducer": "REDUCE_SUM",
                      "groupByFields": ["resource.function_name"]
                    }
                  }
                }
              }
            ]
          }
        }
      },
      {
        "yPos": 4,
        "width": 12,
        "height": 4,
        "widget": {
          "title": "Cloud Functions - Latency (95th percentile)",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "resource.type=\"cloud_function\" metric.type=\"cloudfunctions.googleapis.com/function/execution_times\"",
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "perSeriesAligner": "ALIGN_DELTA",
                      "crossSeriesReducer": "REDUCE_PERCENTILE_95",
                      "groupByFields": ["resource.function_name"]
                    }
                  }
                }
              }
            ]
          }
        }
      }
    ]
  }
}
EOF

gcloud monitoring dashboards create --config-from-file=/tmp/dashboard.json 2>/dev/null \
    && echo "✅ Custom dashboard created" \
    || echo "⚠️  Dashboard may already exist"

# ============================================================================
# 4. ENABLE LOG-BASED METRICS
# ============================================================================

echo "Creating log-based metrics..."

# Metric: Payment failures
gcloud logging metrics create payment_failures \
    --description="Count of payment failures" \
    --log-filter='resource.type="cloud_function"
severity="ERROR"
jsonPayload.type="payment_failed"' \
    2>/dev/null && echo "✅ Log metric created: payment_failures" || echo "⚠️  payment_failures metric may already exist"

# Metric: Subscription renewals
gcloud logging metrics create subscription_renewals \
    --description="Count of subscription renewal attempts" \
    --log-filter='resource.type="cloud_function"
jsonPayload.message:"Processing renewals"' \
    2>/dev/null && echo "✅ Log metric created: subscription_renewals" || echo "⚠️  subscription_renewals metric may already exist"

echo "========================================="
echo "✅ Monitoring and alerting setup complete!"
echo ""
echo "Next steps:"
echo "1. View dashboards: https://console.cloud.google.com/monitoring/dashboards"
echo "2. Manage alert policies: https://console.cloud.google.com/monitoring/alerting/policies"
echo "3. Configure notification channels: https://console.cloud.google.com/monitoring/alerting/notifications"
echo "========================================="

exit 0
