#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Onyxia VS Code init script (robust)
#
# Goals:
# - Clone a GitHub repo into /home/onyxia/work/<repo>
# - Optionally copy data from S3 (MinIO) using mc
# - Optionally create/sync a Python env with uv
# - Create sensible .vscode/settings.json
# - Optionally install GitHub Copilot extensions in code-server
#
# Works well with Onyxia patterns:
# - Env vars are commonly injected by the chart / Onyxia UI (extra env)
# - Git credentials may be provided as env vars (e.g. GIT_PERSONAL_ACCESS_TOKEN)
#
# Usage:
#   init.sh <github_owner/repo> [s3_prefix] [s3_subpath]
#
# Examples:
#   init.sh InseeFrLab/onyxia
#   init.sh fbedecarrats/PA_matching projet-betsaka
#   init.sh fbedecarrats/PA_matching fbedecarrats/Replication_wolf Replication_wolf_data
#
###############################################################################

log() { printf '%s\n' "$*"; }
warn() { printf 'Warning: %s\n' "$*" >&2; }
die() { printf 'Error: %s\n' "$*" >&2; exit 2; }

# --- Inputs (args) -----------------------------------------------------------
FULL_NAME="${1:-}"
SERV_FOLD="${2:-}"      # s3 prefix (bucket/dir as configured in mc alias)
S3_SUBPATH="${3:-}"     # optional path under SERV_FOLD

# --- Defaults for env vars (IMPORTANT with set -u) ----------------------------
COPILOT_MODE="${COPILOT_MODE:-none}"           # none|auto|fixed
GIT_PERSONAL_ACCESS_TOKEN="${GIT_PERSONAL_ACCESS_TOKEN:-}"
GIT_BRANCH="${GIT_BRANCH:-}"                   # optional
GIT_REPOSITORY="${GIT_REPOSITORY:-}"           # optional override (full URL)
GIT_USER_NAME="${GIT_USER_NAME:-}"
GIT_USER_MAIL="${GIT_USER_MAIL:-}"

# Prefer Onyxia-provided repo env var if present and arg omitted
if [[ -z "$FULL_NAME" && -n "$GIT_REPOSITORY" ]]; then
  # If they pass a full URL, we still need a directory name; derive from URL.
  # Supports: https://github.com/owner/repo(.git)
  # Best effort:
  FULL_NAME="$(printf '%s' "$GIT_REPOSITORY" | sed -E 's#^https?://github.com/##; s#\.git$##')"
fi

[[ -n "$FULL_NAME" ]] || die "Missing required argument <github_owner/repo> (or set GIT_REPOSITORY)."
[[ "$FULL_NAME" == */* ]] || die "Repo must be formatted as <owner>/<repo>, got: $FULL_NAME"

OWNER="${FULL_NAME%%/*}"
PROJ_NAME="${FULL_NAME##*/}"
[[ -n "$OWNER" && -n "$PROJ_NAME" ]] || die "Invalid repo name: $FULL_NAME"

WORK_ROOT="/home/onyxia/work"
WORK_DIR="${WORK_ROOT}/${PROJ_NAME}"

# Safety guard before rm -rf
case "$WORK_DIR" in
  "$WORK_ROOT" | "$WORK_ROOT/" ) die "Refusing to operate on WORK_DIR=$WORK_DIR";;
  "$WORK_ROOT"/* ) : ;;
  * ) die "Refusing to operate outside $WORK_ROOT (WORK_DIR=$WORK_DIR)";;
esac

# --- Optional: configure git identity if provided -----------------------------
if command -v git >/dev/null 2>&1; then
  if [[ -n "$GIT_USER_NAME" ]]; then
    git config --global user.name "$GIT_USER_NAME" || true
  fi
  if [[ -n "$GIT_USER_MAIL" ]]; then
    git config --global user.email "$GIT_USER_MAIL" || true
  fi
fi

# --- Build repo URL ----------------------------------------------------------
# If Onyxia/chart provides a full repo URL, use it.
# Otherwise, use https://github.com/<owner>/<repo>.git and optionally embed token.
REPO_URL=""
if [[ -n "$GIT_REPOSITORY" ]]; then
  REPO_URL="$GIT_REPOSITORY"
else
  if [[ -n "$GIT_PERSONAL_ACCESS_TOKEN" ]]; then
    # Works, but can leak into .git/config; we will sanitize origin after clone.
    REPO_URL="https://${GIT_PERSONAL_ACCESS_TOKEN}@github.com/${FULL_NAME}.git"
  else
    REPO_URL="https://github.com/${FULL_NAME}.git"
  fi
fi

# --- Clone -------------------------------------------------------------------
log "Preparing workspace at: $WORK_DIR"
rm -rf "$WORK_DIR"

log "Cloning $FULL_NAME"
git clone --depth 1 "$REPO_URL" "$WORK_DIR"

# Checkout branch if provided
if [[ -n "$GIT_BRANCH" ]]; then
  (
    cd "$WORK_DIR"
    # Best effort: works for branches/tags; may fail if not fetched with depth=1
    # If it fails, we try a fetch.
    git checkout "$GIT_BRANCH" 2>/dev/null || {
      warn "Checkout $GIT_BRANCH failed with shallow clone; fetching full history and retrying..."
      git fetch --all --tags || true
      git checkout "$GIT_BRANCH" || warn "Still could not checkout $GIT_BRANCH; continuing on default branch."
    }
  )
fi

# Sanitize origin URL if we embedded token
if [[ -n "$GIT_PERSONAL_ACCESS_TOKEN" && -z "$GIT_REPOSITORY" ]]; then
  (
    cd "$WORK_DIR"
    git remote set-url origin "https://github.com/${FULL_NAME}.git" || true
  )
fi

# --- Optional S3/MinIO copy via mc -------------------------------------------
# Convention: mc alias "s3" exists and points to MinIO/S3 endpoint.
# This matches many Onyxia setups where S3 credentials are injected as env vars.
if [[ -n "$SERV_FOLD" && "$SERV_FOLD" != "none" && "$SERV_FOLD" != "skip" ]]; then
  if [[ -z "$S3_SUBPATH" ]]; then
    S3_SUBPATH="$PROJ_NAME"
  fi

  if command -v mc >/dev/null 2>&1; then
    log "Copying from s3/${SERV_FOLD}/${S3_SUBPATH} into $WORK_DIR/"
    mkdir -p "$WORK_DIR"
    mc cp -r "s3/${SERV_FOLD}/${S3_SUBPATH}" "$WORK_DIR/" || \
      warn "S3 copy failed for s3/${SERV_FOLD}/${S3_SUBPATH}; continuing."
  else
    warn "mc not found; skipping S3 copy."
  fi
else
  log "Skipping S3 copy (no s3_prefix provided)."
fi

# --- Python env via uv (if present) ------------------------------------------
PROJECT_FILE="${WORK_DIR}/pyproject.toml"
if [[ -f "$PROJECT_FILE" ]]; then
  if command -v uv >/dev/null 2>&1; then
    log "Found pyproject.toml; running: uv sync"
    (
      cd "$WORK_DIR"
      uv sync --frozen --no-cache || warn "uv sync failed; continuing."
    )
  else
    warn "pyproject.toml present but uv is not installed; skipping uv sync."
  fi
fi

# --- VS Code workspace settings ----------------------------------------------
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

# --- code-server extensions (best effort) ------------------------------------
if command -v code-server >/dev/null 2>&1; then
  case "$COPILOT_MODE" in
    auto)
      log "Installing GitHub Copilot extensions (auto)"
      code-server --install-extension GitHub.copilot || true
      code-server --install-extension GitHub.copilot-chat || true
      ;;

    fixed)
      log "Installing GitHub Copilot extensions (fixed versions)"
      copilotVersion="1.129.0"
      copilotChatVersion="0.20.0"

      tmpdir="$(mktemp -d)"
      (
        cd "$tmpdir"
        # marketplace vspackage is commonly a vsix payload; keep best-effort behavior
        wget -q "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/GitHub/vsextensions/copilot/${copilotVersion}/vspackage" \
          -O copilot.vsix || true
        wget -q "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/GitHub/vsextensions/copilot-chat/${copilotChatVersion}/vspackage" \
          -O copilot-chat.vsix || true

        [[ -s copilot.vsix ]] && code-server --install-extension copilot.vsix || true
        [[ -s copilot-chat.vsix ]] && code-server --install-extension copilot-chat.vsix || true
      )
      rm -rf "$tmpdir"
      ;;

    none|"")
      log "Skipping Copilot installation (COPILOT_MODE=none)"
      ;;

    *)
      warn "Unknown COPILOT_MODE='$COPILOT_MODE' (expected none|auto|fixed); skipping Copilot install."
      ;;
  esac
fi

# --- Ownership fix (non-fatal) -----------------------------------------------
chown -R onyxia:users "$WORK_DIR" 2>/dev/null || true

log "Initialization complete. Project ready in $WORK_DIR"
