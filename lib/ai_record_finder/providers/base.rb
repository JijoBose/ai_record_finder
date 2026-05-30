# frozen_string_literal: true

require "faraday"
require "json"

module AIRecordFinder
  module Providers
    # Shared HTTP transport for chat-style LLM providers.
    #
    # Subclasses implement the provider-specific contract:
    #   #endpoint_path, #request_headers, #request_payload, #extract_content
    #
    # Endpoint paths MUST be relative (no leading slash) so they append to the
    # configured base URL's path (e.g. ".../v1") instead of replacing it.
    class Base
      def initialize(configuration:, connection: nil)
        @configuration = configuration
        @connection = connection
        validate_configuration!
      end

      def chat_completion(system_prompt:, user_prompt:)
        response = post_request(system_prompt, user_prompt)
        ensure_success!(response)
        extract_content(parse_body(response))
      rescue Faraday::Error => e
        raise AIResponseError, "AI request failed: #{e.message}"
      end

      private

      attr_reader :configuration

      def post_request(system_prompt, user_prompt)
        connection.post(endpoint_path) do |req|
          request_headers.each { |name, value| req.headers[name] = value }
          req.body = JSON.generate(request_payload(system_prompt, user_prompt))
        end
      end

      def connection
        @connection ||= Faraday.new(url: configuration.api_base_url) do |f|
          f.options.timeout = configuration.request_timeout
          f.options.open_timeout = configuration.request_timeout
          f.adapter Faraday.default_adapter
        end
      end

      def parse_body(response)
        JSON.parse(response.body.to_s)
      rescue JSON::ParserError
        raise AIResponseError, "AI response body is not valid JSON"
      end

      # Faraday does not raise on non-2xx, so check the status explicitly. Error
      # bodies are not guaranteed to be JSON (a gateway may return HTML/plain
      # text), so this must surface a useful detail without depending on a
      # successful parse — hence it runs before parse_body.
      def ensure_success!(response)
        return if response.success?

        raise AIResponseError, "AI request failed: #{error_detail(response)}"
      end

      # Both OpenAI and Anthropic nest the human-readable error under
      # error.message; fall back to the HTTP status for non-JSON error bodies.
      def error_detail(response)
        parsed = JSON.parse(response.body.to_s)
        (parsed.is_a?(Hash) && parsed.dig("error", "message")) || "HTTP #{response.status}"
      rescue JSON::ParserError
        "HTTP #{response.status}"
      end

      def validate_configuration!
        return unless configuration.api_key.to_s.strip.empty?

        raise ConfigurationError, "Missing API key. Set AIRecordFinder.configure { |c| c.api_key = ... }"
      end

      # --- Provider contract (subclasses must override) ---

      def endpoint_path
        raise NotImplementedError, "#{self.class} must implement #endpoint_path"
      end

      def request_headers
        raise NotImplementedError, "#{self.class} must implement #request_headers"
      end

      def request_payload(_system_prompt, _user_prompt)
        raise NotImplementedError, "#{self.class} must implement #request_payload"
      end

      def extract_content(_parsed)
        raise NotImplementedError, "#{self.class} must implement #extract_content"
      end
    end
  end
end
