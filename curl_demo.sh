#!/usr/bin/env bash
#
# Demonstrates the OAuth 2.1 protection on the MCP server.
#
# Provide two access tokens issued by your IdP:
#   TOKEN_GREET   - carries the "greet" scope
#   TOKEN_GOODBYE - carries the "goodbye" scope
#
# Usage:
#   TOKEN_GREET=... TOKEN_GOODBYE=... ./curl_demo.sh
#
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:9292}"
MCP_URL="$BASE_URL/mcp"

if [[ -z "${TOKEN_GREET:-}" || -z "${TOKEN_GOODBYE:-}" ]]; then
  echo "Set TOKEN_GREET and TOKEN_GOODBYE to access tokens from your IdP." >&2
  exit 1
fi

call_tool() {
  local label="$1" token="$2" tool="$3"

  local args=(
    -s
    -w $'\n%{http_code}'
    -X POST "$MCP_URL"
    -H 'content-type: application/json'
    -H 'accept: application/json, text/event-stream'
  )
  [[ -n "$token" ]] && args+=(-H "authorization: Bearer $token")
  args+=(-d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"$tool\",\"arguments\":{\"name\":\"Ada\"}}}")

  local out code body
  out="$(curl "${args[@]}")"
  code="${out##*$'\n'}"
  body="${out%$'\n'*}"

  printf '%-34s -> HTTP %s\n' "$label" "$code"
  printf '    %s\n' "$body"
}

echo "Protected resource metadata:"
curl -s "$BASE_URL/.well-known/oauth-protected-resource/mcp"
echo
echo

call_tool "no token -> greet"          ""              greet
call_tool "greet token -> greet"       "$TOKEN_GREET"  greet
call_tool "greet token -> goodbye"     "$TOKEN_GREET"  goodbye
call_tool "goodbye token -> goodbye"   "$TOKEN_GOODBYE" goodbye
call_tool "goodbye token -> greet"     "$TOKEN_GOODBYE" greet
call_tool "garbage token -> greet"     "not.a.jwt"     greet
