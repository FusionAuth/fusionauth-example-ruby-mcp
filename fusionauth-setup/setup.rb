#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"
require "securerandom"
require "fusionauth/fusionauth_client"

def parse_args
  options = {
    api_key: nil,
    tenant_id: nil,
    base_url: "http://localhost:9011",
    client_name: "MCP Server Client",
    mcp_server_url: "http://localhost:8000/mcp",
    port: 3334,
    username: "test@example.com",
    password: "password",
    first_name: "Test",
    last_name: "User",
  }

  parser = OptionParser.new do |opts|
    opts.banner = "Usage: ruby setup.rb --api-key KEY --tenant-id TENANT_ID [options]"

    opts.on("--api-key KEY", "FusionAuth API key") { |v| options[:api_key] = v }
    opts.on("--tenant-id TENANT_ID", "Tenant ID") { |v| options[:tenant_id] = v }
    opts.on("--base-url URL", "FusionAuth base URL (default: http://localhost:9011)") { |v| options[:base_url] = v }
    opts.on("--client-name NAME", "MCP client application name (default: MCP Server Client)") { |v| options[:client_name] = v }
    opts.on("--mcp-server-url URL", "MCP server URL (default: http://localhost:8000/mcp)") { |v| options[:mcp_server_url] = v }
    opts.on("--port PORT", Integer, "OAuth callback port (default: 3334)") { |v| options[:port] = v }
    opts.on("--username EMAIL", "Test user email (default: test@example.com)") { |v| options[:username] = v }
    opts.on("--password PASS", "Test user password (default: password)") { |v| options[:password] = v }
    opts.on("--first-name NAME", "Test user first name (default: Test)") { |v| options[:first_name] = v }
    opts.on("--last-name NAME", "Test user last name (default: User)") { |v| options[:last_name] = v }
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

  # Create application
  app_id = SecureRandom.uuid
  app_request = {
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

  app_resp = client.create_application(app_id, app_request)
  unless app_resp.was_successful
    abort "Failed to create application: #{app_resp.status} #{app_resp.error_response.inspect}"
  end

  puts "Created application: #{app_id}"

  # Create the greet and goodbye scopes required by the MCP server's tools
  %w[greet goodbye].each do |scope_name|
    scope_id = SecureRandom.uuid
    scope_request = {
      scope: {
        name: scope_name,
        description: "Allow calling the #{scope_name} MCP tool",
        required: false,
      },
    }
    scope_resp = client.create_o_auth_scope(app_id, scope_id, scope_request)
    unless scope_resp.was_successful
      abort "Failed to create scope: #{scope_resp.status} #{scope_resp.error_response.inspect}"
    end
    puts "Created scope: #{scope_name}"
  end

  # Create test user
  user_id = SecureRandom.uuid
  user_request = {
    user: {
      firstName: opts[:first_name],
      lastName: opts[:last_name],
      email: opts[:username],
      password: opts[:password],
    },
  }
  user_resp = client.create_user(user_id, user_request)
  unless user_resp.was_successful
    abort "Failed to create user: #{user_resp.status} #{user_resp.error_response.inspect}"
  end
  puts "Created user: #{opts[:username]}"

  # Register user to application
  reg_request = {
    registration: {
      applicationId: app_id,
      roles: [],
    },
  }
  reg_resp = client.register(user_id, reg_request)
  unless reg_resp.was_successful
    abort "Failed to register user: #{reg_resp.status} #{reg_resp.error_response.inspect}"
  end
  puts "Registered user to application"

  # Output MCP client config
  puts "\n=== MCP client configuration (for mcp-remote) ==="
  client_info = { client_id: app_id, scope: "openid profile greet goodbye" }.to_json
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
  puts "\nTest credentials: #{opts[:username]} / #{opts[:password]}"
end

main
