# frozen_string_literal: true

require "rack"
require "mcp"
require_relative "lib/auth"
require_relative "lib/tools"

disable_auth = ENV["DISABLE_AUTH"] == "true"
config = McpOAuth::Config.from_env(require_oidc: !disable_auth)

server = MCP::Server.new(
  name: "greet_goodbye",
  title: "Greet & Goodbye",
  version: "1.0.0",
  tools: [GreetTool, GoodbyeTool],
  server_context: {},
)

transport = MCP::Server::Transports::StreamableHTTPTransport.new(
  server,
  stateless: true,
  enable_json_response: true,
)

app = Rack::Builder.new do
  unless disable_auth
    map config.metadata_path do
      run McpOAuth::ProtectedResourceMetadata.new(config)
    end
  end

  map "/mcp" do
    use McpOAuth::BearerAuth, config: config unless disable_auth
    run transport
  end
end

run app
