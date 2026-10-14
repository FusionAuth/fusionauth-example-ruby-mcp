# FusionAuth setup scripts

Ruby scripts using the [FusionAuth Ruby client](https://github.com/FusionAuth/fusionauth-ruby-client) to set up a FusionAuth instance for the MCP OAuth example in this repo.

All scripts require an API key, tenant ID, and instance URL. The instance URL may have multiple tenants and should be licensed appropriately (Essentials or Enterprise is required for custom OAuth scopes).

## Scripts

- `setup.rb`: creates an OAuth application (PKCE, refresh token, strict scope handling, authorized resource URIs set to the MCP server), adds the `greet` and `goodbye` scopes required by the MCP server's tools, creates a test user (`test@example.com`/`password`), registers the user to the application, and prints MCP client config for `mcp-remote`.
- `register_client.rb`: creates or reuses an OAuth application (via `--existing-app-id`) and prints MCP client config.
- `create_scope.rb`: adds a custom OAuth scope to an existing application (defaults to `greet`; run again with `--scope-name goodbye` to add the other).
- `create_test_user.rb`: creates a test user and optionally registers it to an application.

## Usage

Run from this directory (or with `bundle exec`):

```
bundle exec ruby setup.rb \
  --api-key <API_KEY> \
  --tenant-id <TENANT_ID> \
  --base-url https://your-fusionauth.example.com \
  --mcp-server-url http://localhost:8000/mcp \
  --port 3334
```

Other scripts take similar flags; see `--help` or the banner for each.

## Notes

- `setup.rb` matches the example flow: it sets `authorizedResourceUris` to the MCP server URL, enables `authorization_code` and `refresh_token`, requires PKCE, sets `scopeHandlingPolicy` to `Strict`, and uses `NotRequiredWhenUsingPKCE` for client auth (suitable for public MCP clients).
- The Ruby client methods used: `create_application`, `create_o_auth_scope`, `create_user`, `register`. All return a response with `was_successful`.
- If you already have an application, use `register_client.rb` with `--existing-app-id` and `create_scope.rb` to add scopes.