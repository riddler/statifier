#!/bin/bash

# Setup git hooks for the project

echo "🔧 Setting up git hooks..."

# Create .git/hooks directory if it doesn't exist
mkdir -p .git/hooks

# Copy pre-push hook
cp .githooks/pre-push .git/hooks/pre-push
chmod +x .git/hooks/pre-push

echo "✅ Git hooks installed successfully!"
echo ""
echo "The pre-push hook will now run:"
echo "  - Code formatting check"
echo "  - Regression tests"  
echo "  - Static analysis (Credo)"
echo ""
echo "To bypass the hook in emergencies, use: git push --no-verify"