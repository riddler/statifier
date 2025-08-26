# GitHub Workflows

This directory contains the CI/CD workflows for the SC project.

## Workflow Strategy

### **Conditional Execution Based on File Changes**

The workflows are designed to run conditionally based on what files have been changed:

#### **Code Changes** → `ci.yml`

- **Triggers**: Changes to `.ex`, `.exs`, `mix.exs`, `mix.lock`, `config/`, etc.
- **Skips**: Documentation files (`.md`), license files, `.gitignore`
- **Jobs**: Full CI pipeline (compile, format, test, credo, dialyzer, regression tests)
- **Purpose**: Validates code quality, functionality, and compatibility

#### **Documentation Changes** → `docs.yml`  

- **Triggers**: Changes to `.md` files, `docs/` directory
- **Jobs**: Markdown linting, link checking, documentation validation
- **Purpose**: Ensures documentation quality and consistency

### **Benefits**

- ✅ **Faster feedback** - Documentation changes don't run expensive code tests
- ✅ **Resource efficient** - Saves CI minutes on documentation-only changes
- ✅ **Focused validation** - Each workflow validates what actually changed
- ✅ **Clear separation** - Code and documentation validation are distinct concerns

### **Example Scenarios**

| Change | ci.yml | docs.yml | Result |
|--------|--------|----------|---------|
| `lib/sc/validator.ex` | ✅ Runs | ❌ Skipped | Full code validation |
| `README.md` | ❌ Skipped | ✅ Runs | Documentation validation only |
| `lib/sc/state.ex` + `CLAUDE.md` | ✅ Runs | ✅ Runs | Both workflows run |

## Workflows

### **`ci.yml`** - Main CI Pipeline

- **Compilation** - Compile with warnings as errors
- **Code Formatting** - Verify `mix format` compliance  
- **Testing** - Multi-version testing with coverage (Elixir 1.17+ / OTP 26+)
- **Static Analysis** - Credo strict mode validation
- **Type Checking** - Dialyzer static analysis
- **Regression Testing** - Critical functionality validation

### **`docs.yml`** - Documentation Pipeline  

- **Markdown Linting** - Style and structure validation
- **Link Checking** - Verify external links are valid
- **Memory Validation** - Ensure CLAUDE.md and README.md have required sections
- **API Consistency** - Check that documentation references current API

## Configuration Files

- **`markdown-link-check-config.json`** - Link checker configuration with retry policies
