#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   vscode.sh <github_owner/repo> [s3_prefix] [s3_subpath]
#
# Examples:
#   vscode.sh BETSAKA/PA_impacts_fires projet-betsaka
#     copies from s3/projet-betsaka/PA_impacts_fires to /home/onyxia/work/PA_impacts_fires
#
#   vscode.sh fbedecarrats/PA_matching fbedecarrats/Replication_wolf
#     copies from s3/fbedecarrats/Replication_wolf/PA_matching to /home/onyxia/work/PA_matching
#
#   vscode.sh fbedecarrats/PA_matching
#     clones only, no S3 copy
#
#   vscode.sh fbedecarrats/PA_matching fbedecarrats/Replication_wolf Replication_wolf_data
#     copies from s3/fbedecarrats/Replication_wolf/Replication_wolf_data to /home/onyxia/work/PA_matching

FULL_NAME="${1:-}"
SERV_FOLD="${2:-}"
S3_SUBPATH="${3:-}"

if [ -z "$FULL_NAME" ]; then
  echo "Error: missing required argument <github_owner/repo>" >&2
  exit 2
fi

PROJ_NAME="${FULL_NAME##*/}"
WORK_DIR="/home/onyxia/work/${PROJ_NAME}"

if [ -n "${GIT_PERSONAL_ACCESS_TOKEN:-}" ]; then
  REPO_URL="https://${GIT_PERSONAL_ACCESS_TOKEN}@github.com/${FULL_NAME}.git"
else
  REPO_URL="https://github.com/${FULL_NAME}.git"
fi

echo "Cloning ${FULL_NAME} into ${WORK_DIR}"
rm -rf "$WORK_DIR"
git clone "$REPO_URL" "$WORK_DIR"

# Optional S3 copy
if [ -n "$SERV_FOLD" ] && [ "$SERV_FOLD" != "none" ] && [ "$SERV_FOLD" != "skip" ]; then
  if [ -z "$S3_SUBPATH" ]; then
    S3_SUBPATH="$PROJ_NAME"
  fi

  if command -v mc >/dev/null 2>&1; then
    echo "Copying from s3/${SERV_FOLD}/${S3_SUBPATH} to /home/onyxia/work/${PROJ_NAME}"
    # Copy into the project folder so data lands inside the repo directory
    mkdir -p "$WORK_DIR"
    mc cp -r "s3/${SERV_FOLD}/${S3_SUBPATH}" "$WORK_DIR/" || {
      echo "Warning: S3 copy failed (s3/${SERV_FOLD}/${S3_SUBPATH}). Continuing." >&2
    }
  else
    echo "Warning: mc not found, skipping S3 copy." >&2
  fi
else
  echo "Skipping S3 copy (no s3_prefix provided)."
fi

# Python environment via uv if pyproject.toml exists
PROJECT_FILE="${WORK_DIR}/pyproject.toml"
if [ -f "$PROJECT_FILE" ] && command -v uv >/dev/null 2>&1; then
  echo "Found pyproject.toml, running uv sync"
  cd "$WORK_DIR"
  uv sync --frozen --no-cache || {
    echo "Warning: uv sync failed. Continuing." >&2
  }
fi

# VS Code settings
LOCAL_SETTINGS_DIR="${WORK_DIR}/.vscode"
mkdir -p "$LOCAL_SETTINGS_DIR"

cat > "${LOCAL_SETTINGS_DIR}/settings.json" <<'JSON'
{
  "workbench.panel.defaultLocation": "right",
  "workbench.editor.openSideBySideDirection": "down",
  "editor.rulers": [80, 100, 120],
  "files.trimTrailingWhitespace": true,
  "files.insertFinalNewline": true,
  "terminal.integrated.cursorStyle": "line",
  "terminal.integrated.cursorBlinking": true,
  "chat.extensionUnification.enabled": false,
  "cSpell.enabled": false,
  "r.plot.useHttpgd": true,
  "r.lsp.diagnostics": false,
  "flake8.enabled": false,
  "[python]": {
    "editor.defaultFormatter": "charliermarsh.ruff",
    "editor.formatOnSave": true,
    "editor.codeActionsOnSave": {
      "source.fixAll.ruff": "explicit",
      "source.organizeImports.ruff": "explicit"
    }
  }
}
JSON

# Install VS Code extensions (best effort)
if command -v code-server >/dev/null 2>&1; then
  if [ "$COPILOT_MODE" = "auto" ]; then
    echo "Installing Copilot (auto mode)"
    code-server --install-extension GitHub.copilot || true
    code-server --install-extension GitHub.copilot-chat || true

  elif [ "$COPILOT_MODE" = "fixed" ]; then
    echo "Installing Copilot (fixed version mode)"

    copilotVersion="1.129.0"
    copilotChatVersion="0.20.0"

    tmpdir="$(mktemp -d)"
    (
      cd "$tmpdir"
      wget -q \
        "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/GitHub/vsextensions/copilot/${copilotVersion}/vspackage" \
        -O copilot.vsix.gz || true
      wget -q \
        "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/GitHub/vsextensions/copilot-chat/${copilotChatVersion}/vspackage" \
        -O copilot-chat.vsix.gz || true

      gzip -d copilot.vsix.gz 2>/dev/null || true
      gzip -d copilot-chat.vsix.gz 2>/dev/null || true

      code-server --install-extension copilot.vsix || true
      code-server --install-extension copilot-chat.vsix || true
    )
    rm -rf "$tmpdir"

  elif [ "$COPILOT_MODE" = "none" ]; then
    echo "Skipping Copilot installation"
  fi
fi

# Ownership fix (best effort)
chown -R onyxia:users "$WORK_DIR" 2>/dev/null || true

echo "Initialization complete. Project ready in $WORK_DIR"
