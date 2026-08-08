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

awk -v catalog="$catalog_file" '
  BEGIN { written = 0 }
  /^model_catalog_json[[:space:]]*=/ {
    print "model_catalog_json = \"" catalog "\""
    written = 1
    next
  }
  /^\[/ && !written {
    print "model_catalog_json = \"" catalog "\""
    print ""
    written = 1
  }
  { print }
  END {
    if (!written) {
      print "model_catalog_json = \"" catalog "\""
    }
  }
' "$profile_file" > "$profile_tmp"

chmod --reference="$profile_file" "$profile_tmp" 2>/dev/null || chmod 600 "$profile_tmp"
mv "$profile_tmp" "$profile_file"
trap - EXIT HUP INT TERM

echo "Installed Codex model metadata at $catalog_file."
echo "Updated $profile_file for a $context_size-token context window."
