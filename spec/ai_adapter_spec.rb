# frozen_string_literal: true

require "spec_helper"

RSpec.describe AIRecordFinder::AIAdapter do
  it "strips markdown code fences and parses JSON" do
    client = instance_double("Client")
    allow(client).to receive(:chat_completion).and_return(
      <<~TEXT
        ```json
        {"filters":[],"limit":10}
        ```
      TEXT
    )

    result = described_class.new(client: client).call(system_prompt: "x", user_prompt: "y")
    expect(result).to eq("filters" => [], "limit" => 10)
  end

  it "raises AIResponseError for invalid JSON" do
    client = instance_double("Client")
    allow(client).to receive(:chat_completion).and_return("not-json")

    expect do
      described_class.new(client: client).call(system_prompt: "x", user_prompt: "y")
    end.to raise_error(AIRecordFinder::AIResponseError)
  end
end
