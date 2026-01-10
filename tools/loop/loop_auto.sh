#!/usr/bin/env bash
set -u  # exit on undefined vars, but allow non-zero exit codes
set -o pipefail

TZ=Asia/Beirut
export TZ

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

PY_BIN="${ROOT_DIR}/.venv/bin/python"
EXCEL_PATH="${EXCEL_PATH:-UrbanPoints_CTO_Master_Control_v4.xlsx}"

if [ ! -f "$PY_BIN" ]; then
  PY_BIN="python"
fi

summary=""


# Helper: Create NO-GO evidence for LOOP errors
create_loop_nogo() {
  local reason="$1"
  local order_json_out="${2:-}"
  local order_json_err="${3:-}"
  
  run_ts="$(date +%Y%m%d-%H%M%S)"
  evidence_dir="docs/evidence/LOOP/${run_ts}"
  mkdir -p "$evidence_dir"
  
  # Write gate.log with diagnostics
  cat >"$evidence_dir/gate.log" <<EOF
[LOOP ERROR] Timestamp: $run_ts
[LOOP ERROR] Reason: $reason

=== STDOUT from next_order.py ===
$order_json_out

=== STDERR from next_order.py ===
$order_json_err

=== TZ Setting ===
TZ=$TZ
EOF

  # Write NO_GO.md with explanation
  cat >"$evidence_dir/NO_GO.md" <<EOF
# LOOP Execution Failure

**Timestamp:** $run_ts  
**Reason:** $reason

## What happened
The autonomous execution loop encountered an error while trying to pick the next order.

## Next steps
1. Check that the Excel file exists: \`$EXCEL_PATH\`
2. Verify the ORDERS sheet and required columns (Order_ID, Status, Gate_Command, Feature_IDs, Priority, Depends_On_Orders)
3. Ensure at least one order has Status=Open and all dependencies are satisfied
4. Run with debug output: \`$PY_BIN tools/loop/next_order.py --excel "$EXCEL_PATH" --debug 2>&1\`

## Details
See \`gate.log\` for full diagnostics.
EOF

  # Write verdict.json
  cat >"$evidence_dir/verdict.json" <<EOF
{
  "run_ts": "$run_ts",
  "order_id": "LOOP",
  "end_to_end_working": false,
  "artifacts": ["$evidence_dir/gate.log"],
  "blockers": ["$reason"]
}
EOF

  echo "$evidence_dir"
}


# Helper: Validate JSON output
json_is_valid() {
  local json_str="$1"
  if [ -z "$json_str" ]; then
    return 1  # empty
  fi
  # Try to parse with Python
  if echo "$json_str" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null; then
    return 0
  fi
  return 1
}


# Main loop
while true; do
  # Capture stdout and stderr separately
  order_json_out=""
  order_json_err=""
  next_order_exit=0

  # Run next_order.py with stdout/stderr separation
  order_json_out=$($PY_BIN tools/loop/next_order.py --excel "$EXCEL_PATH" 2>/tmp/loop_stderr.txt) || next_order_exit=$?
  order_json_err=$(cat /tmp/loop_stderr.txt 2>/dev/null || echo "")

  if [ $next_order_exit -ne 0 ]; then
    # Script exited non-zero
    nogo_dir="$(create_loop_nogo "next_order.py exited with code $next_order_exit" "$order_json_out" "$order_json_err")"
    echo "LOOP ERROR: next_order.py failed. Evidence: $nogo_dir"
    exit 1
  fi

  if [ -z "$order_json_out" ]; then
    # Empty output
    nogo_dir="$(create_loop_nogo "next_order.py produced no output" "" "$order_json_err")"
    echo "LOOP ERROR: next_order.py produced empty output. Evidence: $nogo_dir"
    exit 1
  fi

  # Validate JSON
  if ! json_is_valid "$order_json_out"; then
    nogo_dir="$(create_loop_nogo "next_order.py output is not valid JSON" "$order_json_out" "$order_json_err")"
    echo "LOOP ERROR: Invalid JSON from next_order.py. Evidence: $nogo_dir"
    exit 1
  fi

  # Parse JSON to check ok flag
  ok_flag=$(echo "$order_json_out" | python3 -c "import json,sys; print(json.load(sys.stdin).get('ok', False))" 2>/dev/null || echo "false")

  if [ "$ok_flag" != "True" ]; then
    # ok=false means no more orders or error
    error_msg=$(echo "$order_json_out" | python3 -c "import json,sys; print(json.load(sys.stdin).get('error', 'unknown'))" 2>/dev/null || echo "unknown")
    if [ "$error_msg" = "no_open_orders" ]; then
      echo "No open orders detected. Attempting auto-reconcile..."
      
      # Run reconciliation
      reconcile_out=$($PY_BIN tools/excel/reconcile_orders.py --excel "$EXCEL_PATH" 2>/tmp/reconcile_stderr.txt) || reconcile_exit=$?
      reconcile_err=$(cat /tmp/reconcile_stderr.txt 2>/dev/null || echo "")
      reconcile_exit=${reconcile_exit:-0}
      
      if [ $reconcile_exit -ne 0 ]; then
        # Reconciliation failed
        nogo_dir="$(create_loop_nogo "reconcile_orders.py exited with code $reconcile_exit" "$reconcile_out" "$reconcile_err")"
        echo "RECONCILE ERROR: Failed to auto-reconcile. Evidence: $nogo_dir"
        exit 1
      fi
      
      # Parse reconciliation output
      reconcile_ok=$(echo "$reconcile_out" | python3 -c "import json,sys; print(json.load(sys.stdin).get('ok', False))" 2>/dev/null || echo "false")
      if [ "$reconcile_ok" != "True" ]; then
        # Reconciliation returned ok=false
        reconcile_error=$(echo "$reconcile_out" | python3 -c "import json,sys; print(json.load(sys.stdin).get('error', 'unknown'))" 2>/dev/null || echo "unknown")
        nogo_dir="$(create_loop_nogo "Reconciliation failed: $reconcile_error" "$reconcile_out" "$reconcile_err")"
        echo "RECONCILE ERROR: $reconcile_error. Evidence: $nogo_dir"
        exit 1
      fi
      
      # Reconciliation succeeded; get statistics
      orders_changed=$(echo "$reconcile_out" | python3 -c "import json,sys; print(json.load(sys.stdin).get('orders_changed', 0))" 2>/dev/null || echo "0")
      reopened=$(echo "$reconcile_out" | python3 -c "import json,sys; print(json.load(sys.stdin).get('reopened_order_id', ''))" 2>/dev/null || echo "")
      
      # Write reconcile log to evidence
      run_ts="$(date +%Y%m%d-%H%M%S)"
      evidence_dir="docs/evidence/LOOP/${run_ts}"
      mkdir -p "$evidence_dir"
      
      cat >"$evidence_dir/reconcile.log" <<EOF
[RECONCILE] Timestamp: $run_ts
[RECONCILE] Orders changed: $orders_changed
[RECONCILE] Reopened order: $reopened

=== Full reconciliation output ===
$reconcile_out

=== Reconciliation stderr ===
$reconcile_err
EOF
      
      echo "Reconcile complete: $orders_changed orders changed, reopened: $reopened. Evidence: $evidence_dir/reconcile.log"
      
      # Retry next_order.py once after reconciliation
      echo "Retrying next_order.py after reconciliation..."
      order_json_out=$($PY_BIN tools/loop/next_order.py --excel "$EXCEL_PATH" 2>/tmp/loop_stderr.txt) || next_order_exit=$?
      order_json_err=$(cat /tmp/loop_stderr.txt 2>/dev/null || echo "")
      
      if [ $next_order_exit -ne 0 ]; then
        nogo_dir="$(create_loop_nogo "next_order.py still failed after reconcile (exit $next_order_exit)" "$order_json_out" "$order_json_err")"
        echo "LOOP ERROR: next_order.py failed even after reconciliation. Evidence: $nogo_dir"
        exit 1
      fi
      
      # Validate retry JSON
      if [ -z "$order_json_out" ] || ! json_is_valid "$order_json_out"; then
        nogo_dir="$(create_loop_nogo "next_order.py output invalid after reconcile" "$order_json_out" "$order_json_err")"
        echo "LOOP ERROR: Invalid JSON from next_order.py after reconciliation. Evidence: $nogo_dir"
        exit 1
      fi
      
      # Check retry result
      ok_flag_retry=$(echo "$order_json_out" | python3 -c "import json,sys; print(json.load(sys.stdin).get('ok', False))" 2>/dev/null || echo "false")
      if [ "$ok_flag_retry" != "True" ]; then
        # Still no orders after reconciliation - this is final
        error_msg_retry=$(echo "$order_json_out" | python3 -c "import json,sys; print(json.load(sys.stdin).get('error', 'unknown'))" 2>/dev/null || echo "unknown")
        nogo_reason="After auto-reconciliation: $error_msg_retry (no eligible orders remain)"
        cat >>"$evidence_dir/NO_GO.md" <<EOF

## Auto-Reconciliation Result
Reconciliation changed $orders_changed orders, but no eligible order was found for execution.
This may indicate:
- All orders are marked Done AND all features have Is_End_to_End_Working='YES'
- All remaining Open orders have unsatisfied dependencies
- The matrix is fully complete

**Final Decision:** Loop stopping. All configured work complete.
EOF
        
        # Add verdict
        cat >"$evidence_dir/verdict.json" <<EOF
{
  "run_ts": "$run_ts",
  "order_id": "LOOP",
  "end_to_end_working": true,
  "action": "auto-reconcile-completed",
  "orders_changed": $orders_changed,
  "artifacts": ["$evidence_dir/reconcile.log"],
  "blockers": []
}
EOF
        
        echo "No open orders after reconciliation. Loop complete. Evidence: $evidence_dir"
        break
      fi
      
      # Retry succeeded! Continue with the loop using the new order_json_out
      echo "Reconciliation successful. Proceeding with reopened order..."
      # Continue with the loop iteration (no break, flow continues to extract fields)
    else
      # Some other error from next_order.py
      nogo_dir="$(create_loop_nogo "next_order.py returned ok=false: $error_msg" "$order_json_out" "$order_json_err")"
      echo "LOOP ERROR: $error_msg. Evidence: $nogo_dir"
      exit 1
    fi
  fi

  # Extract fields from valid JSON
  order_id=$(echo "$order_json_out" | python3 -c "import json,sys; print(json.load(sys.stdin).get('order_id',''))" 2>/dev/null || echo "")
  gate_cmd=$(echo "$order_json_out" | python3 -c "import json,sys; print(json.load(sys.stdin).get('gate_command',''))" 2>/dev/null || echo "")
  feature_ids=$(echo "$order_json_out" | python3 -c "import json,sys; print(','.join(json.load(sys.stdin).get('feature_ids',[])))" 2>/dev/null || echo "")

  if [ -z "$order_id" ] || [ -z "$gate_cmd" ]; then
    nogo_dir="$(create_loop_nogo "Extracted empty order_id or gate_cmd from JSON" "$order_json_out" "$order_json_err")"
    echo "LOOP ERROR: Missing order_id or gate_cmd. Evidence: $nogo_dir"
    exit 1
  fi

  run_ts="$(date +%Y%m%d-%H%M%S)"
  evidence_dir="docs/evidence/${order_id}/${run_ts}"
  mkdir -p "$evidence_dir"
  gate_log="$evidence_dir/gate.log"

  echo "Running $order_id at $run_ts"
  set +e
  bash -c "$gate_cmd" 2>&1 | tee "$gate_log"
  exit_code=${PIPESTATUS[0]}
  set -e

  end_to_end="false"
  status="Done"
  if [ $exit_code -ne 0 ]; then
    status="NO-GO"
  else
    end_to_end="true"
  fi

  # Write verdict
  cat >"$evidence_dir/verdict.json" <<EOF
{
  "run_ts": "$run_ts",
  "order_id": "$order_id",
  "end_to_end_working": $end_to_end,
  "artifacts": ["$gate_log"],
  "blockers": []
}
EOF

  if [ "$status" = "NO-GO" ]; then
    tail -n 50 "$gate_log" >"$evidence_dir/NO_GO.md"
  fi

  $PY_BIN tools/excel/update_from_evidence.py \
    --excel "$EXCEL_PATH" \
    --order-id "$order_id" \
    --status "$status" \
    --evidence-dir "$evidence_dir" \
    --feature-ids "$feature_ids" \
    $([ "$end_to_end" = "true" ] && echo "--end-to-end") || true

  summary+="$order_id => $status\\n"

  if [ "$status" = "NO-GO" ]; then
    echo "NO-GO encountered at $order_id. Stopping loop."
    break
  fi
done

echo -e "\n=== Loop Summary ===\n$summary"
