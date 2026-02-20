# Developer Guide (Basic)

This guide explains how to use `ai_record_finder` in a Rails app.

## 1. Install

Add the gem:

```ruby
# Gemfile
gem "ai_record_finder"
```

Install dependencies:

```bash
bundle install
```

## 2. Configure

Create an initializer:

```ruby
# config/initializers/ai_record_finder.rb
AIRecordFinder.configure do |config|
  config.api_key = ENV.fetch("OPENAI_API_KEY")
  config.model_name = "gpt-4o-mini"
  config.max_limit = 100

  # Only models in this list can be queried.
  config.allowed_models = [Invoice, User]

  # Optional: allow specific joins per model.
  config.allowed_associations = {
    "Invoice" => ["user"]
  }
end
```

## 3. Run a Query

Use natural language + model:

```ruby
relation = AIRecordFinder.query(
  prompt: "Unpaid invoices above 50000 from last quarter",
  model: Invoice
)
```

For associated-table constraints, use `association.column` semantics in the request intent, such as: "unpaid invoices where `user.email` contains `@acme.com`". The gem will auto-join associations used by these fields, but they must still be whitelisted in `allowed_associations`.

The return value is always an `ActiveRecord::Relation`, so you can chain it:

```ruby
relation.limit(20).pluck(:id)
```

## 4. What Happens Internally

1. The model is checked against `allowed_models`.
2. The model schema (columns, associations, enums) is introspected.
3. A strict AI prompt is built that allows only JSON DSL.
4. AI output is cleaned and JSON-parsed.
5. DSL is validated (fields, operators, sort, limit, keys).
6. A safe ActiveRecord relation is built and returned.

## 5. DSL Constraints (Important)

The AI can only use these operators:

- `eq`
- `gt`
- `lt`
- `gte`
- `lte`
- `between`
- `in`
- `like`

Safety rules:

- Unknown fields are rejected.
- Unknown operators are rejected.
- Unknown JSON keys are rejected.
- `limit` must be `<= config.max_limit`.
- Joins are blocked unless explicitly allowed.

## 6. Tenant Safety Hook

If your model defines `current_tenant_scope`, it is automatically merged:

```ruby
class Invoice < ApplicationRecord
  def self.current_tenant_scope
    where(account_id: Current.account_id)
  end
end
```

This helps enforce tenant boundaries by default.

## 7. Common Errors

- `AIRecordFinder::UnauthorizedModel`
: model is not in `allowed_models`.
- `AIRecordFinder::InvalidModelError`
: model is not an ActiveRecord model.
- `AIRecordFinder::InvalidDSL`
: AI returned unsupported fields/operators/keys/limit.
- `AIRecordFinder::AIResponseError`
: AI response was invalid or API call failed.

## 8. Basic Controller Example

```ruby
class InvoicesController < ApplicationController
  def search
    relation = AIRecordFinder.query(
      prompt: params[:q],
      model: Invoice
    )

    @invoices = relation.limit(50)
  rescue AIRecordFinder::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end
end
```

## 9. Testing Your Integration

Run library tests:

```bash
bundle exec rspec
```

For app-level tests, mock `AIRecordFinder.query` in controller/service specs and assert:

- It returns a relation.
- Unauthorized models are rejected.
- Tenant constraints remain applied.
