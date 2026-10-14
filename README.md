# OAuth 2.1 protected MCP server

A demonstration MCP server with two tools: `greet` and `goodbye`. Each tool requires its own OAuth scope, so a client can call one without holding the other. The server validates JWT access tokens against an external IdP's signing keys (JWKS) and follows the OAuth 2.1 bearer profile for MCP.

## Requirements

Ruby 3.3 or newer, with Bundler.

## Setup

Run `bundle install` from this directory.

## Configuration

The server reads its settings from environment variables.

| Variable | Required | Default | Description |
| --- | --- | --- | --- |
| `OIDC_ISSUER` | Yes | | Token issuer. The server verifies the `iss` claim against it and discovers `jwks_uri` from it. |
| `OIDC_AUDIENCE` | Yes | | The only audience the server accepts. The server verifies the `aud` claim against it. |
| `OIDC_JWKS_URI` | No | Discovered | Where to fetch the IdP's JSON Web Key Set. Defaults to the `jwks_uri` in the issuer's OpenID configuration. |
| `RESOURCE_URL` | No | `http://localhost:9292/mcp` | Public URL of the MCP endpoint, used in the protected-resource metadata. |
| `DISABLE_AUTH` | No | `false` | Set to `true` to run the server with no auth middleware and no protected-resource metadata endpoint, for comparison against an unprotected MCP server. `OIDC_ISSUER`/`OIDC_AUDIENCE` are not required in this mode. |

See `.env.example` for a template.

Token validation checks the JWT signature (RS256, RS384, RS512, ES256, ES384, ES512, PS256, PS384, PS512), the `iss` claim, the `aud` claim, and `exp` with 30 seconds of leeway. The access token's scopes are read from the `scope`, `scp`, or `scopes` claim. JWKS are cached for five minutes.

Scope-to-tool mapping:

| Tool | Required scope |
| --- | --- |
| `greet` | `greet` |
| `goodbye` | `goodbye` |

## Run

```
bundle exec puma config.ru
```

The server listens on port 9292. The MCP endpoint is `/mcp`; the protected-resource metadata (RFC 9728) is at `/.well-known/oauth-protected-resource/mcp`. A request without a token gets HTTP 401. A request whose token lacks the required scope gets HTTP 403 with an `insufficient_scope` challenge that names the missing scope.

The transport runs stateless with JSON responses, which keeps the examples in this file simple. Both settings live in `config.ru` and can be changed.

## Test

Point the server at an IdP that issues JWT access tokens, then supply two tokens and run the script:

```
TOKEN_GREET=<token carrying the greet scope> \
TOKEN_GOODBYE=<token carrying the goodbye scope> \
./curl_demo.sh
```

The script calls `greet` and `goodbye` with no token, a garbage token, and each scope token, and prints the HTTP status and response body for every case.

### Comparing against an unauthenticated server

To see what the same server returns with no auth protection at all, run it with `DISABLE_AUTH=true` (no `OIDC_ISSUER`/`OIDC_AUDIENCE` needed):

```
DISABLE_AUTH=true bundle exec puma config.ru
```

Then call it with no token and no challenge is returned, just the tool result:

```
curl -s -X POST http://localhost:9292/mcp \
  -H 'content-type: application/json' \
  -H 'accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"greet","arguments":{"name":"Ada"}}}'
```

## Project layout

| File | Purpose |
| --- | --- |
| `config.ru` | Rack app. Mounts the auth middleware, the transport, and the protected-resource metadata endpoint. |
| `lib/auth.rb` | Config, JWKS cache, JWT validator, bearer-auth middleware, protected-resource metadata app. |
| `lib/tools.rb` | `greet` and `goodbye` tool definitions. |
| `curl_demo.sh` | End-to-end demonstration against a running server. |