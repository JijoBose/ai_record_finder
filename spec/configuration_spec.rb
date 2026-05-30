# frozen_string_literal: true

require "spec_helper"

RSpec.describe AIRecordFinder::Configuration do
  subject(:config) { described_class.new }

  it "defaults to the OpenAI provider with its model and base URL" do
    expect(config.provider).to eq(:openai)
    expect(config.model_name).to eq("gpt-4o-mini")
    expect(config.api_base_url).to eq("https://api.openai.com/v1")
  end

  it "resolves Anthropic defaults when the provider is :anthropic" do
    config.provider = :anthropic

    expect(config.model_name).to eq("claude-sonnet-4-6")
    expect(config.api_base_url).to eq("https://api.anthropic.com/v1")
  end

  it "normalizes provider strings and casing to a symbol" do
    config.provider = "Anthropic"

    expect(config.provider).to eq(:anthropic)
  end

  it "prefers explicitly assigned model_name and api_base_url over provider defaults" do
    config.provider = :anthropic
    config.model_name = "claude-opus-4-8"
    config.api_base_url = "https://gateway.internal/v1"

    expect(config.model_name).to eq("claude-opus-4-8")
    expect(config.api_base_url).to eq("https://gateway.internal/v1")
  end

  it "falls back to OpenAI defaults for an unrecognized provider" do
    config.provider = :unknown

    expect(config.model_name).to eq("gpt-4o-mini")
    expect(config.api_base_url).to eq("https://api.openai.com/v1")
  end

  it "exposes Anthropic-specific defaults" do
    expect(config.max_tokens).to eq(1024)
    expect(config.anthropic_version).to eq("2023-06-01")
  end
end
