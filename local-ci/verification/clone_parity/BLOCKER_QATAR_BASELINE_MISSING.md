# BLOCKER: Qatar Baseline Missing

**Status:** NO-GO

**Reason:** Baseline YAML has no 'features' list.

**Requirement:** Place docs/QATAR_BASELINE_FEATURES.yaml with schema:

```yaml
features:
  - id: F001
    title: Customer Signup
    description: Basic signup with phone or email
    surface: customer
    flows:
      - "Open app > Signup > Verify > Home"
```

Alternative accepted files:
1) docs/QATAR_BASELINE_FEATURES.yaml
2) docs/QATAR_BASELINE_FEATURES.md
3) spec/qatar_baseline.yaml
4) docs/qatar_feature_matrix.xlsx (optional)

This tool will STOP until one of these files exists.
