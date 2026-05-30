# frozen_string_literal: true

require "spec_helper"
require "json"

RSpec.describe AIRecordFinder::Client do
  def stub_connection(base_url, expected_path, response)
    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.post(expected_path) do |_env|
      [200, { "Content-Type" => "application/json" }, JSON.generate(response)]
    end
    Faraday.new(url: base_url) { |f| f.adapter :test, stubs }
  end

  it "delegates to the OpenAI provider by default" do
    cfg = AIRecordFinder::Configuration.new.tap { |c| c.api_key = "k" }
    conn = stub_connection(
      cfg.api_base_url, "/v1/chat/completions",
      { "choices" => [{ "message" => { "content" => "openai-out" } }] }
    )

    client = described_class.new(configuration: cfg, connection: conn)

    expect(client.chat_completion(system_prompt: "s", user_prompt: "u")).to eq("openai-out")
  end

  it "delegates to the Anthropic provider when configured" do
    cfg = AIRecordFinder::Configuration.new.tap do |c|
      c.api_key = "k"
      c.provider = :anthropic
    end
    conn = stub_connection(
      cfg.api_base_url, "/v1/messages",
      { "content" => [{ "type" => "text", "text" => "anthropic-out" }] }
    )

    client = described_class.new(configuration: cfg, connection: conn)

    expect(client.chat_completion(system_prompt: "s", user_prompt: "u")).to eq("anthropic-out")
  end

  it "raises ConfigurationError when the API key is missing" do
    cfg = AIRecordFinder::Configuration.new

    expect { described_class.new(configuration: cfg) }
      .to raise_error(AIRecordFinder::ConfigurationError, /Missing API key/)
  end
end
