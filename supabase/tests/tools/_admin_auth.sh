#!/usr/bin/env bash
# Shared service_role/secret-key handling for tools/provision_test_users.sh
# and tools/cleanup_test_users.sh. Not meant to be run directly.
#
# Supabase has two key formats in play:
#   - new: sb_secret_... — not a JWT. Only the `apikey` header is
#     needed/understood; it carries the admin privilege directly.
#   - legacy: a JWT (starts with "eyJ", the old "service_role" key).
#     GoTrue's admin routes additionally check the Authorization
#     bearer token's `role` claim for this format, so both headers
#     are required.
# The publishable/anon key (sb_publishable_... or a JWT for the `anon`
# role) must never be used here — it has no admin rights, and sending
# it produces a 401 "Invalid API key".

validate_admin_key_format() {
  local key="$1"
  if [[ "$key" != sb_secret_* ]] && [[ "$key" != eyJ* ]]; then
    echo "Error: this doesn't look like a service_role/secret key." >&2
    echo "It must start with 'sb_secret_' (current key format) or 'eyJ' (legacy JWT)." >&2
    echo "Do NOT use the sb_publishable_ (or anon) key here — it has no admin rights." >&2
    return 1
  fi
  return 0
}

# write_admin_curl_config <key> <config_file_path>
# Writes the apikey header, and Authorization: Bearer only for the
# legacy JWT format (the new sb_secret_ key doesn't use/need it).
write_admin_curl_config() {
  local key="$1" config_file="$2"
  {
    printf 'header = "apikey: %s"\n' "$key"
    if [[ "$key" == eyJ* ]]; then
      printf 'header = "Authorization: Bearer %s"\n' "$key"
    fi
  } > "$config_file"
}

# verify_admin_key <supabase_url> <config_file_path>
# One read-only call to confirm the key actually works, before
# attempting any create/delete — a bad key should fail once with a
# clear message, not N times with a confusing one.
verify_admin_key() {
  local supabase_url="$1" config_file="$2" response status
  response=$(curl -s -K "$config_file" -w '\n%{http_code}' \
    "${supabase_url}/auth/v1/admin/users?per_page=1")
  status=$(tail -n1 <<< "$response")
  if [ "$status" != "200" ]; then
    echo "Error: the admin key check failed (HTTP $status)." >&2
    echo "Response: $(sed '$d' <<< "$response")" >&2
    return 1
  fi
  return 0
}
