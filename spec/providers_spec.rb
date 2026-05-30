# frozen_string_literal: true

require "spec_helper"
require "json"

RSpec.describe AIRecordFinder::Providers do
  # Wires a provider to a Faraday test connection that records the outgoing
  # request into `captured` and replies with a canned response. The connection
  # is built from the configured base URL so the relative endpoint path is
  # resolved exactly as it would be in production.
  def stubbed(klass, configuration, expected_path:, response: nil, raw_body: nil, status: 200)
    captured = {}
    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.post(expected_path) do |env|
      captured[:url] = env.url.to_s
      captured[:headers] = env.request_headers.to_h
      captured[:body] = JSON.parse(env.body)
      [status, { "Content-Type" => "application/json" }, raw_body || JSON.generate(response)]
    end
    connection = Faraday.new(url: configuration.api_base_url) { |f| f.adapter :test, stubs }
    [klass.new(configuration: configuration, connection: connection), captured]
  end

  def config_for(provider)
    AIRecordFinder::Configuration.new.tap do |c|
      c.api_key = "secret-key"
      c.provider = provider
    end
  end

  describe AIRecordFinder::Providers::OpenAI do
    it "posts an OpenAI chat-completions request and extracts the message content" do
      provider, captured = stubbed(
        described_class, config_for(:openai),
        expected_path: "/v1/chat/completions",
        response: { "choices" => [{ "message" => { "content" => '{"filters":[]}' } }] }
      )

      result = provider.chat_completion(system_prompt: "SYS", user_prompt: "USR")

      expect(result).to eq('{"filters":[]}')
      # Guards the latent bug: a leading-slash path drops the "/v1" prefix.
      expect(captured[:url]).to eq("https://api.openai.com/v1/chat/completions")
      expect(captured[:headers]["Authorization"]).to eq("Bearer secret-key")
      expect(captured[:body]).to eq(
        "model" => "gpt-4o-mini",
        "temperature" => 0.0,
        "messages" => [
          { "role" => "system", "content" => "SYS" },
          { "role" => "user", "content" => "USR" }
        ]
      )
    end

    it "raises AIResponseError on a non-2xx response, surfacing the API message" do
      provider, = stubbed(
        described_class, config_for(:openai),
        expected_path: "/v1/chat/completions",
        status: 401,
        response: { "error" => { "message" => "Invalid API key" } }
      )

      expect { provider.chat_completion(system_prompt: "s", user_prompt: "u") }
        .to raise_error(AIRecordFinder::AIResponseError, /Invalid API key/)
    end

    it "raises AIResponseError when the response has no choices" do
      provider, = stubbed(
        described_class, config_for(:openai),
        expected_path: "/v1/chat/completions",
        response: { "unexpected" => true }
      )

      expect { provider.chat_completion(system_prompt: "s", user_prompt: "u") }
        .to raise_error(AIRecordFinder::AIResponseError, /missing choices/)
    end

    it "raises AIResponseError when choices is an empty array" do
      provider, = stubbed(
        described_class, config_for(:openai),
        expected_path: "/v1/chat/completions",
        response: { "choices" => [] }
      )

      expect { provider.chat_completion(system_prompt: "s", user_prompt: "u") }
        .to raise_error(AIRecordFinder::AIResponseError, /missing choices/)
    end

    it "raises AIResponseError when content is null (tool_calls-only reply)" do
      provider, = stubbed(
        described_class, config_for(:openai),
        expected_path: "/v1/chat/completions",
        response: { "choices" => [{ "message" => { "role" => "assistant", "content" => nil, "tool_calls" => [] } }] }
      )

      expect { provider.chat_completion(system_prompt: "s", user_prompt: "u") }
        .to raise_error(AIRecordFinder::AIResponseError, /missing choices/)
    end

    it "raises AIResponseError when the first choice has no message" do
      provider, = stubbed(
        described_class, config_for(:openai),
        expected_path: "/v1/chat/completions",
        response: { "choices" => [{ "finish_reason" => "stop" }] }
      )

      expect { provider.chat_completion(system_prompt: "s", user_prompt: "u") }
        .to raise_error(AIRecordFinder::AIResponseError, /missing choices/)
    end

    it "surfaces the HTTP status when an error response has no message" do
      provider, = stubbed(
        described_class, config_for(:openai),
        expected_path: "/v1/chat/completions",
        status: 429,
        response: { "error" => { "type" => "rate_limit_error" } }
      )

      expect { provider.chat_completion(system_prompt: "s", user_prompt: "u") }
        .to raise_error(AIRecordFinder::AIResponseError, /HTTP 429/)
    end

    it "surfaces the HTTP status when an error body is not JSON" do
      provider, = stubbed(
        described_class, config_for(:openai),
        expected_path: "/v1/chat/completions",
        status: 502,
        raw_body: "<html>Bad Gateway</html>"
      )

      expect { provider.chat_completion(system_prompt: "s", user_prompt: "u") }
        .to raise_error(AIRecordFinder::AIResponseError, /HTTP 502/)
    end

    it "raises AIResponseError when a successful body is not valid JSON" do
      provider, = stubbed(
        described_class, config_for(:openai),
        expected_path: "/v1/chat/completions",
        raw_body: "not json at all"
      )

      expect { provider.chat_completion(system_prompt: "s", user_prompt: "u") }
        .to raise_error(AIRecordFinder::AIResponseError, /not valid JSON/)
    end

    it "wraps Faraday transport errors as AIResponseError" do
      cfg = config_for(:openai)
      stubs = Faraday::Adapter::Test::Stubs.new
      stubs.post("/v1/chat/completions") { raise Faraday::TimeoutError }
      connection = Faraday.new(url: cfg.api_base_url) { |f| f.adapter :test, stubs }
      provider = described_class.new(configuration: cfg, connection: connection)

      expect { provider.chat_completion(system_prompt: "s", user_prompt: "u") }
        .to raise_error(AIRecordFinder::AIResponseError, /AI request failed/)
    end
  end

  describe AIRecordFinder::Providers::Anthropic do
    it "posts a native Messages request and extracts the text block" do
      provider, captured = stubbed(
        described_class, config_for(:anthropic),
        expected_path: "/v1/messages",
        response: { "content" => [{ "type" => "text", "text" => '{"filters":[]}' }] }
      )

      result = provider.chat_completion(system_prompt: "SYS", user_prompt: "USR")

      expect(result).to eq('{"filters":[]}')
      expect(captured[:url]).to eq("https://api.anthropic.com/v1/messages")
      expect(captured[:headers]["x-api-key"]).to eq("secret-key")
      expect(captured[:headers]["anthropic-version"]).to eq("2023-06-01")
      expect(captured[:headers]).not_to have_key("Authorization")
      expect(captured[:body]).to eq(
        "model" => "claude-sonnet-4-6",
        "max_tokens" => 1024,
        "temperature" => 0.0,
        "system" => "SYS",
        "messages" => [{ "role" => "user", "content" => "USR" }]
      )
    end

    it "skips non-text blocks and returns the first text block" do
      provider, = stubbed(
        described_class, config_for(:anthropic),
        expected_path: "/v1/messages",
        response: {
          "content" => [
            { "type" => "thinking", "thinking" => "..." },
            { "type" => "text", "text" => "the answer" }
          ]
        }
      )

      expect(provider.chat_completion(system_prompt: "s", user_prompt: "u")).to eq("the answer")
    end

    it "returns the first text block when several are present" do
      provider, = stubbed(
        described_class, config_for(:anthropic),
        expected_path: "/v1/messages",
        response: {
          "content" => [
            { "type" => "text", "text" => "first" },
            { "type" => "text", "text" => "second" }
          ]
        }
      )

      expect(provider.chat_completion(system_prompt: "s", user_prompt: "u")).to eq("first")
    end

    it "raises AIResponseError when the content array is empty" do
      provider, = stubbed(
        described_class, config_for(:anthropic),
        expected_path: "/v1/messages",
        response: { "content" => [] }
      )

      expect { provider.chat_completion(system_prompt: "s", user_prompt: "u") }
        .to raise_error(AIRecordFinder::AIResponseError, /missing content text block/)
    end

    it "raises AIResponseError when a text block has no text value" do
      provider, = stubbed(
        described_class, config_for(:anthropic),
        expected_path: "/v1/messages",
        response: { "content" => [{ "type" => "text" }] }
      )

      expect { provider.chat_completion(system_prompt: "s", user_prompt: "u") }
        .to raise_error(AIRecordFinder::AIResponseError, /missing content text block/)
    end

    it "raises AIResponseError surfacing the Anthropic error message" do
      provider, = stubbed(
        described_class, config_for(:anthropic),
        expected_path: "/v1/messages",
        status: 400,
        response: { "type" => "error", "error" => { "type" => "invalid_request_error", "message" => "max_tokens: required" } }
      )

      expect { provider.chat_completion(system_prompt: "s", user_prompt: "u") }
        .to raise_error(AIRecordFinder::AIResponseError, /max_tokens: required/)
    end

    it "raises AIResponseError when no text block is present" do
      provider, = stubbed(
        described_class, config_for(:anthropic),
        expected_path: "/v1/messages",
        response: { "content" => [{ "type" => "tool_use", "id" => "x" }] }
      )

      expect { provider.chat_completion(system_prompt: "s", user_prompt: "u") }
        .to raise_error(AIRecordFinder::AIResponseError, /missing content text block/)
    end

    it "respects custom max_tokens and anthropic_version" do
      cfg = config_for(:anthropic)
      cfg.max_tokens = 256
      cfg.anthropic_version = "2024-10-22"
      provider, captured = stubbed(
        described_class, cfg,
        expected_path: "/v1/messages",
        response: { "content" => [{ "type" => "text", "text" => "x" }] }
      )

      provider.chat_completion(system_prompt: "s", user_prompt: "u")

      expect(captured[:body]["max_tokens"]).to eq(256)
      expect(captured[:headers]["anthropic-version"]).to eq("2024-10-22")
    end
  end

  describe ".build" do
    it "returns the OpenAI provider for :openai" do
      expect(described_class.build(configuration: config_for(:openai)))
        .to be_a(AIRecordFinder::Providers::OpenAI)
    end

    it "returns the Anthropic provider for :anthropic" do
      expect(described_class.build(configuration: config_for(:anthropic)))
        .to be_a(AIRecordFinder::Providers::Anthropic)
    end

    it "raises ConfigurationError for an unknown provider" do
      expect { described_class.build(configuration: config_for(:gemini)) }
        .to raise_error(AIRecordFinder::ConfigurationError, /Unknown provider/)
    end

    it "raises ConfigurationError when the API key is missing" do
      cfg = AIRecordFinder::Configuration.new
      cfg.provider = :anthropic

      expect { described_class.build(configuration: cfg) }
        .to raise_error(AIRecordFinder::ConfigurationError, /Missing API key/)
    end
  end
end
