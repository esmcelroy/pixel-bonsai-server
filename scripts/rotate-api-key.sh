#!/data/data/com.termux/files/usr/bin/sh
set -eu

project_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
config_file=${PIXEL_BONSAI_CONFIG:-"$project_root/config/server.env"}
token_export=${PIXEL_BONSAI_TOKEN_EXPORT:-}

if [ ! -f "$config_file" ]; then
  echo "Missing $config_file. Run ./scripts/configure.sh first." >&2
  exit 1
fi

if command -v openssl >/dev/null 2>&1; then
  api_key=$(openssl rand -hex 32)
elif command -v od >/dev/null 2>&1; then
  api_key=$(od -An -N32 -tx1 /dev/urandom | tr -d ' \n')
else
  echo "Cannot generate an API key: install OpenSSL." >&2
  exit 1
fi

if [ "${#api_key}" -ne 64 ]; then
  echo "Failed to generate a 256-bit API key." >&2
  exit 1
fi

config_tmp=$(mktemp "${TMPDIR:-/tmp}/pixel-bonsai-config.XXXXXX")
trap 'rm -f "$config_tmp"' EXIT HUP INT TERM
awk -v api_key="$api_key" '
  BEGIN { replaced = 0 }
  /^API_KEY=/ {
    print "API_KEY=" api_key
    replaced = 1
    next
  }
  { print }
  END {
    if (!replaced) {
      print "API_KEY=" api_key
    }
  }
' "$config_file" > "$config_tmp"

chmod 600 "$config_tmp"
mv "$config_tmp" "$config_file"
trap - EXIT HUP INT TERM

if [ -n "$token_export" ]; then
  umask 077
  printf '%s\n' "$api_key" > "$token_export"
  echo "Rotated the API key and exported a client copy to $token_export."
else
  echo "Rotated the API key in $config_file."
fi
