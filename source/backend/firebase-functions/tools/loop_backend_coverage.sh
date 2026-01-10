#!/bin/bash
# Backend Coverage Loop Script
# Runs tests with coverage and tracks progress

set -e

TIMESTAMP=$(date +%s)
LOG_DIR="/home/user/ARTIFACTS/COMMAND_LOGS"
COVERAGE_DIR="/home/user/ARTIFACTS/COVERAGE"
LOOP_STATUS="/home/user/ARTIFACTS/LOOP_STATUS.md"
VERDICT_FILE="/home/user/ARTIFACTS/LOOP_FINAL_VERDICT.json"
LOG_FILE="$LOG_DIR/${TIMESTAMP}_backend_coverage.log"

mkdir -p "$LOG_DIR"
mkdir -p "$COVERAGE_DIR"

cd /home/user/urbanpoints-lebanon-complete-ecosystem/backend/firebase-functions

echo "========================================" | tee -a "$LOG_FILE"
echo "Backend Coverage Loop - $(date)" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"

# Run tests with coverage
echo "Running tests..." | tee -a "$LOG_FILE"
npm test -- --coverage --runInBand 2>&1 | tee -a "$LOG_FILE"

# Extract coverage metrics
COVERAGE_OUTPUT=$(tail -20 "$LOG_FILE")
STATEMENTS=$(echo "$COVERAGE_OUTPUT" | grep "Statements" | awk '{print $3}')
BRANCHES=$(echo "$COVERAGE_OUTPUT" | grep "Branches" | awk '{print $3}')
FUNCTIONS=$(echo "$COVERAGE_OUTPUT" | grep "Functions" | awk '{print $3}')
LINES=$(echo "$COVERAGE_OUTPUT" | grep "Lines" | awk '{print $3}')
TEST_PASS=$(echo "$COVERAGE_OUTPUT" | grep "Tests:" | awk '{print $2}')
TEST_TOTAL=$(echo "$COVERAGE_OUTPUT" | grep "Tests:" | awk '{print $4}')

# Copy coverage reports
if [ -d "coverage" ]; then
    cp -r coverage "$COVERAGE_DIR/${TIMESTAMP}"
    echo "Coverage reports copied to $COVERAGE_DIR/${TIMESTAMP}" | tee -a "$LOG_FILE"
fi

# Update loop status
echo "" >> "$LOOP_STATUS"
echo "## Loop Run - $(date)" >> "$LOOP_STATUS"
echo "- Timestamp: $TIMESTAMP" >> "$LOOP_STATUS"
echo "- Tests: $TEST_PASS / $TEST_TOTAL" >> "$LOOP_STATUS"
echo "- Coverage:" >> "$LOOP_STATUS"
echo "  - Statements: $STATEMENTS" >> "$LOOP_STATUS"
echo "  - Branches: $BRANCHES" >> "$LOOP_STATUS"
echo "  - Functions: $FUNCTIONS" >> "$LOOP_STATUS"
echo "  - Lines: $LINES" >> "$LOOP_STATUS"
echo "- Log: $LOG_FILE" >> "$LOOP_STATUS"

# Check if GO criteria met
GO_STATEMENTS=$(echo "$STATEMENTS" | sed 's/%//' | awk '{if($1>=80) print "PASS"; else print "FAIL"}')
GO_BRANCHES=$(echo "$BRANCHES" | sed 's/%//' | awk '{if($1>=80) print "PASS"; else print "FAIL"}')
GO_FUNCTIONS=$(echo "$FUNCTIONS" | sed 's/%//' | awk '{if($1>=80) print "PASS"; else print "FAIL"}')
GO_LINES=$(echo "$LINES" | sed 's/%//' | awk '{if($1>=80) print "PASS"; else print "FAIL"}')

if [ "$TEST_PASS" = "$TEST_TOTAL" ] && [ "$GO_STATEMENTS" = "PASS" ] && [ "$GO_BRANCHES" = "PASS" ] && [ "$GO_FUNCTIONS" = "PASS" ] && [ "$GO_LINES" = "PASS" ]; then
    VERDICT="GO"
    echo "✅ GO CRITERIA MET" | tee -a "$LOG_FILE"
else
    VERDICT="NO-GO"
    echo "❌ NO-GO: Coverage thresholds not met" | tee -a "$LOG_FILE"
fi

# Write verdict file
cat > "$VERDICT_FILE" << EOF
{
  "timestamp": "$TIMESTAMP",
  "verdict": "$VERDICT",
  "tests": {
    "passed": "$TEST_PASS",
    "total": "$TEST_TOTAL"
  },
  "coverage": {
    "statements": "$STATEMENTS",
    "branches": "$BRANCHES",
    "functions": "$FUNCTIONS",
    "lines": "$LINES"
  },
  "log_file": "$LOG_FILE",
  "coverage_dir": "$COVERAGE_DIR/${TIMESTAMP}"
}
EOF

echo "Verdict written to $VERDICT_FILE" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"

exit 0
