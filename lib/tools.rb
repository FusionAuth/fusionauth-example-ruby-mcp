# frozen_string_literal: true

require "mcp"

class GreetTool < MCP::Tool
  tool_name "greet"
  title "Greet"
  description "Greet a person by name. Requires the 'greet' OAuth scope."
  input_schema(
    properties: { name: { type: "string", description: "Person to greet" } },
    required: ["name"],
  )

  def self.call(name:, server_context:)
    MCP::Tool::Response.new([{ type: "text", text: "Hello, #{name}!" }])
  end
end

class GoodbyeTool < MCP::Tool
  tool_name "goodbye"
  title "Goodbye"
  description "Say goodbye to a person by name. Requires the 'goodbye' OAuth scope."
  input_schema(
    properties: { name: { type: "string", description: "Person to say goodbye to" } },
    required: ["name"],
  )

  def self.call(name:, server_context:)
    MCP::Tool::Response.new([{ type: "text", text: "Goodbye, #{name}. See you next time!" }])
  end
end
