.PHONY: go go-quality verify

go:
	@echo "Starting GO_RUN self-healing pipeline (up to 8 attempts)..."
	@python3 tools/go_pipeline/go.py

go-quality:
	@echo "GO_QUALITY gates not implemented yet"
	@echo "Planned: lint + analyze stages"

verify:
	@echo "Verify requires evidence directory: make verify EVIDENCE_DIR=<path>"
	@if [ -z "$(EVIDENCE_DIR)" ]; then \
		echo "ERROR: EVIDENCE_DIR not set"; \
		exit 1; \
	fi
	@python3 tools/go_pipeline/verify.py $(EVIDENCE_DIR)
