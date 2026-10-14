# frozen_string_literal: true

require "json"
require "jwt"
require "net/http"
require "stringio"
require "uri"

module McpOAuth
  SUPPORTED_ALGORITHMS = %w[RS256 RS384 RS512 ES256 ES384 ES512 PS256 PS384 PS512].freeze

  TOOL_SCOPES = {
    "greet" => "greet",
    "goodbye" => "goodbye",
  }.freeze

  class Config
    attr_reader :issuer, :audience, :resource_url

    def initialize(issuer:, audience:, resource_url:, jwks_uri: nil)
      @issuer = issuer
      @audience = audience
      @resource_url = resource_url
      @jwks_uri = jwks_uri
    end

    def self.from_env(require_oidc: true)
      if require_oidc
        issuer = ENV.fetch("OIDC_ISSUER") { abort "OIDC_ISSUER is required (e.g. https://idp.example.com)" }
        audience = ENV.fetch("OIDC_AUDIENCE") { abort "OIDC_AUDIENCE is required (the token audience for this MCP server)" }
      else
        issuer = ENV["OIDC_ISSUER"]
        audience = ENV["OIDC_AUDIENCE"]
      end

      new(
        issuer: issuer,
        audience: audience,
        resource_url: ENV.fetch("RESOURCE_URL", "http://localhost:9292/mcp"),
        jwks_uri: ENV["OIDC_JWKS_URI"],
      )
    end

    def scopes
      TOOL_SCOPES.values.uniq
    end

    def metadata_path
      path = URI(resource_url).path
      path = "" if path == "/"
      "/.well-known/oauth-protected-resource#{path}"
    end

    def resource_metadata_url
      URI(resource_url).dup.tap { |uri| uri.path = metadata_path; uri.query = nil }.to_s
    end

    def jwks_uri
      @jwks_uri ||= discover_jwks_uri
    end

    private

    def discover_jwks_uri
      document = Net::HTTP.get(URI("#{@issuer}/.well-known/openid-configuration"))
      JSON.parse(document).fetch("jwks_uri")
    end
  end

  class JwksCache
    def initialize(uri, ttl: 300)
      @uri = uri
      @ttl = ttl
    end

    def keys
      return @keys if @keys && (Time.now - @fetched_at) < @ttl

      @keys = JSON.parse(Net::HTTP.get(URI(@uri)))
      @fetched_at = Time.now
      @keys
    end
  end

  class TokenValidator
    def initialize(config)
      @config = config
      @jwks = JwksCache.new(config.jwks_uri)
    end

    def validate(token)
      claims, = JWT.decode(
        token,
        nil,
        true,
        algorithms: SUPPORTED_ALGORITHMS,
        jwks: @jwks.keys,
        iss: @config.issuer,
        verify_iss: true,
        aud: @config.audience,
        verify_aud: true,
        exp_leeway: 30,
      )
      claims
    end

    def scopes(claims)
      raw = claims["scope"] || claims["scp"] || claims["scopes"]
      case raw
      when String then raw.split
      when Array then raw.map(&:to_s)
      else []
      end
    end
  end

  class BearerAuth
    def initialize(app, config:)
      @app = app
      @config = config
      @validator = TokenValidator.new(config)
    end

    def call(env)
      token = bearer_token(env)
      return challenge(401, "invalid_request", "Missing bearer token") unless token

      claims = @validator.validate(token)
      scopes = @validator.scopes(claims)

      missing = required_scopes(env).reject { |scope| scopes.include?(scope) }
      unless missing.empty?
        return challenge(403, "insufficient_scope",
                         "Missing required scope: #{missing.join(', ')}",
                         scope: missing.join(" "))
      end

      env["mcp.claims"] = claims
      env["mcp.scopes"] = scopes
      @app.call(env)
    rescue JWT::DecodeError => e
      challenge(401, "invalid_token", e.message)
    end

    private

    def bearer_token(env)
      env["HTTP_AUTHORIZATION"].to_s[/\ABearer\s+(.+)\z/i, 1]
    end

    def required_scopes(env)
      return [] unless env["REQUEST_METHOD"] == "POST"

      messages = JSON.parse(read_body(env))
      messages = [messages] unless messages.is_a?(Array)
      messages.filter_map do |message|
        next unless message.is_a?(Hash) && message["method"] == "tools/call"

        TOOL_SCOPES[message.dig("params", "name")]
      end.uniq
    rescue JSON::ParserError
      []
    end

    def read_body(env)
      input = env["rack.input"]
      body = input.read
      input.rewind if input.respond_to?(:rewind)
      env["rack.input"] = StringIO.new(body)
      env["CONTENT_LENGTH"] = body.bytesize.to_s
      body
    end

    def challenge(status, error, description, scope: nil)
      params = %(Bearer realm="mcp", resource_metadata="#{@config.resource_metadata_url}", error="#{error}")
      params += %(, scope="#{scope}") if scope
      params += %(, error_description="#{description.gsub('"', "'")}")

      body = JSON.generate(error: error, error_description: description)
      [status, { "content-type" => "application/json", "www-authenticate" => params }, [body]]
    end
  end

  class ProtectedResourceMetadata
    def initialize(config)
      @config = config
    end

    def call(_env)
      body = JSON.generate(
        resource: @config.resource_url,
        authorization_servers: [@config.issuer],
        scopes_supported: @config.scopes,
        bearer_methods_supported: ["header"],
      )
      [200, { "content-type" => "application/json" }, [body]]
    end
  end
end
