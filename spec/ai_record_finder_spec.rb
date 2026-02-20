# frozen_string_literal: true

require "spec_helper"

RSpec.describe AIRecordFinder do
  let(:adapter) { instance_double("AIAdapter") }

  before do
    user_1 = User.create!(name: "Alex", email: "alex@example.com", account_id: 10)
    user_2 = User.create!(name: "Sam", email: "sam@example.com", account_id: 10)
    user_3 = User.create!(name: "Taylor", email: "taylor@example.com", account_id: 99)

    Invoice.create!(user_id: user_1.id, account_id: 10, amount_cents: 80_000, status: "unpaid", issued_at: Time.now)
    Invoice.create!(user_id: user_2.id, account_id: 10, amount_cents: 10_000, status: "paid", issued_at: Time.now)
    Invoice.create!(user_id: user_3.id, account_id: 99, amount_cents: 90_000, status: "unpaid", issued_at: Time.now)
  end

  it "returns an ActiveRecord::Relation for a valid query" do
    allow(adapter).to receive(:call).and_return(
      {
        "filters" => [
          { "field" => "status", "operator" => "eq", "value" => "unpaid" },
          { "field" => "amount_cents", "operator" => "gt", "value" => 50_000 }
        ],
        "limit" => 50,
        "sort" => { "field" => "created_at", "direction" => "desc" }
      }
    )

    relation = described_class.query(
      prompt: "Unpaid invoices above 50000",
      model: Invoice,
      ai_adapter: adapter
    )

    expect(relation).to be_a(ActiveRecord::Relation)
    expect(relation.count).to eq(1)
    expect(relation.first.account_id).to eq(10)
  end

  it "raises InvalidDSL for invalid field" do
    allow(adapter).to receive(:call).and_return(
      {
        "filters" => [
          { "field" => "drop_table", "operator" => "eq", "value" => "x" }
        ],
        "limit" => 10
      }
    )

    expect do
      described_class.query(prompt: "bad", model: Invoice, ai_adapter: adapter)
    end.to raise_error(AIRecordFinder::InvalidDSL, /Unknown field/)
  end

  it "raises InvalidDSL when limit exceeds configured max" do
    allow(adapter).to receive(:call).and_return(
      {
        "filters" => [],
        "limit" => 1_000
      }
    )

    expect do
      described_class.query(prompt: "all", model: Invoice, ai_adapter: adapter)
    end.to raise_error(AIRecordFinder::InvalidDSL, /limit must be between 1 and 100/)
  end

  it "raises InvalidDSL for unknown operator" do
    allow(adapter).to receive(:call).and_return(
      {
        "filters" => [
          { "field" => "amount_cents", "operator" => "delete", "value" => 1 }
        ],
        "limit" => 10
      }
    )

    expect do
      described_class.query(prompt: "bad", model: Invoice, ai_adapter: adapter)
    end.to raise_error(AIRecordFinder::InvalidDSL, /Unknown operator/)
  end

  it "raises UnauthorizedModel for non-whitelisted models" do
    class AuditLog < ActiveRecord::Base
      self.table_name = "users"
    end

    allow(adapter).to receive(:call).and_return({ "filters" => [], "limit" => 5 })

    expect do
      described_class.query(prompt: "anything", model: AuditLog, ai_adapter: adapter)
    end.to raise_error(AIRecordFinder::UnauthorizedModel)
  end

  it "raises InvalidDSL for JSON injection attempt with unknown key" do
    allow(adapter).to receive(:call).and_return(
      {
        "filters" => [
          { "field" => "status", "operator" => "eq", "value" => "unpaid" }
        ],
        "limit" => 10,
        "sql" => "SELECT * FROM invoices; DROP TABLE invoices;"
      }
    )

    expect do
      described_class.query(prompt: "inject", model: Invoice, ai_adapter: adapter)
    end.to raise_error(AIRecordFinder::InvalidDSL, /Unknown DSL keys/)
  end

  it "supports filtering by associated model fields" do
    allow(adapter).to receive(:call).and_return(
      {
        "filters" => [
          { "field" => "user.email", "operator" => "like", "value" => "alex@" },
          { "field" => "status", "operator" => "eq", "value" => "unpaid" }
        ],
        "limit" => 10
      }
    )

    relation = described_class.query(
      prompt: "Unpaid invoices for users with email containing alex@",
      model: Invoice,
      ai_adapter: adapter
    )

    expect(relation.count).to eq(1)
    expect(relation.first.user.email).to eq("alex@example.com")
  end

  it "rejects associated-field filter when join is not allowed by policy" do
    AIRecordFinder.configure do |c|
      c.allowed_associations = {}
    end

    allow(adapter).to receive(:call).and_return(
      {
        "filters" => [
          { "field" => "user.email", "operator" => "eq", "value" => "alex@example.com" }
        ],
        "limit" => 10
      }
    )

    expect do
      described_class.query(prompt: "Invoices for alex@example.com", model: Invoice, ai_adapter: adapter)
    end.to raise_error(AIRecordFinder::InvalidDSL, /Join not allowed by policy: user/)
  end
end
