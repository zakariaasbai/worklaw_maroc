#!/usr/bin/env bash
# Shared helpers for supabase/tests/*.sh integration tests. Not meant to be
# run directly — sourced by the individual test scripts.

require_env() {
  : "${SUPABASE_URL:?Set SUPABASE_URL (see 'npx supabase status' or your project settings)}"
  : "${SUPABASE_ANON_KEY:?Set SUPABASE_ANON_KEY}"
  : "${SUPABASE_DB_URL:?Set SUPABASE_DB_URL}"
}

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; exit 1; }

# json_field '<json>' fieldName -> value (string/uuid fields only)
json_field() {
  grep -o "\"$2\":\"[^\"]*\"" <<< "$1" | head -1 | cut -d'"' -f4
}

psql_scalar() {
  psql "$SUPABASE_DB_URL" -t -A -c "$1"
}

signup() {
  local email="$1" password="$2" full_name="$3" org_name="$4"
  curl -s -X POST "$SUPABASE_URL/auth/v1/signup" \
    -H "apikey: $SUPABASE_ANON_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$email\",\"password\":\"$password\",\"data\":{\"full_name\":\"$full_name\",\"organization_name\":\"$org_name\"}}"
}

signin() {
  local email="$1" password="$2"
  curl -s -X POST "$SUPABASE_URL/auth/v1/token?grant_type=password" \
    -H "apikey: $SUPABASE_ANON_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$email\",\"password\":\"$password\"}"
}

# rest METHOD path token [body] -> prints response body, then a line with
# just the HTTP status code. Callers split with `sed '$d'` (body) / `tail -n1`
# (status).
rest() {
  local method="$1" path="$2" token="$3" body="${4:-}"
  if [ -n "$body" ]; then
    curl -s -w '\n%{http_code}' -X "$method" "$SUPABASE_URL/rest/v1/$path" \
      -H "apikey: $SUPABASE_ANON_KEY" \
      -H "Authorization: Bearer $token" \
      -H "Content-Type: application/json" \
      -H "Prefer: return=representation" \
      -d "$body"
  else
    curl -s -w '\n%{http_code}' -X "$method" "$SUPABASE_URL/rest/v1/$path" \
      -H "apikey: $SUPABASE_ANON_KEY" \
      -H "Authorization: Bearer $token"
  fi
}

rest_body() { sed '$d' <<< "$1"; }
rest_status() { tail -n1 <<< "$1"; }
