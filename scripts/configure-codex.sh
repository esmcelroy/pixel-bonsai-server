#!/bin/sh
set -eu

project_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
profile_name=${1:-pixel-bonsai}
context_size=${2:-16384}
codex_config_dir=${CODEX_HOME:-"$HOME/.codex"}
profile_file="$codex_config_dir/$profile_name.config.toml"
catalog_file="$codex_config_dir/pixel-bonsai-models.json"

case "$context_size" in
  ''|*[!0-9]*)
    echo "Context size must be a positive integer." >&2
    exit 2
    ;;
esac
if [ "$context_size" -le 0 ]; then
  echo "Context size must be a positive integer." >&2
  exit 2
fi
if [ ! -f "$profile_file" ]; then
  echo "Missing Codex profile: $profile_file" >&2
  echo "Create the profile first, then rerun $0 [profile-name] [context-size]." >&2
  exit 1
fi

compact_limit=$((context_size * 3 / 4))
mkdir -p "$codex_config_dir"
sed \
  -e "s/\"context_window\": 16384/\"context_window\": $context_size/" \
  -e "s/\"max_context_window\": 16384/\"max_context_window\": $context_size/" \
  -e "s/\"auto_compact_token_limit\": 12288/\"auto_compact_token_limit\": $compact_limit/" \
  "$project_root/config/codex-models.json" > "$catalog_file"

profile_tmp=$(mktemp "${TMPDIR:-/tmp}/pixel-bonsai-profile.XXXXXX")
trap 'rm -f "$profile_tmp"' EXIT HUP INT TERM

awk \
  -v catalog="$catalog_file" \
  -v context_size="$context_size" \
  -v compact_limit="$compact_limit" '
  BEGIN {
    catalog_written = 0
    context_written = 0
    compact_written = 0
  }
  /^model_context_window[[:space:]]*=/ {
    print "model_context_window = " context_size
    context_written = 1
    next
  }
  /^model_auto_compact_token_limit[[:space:]]*=/ {
    print "model_auto_compact_token_limit = " compact_limit
    compact_written = 1
    next
  }
  /^model_catalog_json[[:space:]]*=/ {
    print "model_catalog_json = \"" catalog "\""
    catalog_written = 1
    next
  }
  /^\[/ && (!catalog_written || !context_written || !compact_written) {
    if (!context_written) {
      print "model_context_window = " context_size
      context_written = 1
    }
    if (!compact_written) {
      print "model_auto_compact_token_limit = " compact_limit
      compact_written = 1
    }
    if (!catalog_written) {
      print "model_catalog_json = \"" catalog "\""
      catalog_written = 1
    }
    print ""
  }
  { print }
  END {
    if (!context_written) {
      print "model_context_window = " context_size
    }
    if (!compact_written) {
      print "model_auto_compact_token_limit = " compact_limit
    }
    if (!catalog_written) {
      print "model_catalog_json = \"" catalog "\""
    }
  }
' "$profile_file" > "$profile_tmp"

chmod --reference="$profile_file" "$profile_tmp" 2>/dev/null || chmod 600 "$profile_tmp"
mv "$profile_tmp" "$profile_file"
trap - EXIT HUP INT TERM

echo "Installed Codex model metadata at $catalog_file."
echo "Updated $profile_file for a $context_size-token context window."
