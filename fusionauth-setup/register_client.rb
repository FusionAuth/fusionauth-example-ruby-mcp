#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"
require "securerandom"
require "fusionauth/fusionauth_client"
require "json"

def parse_args
  options = {
    api_key: nil,
    tenant_id: nil,
    base_url: "http://localhost:9011",
    client_name: "MCP Client",
    mcp_server_url: "http://localhost:8000/mcp",
    port: 3334,
    existing_app_id: nil,
  }

  parser = OptionParser.new do |opts|
    opts.banner = "Usage: ruby register_client.rb --api-key KEY --tenant-id TENANT_ID [--existing-app-id ID]"

    opts.on("--api-key KEY") { |v| options[:api_key] = v }
    opts.on("--tenant-id TENANT_ID") { |v| options[:tenant_id] = v }
    opts.on("--base-url URL") { |v| options[:base_url] = v }
    opts.on("--client-name NAME") { |v| options[:client_name] = v }
    opts.on("--mcp-server-url URL") { |v| options[:mcp_server_url] = v }
    opts.on("--port PORT", Integer) { |v| options[:port] = v }
    opts.on("--existing-app-id ID") { |v| options[:existing_app_id] = v }
  end

  parser.parse!(ARGV)

  if options[:api_key].nil? || options[:tenant_id].nil?
    puts parser.banner
    exit 1
  end

  options
end

def main
  opts = parse_args
  client = FusionAuth::FusionAuthClient.new(opts[:api_key], opts[:base_url])
  app_id = opts[:existing_app_id] || SecureRandom.uuid

  req = {
    application: {
      name: opts[:client_name],
      tenantId: opts[:tenant_id],
      oauthConfiguration: {
        authorizedRedirectURLs: [
          "http://localhost:#{opts[:port]}/oauth/callback",
          "http://127.0.0.1:#{opts[:port]}/oauth/callback",
          "http://localhost:#{opts[:port]}/callback",
          "http://127.0.0.1:#{opts[:port]}/callback",
        ],
        authorizedResourceUris: [opts[:mcp_server_url]],
        authorizedURLValidationPolicy: "ExactMatch",
        clientAuthenticationPolicy: "NotRequiredWhenUsingPKCE",
        enabledGrants: ["authorization_code", "refresh_token"],
        generateRefreshTokens: true,
        proofKeyForCodeExchangePolicy: "Required",
        requireClientAuthentication: false,
        relationship: "ThirdParty",
        scopeHandlingPolicy: "Strict",
      },
    },
  }

  resp = client.create_application(app_id, req)
  if resp.was_successful
    puts "App: #{app_id}"
    client_info = { client_id: app_id, scope: "openid profile get_name" }.to_json
    puts JSON.pretty_generate(
      "mcpServers" => {
        "name-server" => {
          "command" => "npx",
          "args" => [
            "mcp-remote",
            opts[:mcp_server_url],
            opts[:port].to_s,
            "--allow-http",
            "--static-oauth-client-info",
            client_info,
          ],
        },
      },
    )
  else
    abort "Failed: #{resp.status} #{resp.error_response.inspect}"
  end
end

main
