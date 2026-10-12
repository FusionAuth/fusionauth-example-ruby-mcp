#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"
require "securerandom"
require "fusionauth/fusionauth_client"

def parse_args
  options = {
    api_key: nil,
    base_url: "http://localhost:9011",
    application_id: nil,
    scope_name: "get_name",
  }

  parser = OptionParser.new do |opts|
    opts.banner = "Usage: ruby create_scope.rb --api-key KEY --application-id APP_ID [--scope-name NAME]"

    opts.on("--api-key KEY") { |v| options[:api_key] = v }
    opts.on("--application-id APP_ID") { |v| options[:application_id] = v }
    opts.on("--scope-name NAME") { |v| options[:scope_name] = v }
    opts.on("--base-url URL") { |v| options[:base_url] = v }
  end

  parser.parse!(ARGV)

  if options[:api_key].nil? || options[:application_id].nil?
    puts parser.banner
    exit 1
  end

  options
end

def main
  opts = parse_args
  client = FusionAuth::FusionAuthClient.new(opts[:api_key], opts[:base_url])

  scope_id = SecureRandom.uuid
  resp = client.create_o_auth_scope(opts[:application_id], scope_id, {
    scope: {
      name: opts[:scope_name],
      description: "MCP tool scope: #{opts[:scope_name]}",
    },
  })

  if resp.was_successful
    puts "Scope created: #{opts[:scope_name]} (#{scope_id})"
  else
    abort "Failed: #{resp.status} #{resp.error_response.inspect}"
  end
end

main
