#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"
require "securerandom"
require "fusionauth/fusionauth_client"

def parse_args
  options = {
    api_key: nil,
    base_url: "http://localhost:9011",
    username: "test@example.com",
    password: "password",
    first_name: "Test",
    last_name: "User",
    application_id: nil,
  }

  parser = OptionParser.new do |opts|
    opts.banner = "Usage: ruby create_test_user.rb --api-key KEY [--application-id APP_ID]"

    opts.on("--api-key KEY") { |v| options[:api_key] = v }
    opts.on("--base-url URL") { |v| options[:base_url] = v }
    opts.on("--username EMAIL") { |v| options[:username] = v }
    opts.on("--password PASS") { |v| options[:password] = v }
    opts.on("--first-name NAME") { |v| options[:first_name] = v }
    opts.on("--last-name NAME") { |v| options[:last_name] = v }
    opts.on("--application-id APP_ID") { |v| options[:application_id] = v }
  end

  parser.parse!(ARGV)

  if options[:api_key].nil?
    puts parser.banner
    exit 1
  end

  options
end

def main
  opts = parse_args
  client = FusionAuth::FusionAuthClient.new(opts[:api_key], opts[:base_url])

  user_id = SecureRandom.uuid
  user_resp = client.create_user(user_id, {
    user: {
      firstName: opts[:first_name],
      lastName: opts[:last_name],
      email: opts[:username],
      password: opts[:password],
    },
  })

  unless user_resp.was_successful
    abort "Failed to create user: #{user_resp.status} #{user_resp.error_response.inspect}"
  end
  puts "User created: #{opts[:username]} (#{user_id})"

  if opts[:application_id]
    reg_resp = client.register(user_id, {
      registration: { applicationId: opts[:application_id] },
    })
    unless reg_resp.was_successful
      abort "Failed to register: #{reg_resp.status} #{reg_resp.error_response.inspect}"
    end
    puts "Registered to #{opts[:application_id]}"
  end
end

main
