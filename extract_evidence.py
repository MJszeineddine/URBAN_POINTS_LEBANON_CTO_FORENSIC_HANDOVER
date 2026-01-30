#!/usr/bin/env python3
import subprocess
import json

evidence = {
    "firebase_exports": [],
    "rest_api_routes": [],
    "tests_detected": [],
    "ci_workflows": [],
    "auth_implementation": [],
    "payment_implementation": []
}

# Firebase function exports
try:
    result = subprocess.run(
        ["grep", "-r", "export const", "source/backend/firebase-functions/src/", "--include=*.ts"],
        capture_output=True, text=True
    )
    for line in result.stdout.strip().split('\n'):
        if line:
            evidence["firebase_exports"].append(line.split("source/backend/firebase-functions/")[1][:80])
except:
    pass

# REST API routes
try:
    result = subprocess.run(
        ["grep", "-r", "router\\.", "source/backend/rest-api/src/routes", "--include=*.ts"],
        capture_output=True, text=True
    )
    for line in result.stdout.strip().split('\n')[:20]:
        if line:
            evidence["rest_api_routes"].append(line.split("source/backend/rest-api/")[1][:80])
except:
    pass

# Test files
try:
    result = subprocess.run(
        ["find", "source", "-name", "*.test.ts", "-o", "-name", "*.spec.ts"],
        capture_output=True, text=True
    )
    evidence["tests_detected"] = [f for f in result.stdout.strip().split('\n') if f][:15]
except:
    pass

# CI workflows
try:
    result = subprocess.run(
        ["find", ".github/workflows", "-name", "*.yml"],
        capture_output=True, text=True
    )
    evidence["ci_workflows"] = [f for f in result.stdout.strip().split('\n') if f]
except:
    pass

with open("local-ci/verification/reality_map/LATEST/extract/evidence.json", "w") as f:
    json.dump(evidence, f, indent=2)

print("Evidence extraction complete")
print(f"Firebase exports: {len(evidence['firebase_exports'])}")
print(f"REST routes: {len(evidence['rest_api_routes'])}")
print(f"Tests: {len(evidence['tests_detected'])}")
print(f"CI Workflows: {len(evidence['ci_workflows'])}")
