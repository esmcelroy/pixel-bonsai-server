#!/data/data/com.termux/files/usr/bin/sh
set -eu

project_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
config_file="$project_root/config/server.env"

if [ -e "$config_file" ]; then
  echo "$config_file already exists; leaving it unchanged."
  exit 0
fi

if command -v openssl >/dev/null 2>&1; then
  api_key=$(openssl rand -hex 32)
elif command -v od >/dev/null 2>&1; then
  # Android/Termux provides /dev/urandom even before the optional OpenSSL
  # package is installed. POSIX od converts 32 random bytes to 64 hex digits.
  api_key=$(od -An -N32 -tx1 /dev/urandom | tr -d ' \n')
else
  echo "Cannot generate an API key: install OpenSSL with 'pkg install openssl'." >&2
  exit 1
fi

if [ "${#api_key}" -ne 64 ]; then
  echo "Failed to generate a 256-bit API key." >&2
  exit 1
fi

sed "s/API_KEY=replace-me/API_KEY=$api_key/" \
  "$project_root/config/server.env.example" > "$config_file"
chmod 600 "$config_file"

echo "Created $config_file with mode 600."
echo "Keep its API key private; it is intentionally ignored by Git."
