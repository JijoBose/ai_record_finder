# frozen_string_literal: true

require "bundler/setup"
require "active_record"
require "sqlite3"
require "rspec"
require_relative "../lib/ai_record_finder"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

ActiveRecord::Schema.define do
  create_table :users, force: true do |t|
    t.string :name
    t.string :email
    t.integer :account_id
    t.timestamps
  end

  create_table :invoices, force: true do |t|
    t.integer :user_id
    t.integer :account_id
    t.integer :amount_cents
    t.string :status
    t.datetime :issued_at
    t.timestamps
  end
end

class User < ActiveRecord::Base
  has_many :invoices
end

class Invoice < ActiveRecord::Base
  belongs_to :user

  enum :status, { unpaid: "unpaid", paid: "paid", voided: "voided" }

  def self.current_account_id
    10
  end

  def self.current_tenant_scope
    where(account_id: current_account_id)
  end
end

RSpec.configure do |config|
  config.before do
    User.delete_all
    Invoice.delete_all
    AIRecordFinder.reset_configuration!

    AIRecordFinder.configure do |c|
      c.api_key = "test-api-key"
      c.model_name = "gpt-4o-mini"
      c.max_limit = 100
      c.allowed_models = [Invoice, User]
      c.allowed_associations = {
        "Invoice" => ["user"]
      }
    end
  end
end
