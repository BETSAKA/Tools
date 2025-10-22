#!/bin/bash
set -eu

FULL_NAME="$1"                           # e.g. BETSAKA/training
REPO_URL="https://${GIT_PERSONAL_ACCESS_TOKEN}@github.com/${FULL_NAME}.git"

# Onyxia sets this; default as fallback
WORKSPACE_DIR="${WORKSPACE_DIR:-/home/onyxia/work}"

# Optional: start clean (keep if workspace is ephemeral)
rm -rf "${WORKSPACE_DIR:?}/"* "${WORKSPACE_DIR}"/.[!.]* "${WORKSPACE_DIR}"/..?* 2>/dev/null || true

# Clone directly into the workspace root (NOT a subfolder)
git clone "$REPO_URL" "$WORKSPACE_DIR/.tmp-repo"
rsync -a "$WORKSPACE_DIR/.tmp-repo"/ "$WORKSPACE_DIR"/
rm -rf "$WORKSPACE_DIR/.tmp-repo"

# Merge S3 payload on top (if exists)
mc cp -r "s3/projet-betsaka/$(basename "${FULL_NAME}")" "$WORKSPACE_DIR" || true

# Permissions
chown -R onyxia:users "$WORKSPACE_DIR"

# VS Code settings (same path you had)
SETTINGS_FILE="${HOME}/.local/share/code-server/User/settings.json"
mkdir -p "$(dirname "$SETTINGS_FILE")"
[ -f "$SETTINGS_FILE" ] || echo '{}' > "$SETTINGS_FILE"
jq '. + {
  "workbench.startupEditor": "none",
  "window.restoreWindows": "one",
  "files.trimTrailingWhitespace": true,
  "files.insertFinalNewline": true,
  "editor.rulers": [80,100,120],
  "terminal.integrated.cursorStyle": "line",
  "terminal.integrated.cursorBlinking": true,
  "r.plot.useHttpgd": true,
  "flake8.args": ["--max-line-length=100"]
}' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
