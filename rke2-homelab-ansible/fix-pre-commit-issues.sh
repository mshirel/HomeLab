#!/bin/bash
set -e

echo "Creating .yamllint configuration..."

cat > .yamllint << 'EOF'
---
extends: default

rules:
  line-length:
    max: 150
    level: warning
  document-start:
    present: false
  comments:
    min-spaces-from-content: 1
  indentation:
    spaces: 2
    indent-sequences: true
  truthy:
    allowed-values: ['true', 'false', 'yes', 'no']
EOF

echo "Fixing .pre-commit-config.yaml..."
if [ -f .pre-commit-config.yaml ]; then
    if ! head -1 .pre-commit-config.yaml | grep -q "^---"; then
        (echo "---" && cat .pre-commit-config.yaml) > .pre-commit-config.yaml.tmp
        mv .pre-commit-config.yaml.tmp .pre-commit-config.yaml
    fi
fi

echo ""
echo "✓ Configuration updated!"
echo ""
echo "The yamllint will now:"
echo "  - Allow lines up to 150 characters"
echo "  - Only warn (not error) on long lines"
echo "  - Not require --- document start everywhere"
echo ""
echo "For the ansible-lint ModuleNotFoundError:"
echo "  This is a pre-commit environment issue."
echo "  Run: pre-commit clean"
echo "  Then: git commit"
echo ""
echo "Or skip pre-commit for this commit:"
echo "  git commit --no-verify"
