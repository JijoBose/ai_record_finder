# AIRecordFinder

`ai_record_finder` converts natural language prompts into safe `ActiveRecord::Relation` objects.

It is designed for B2B Rails applications that need strict query safety, tenant boundaries, and model-level authorization.

Basic developer documentation: `docs/DEVELOPER_GUIDE.md`

## Installation

Add to your Gemfile:

```ruby
gem "ai_record_finder"
```

Then run:

```bash
bundle install
```

## Configuration

Add an initializer at `config/initializers/ai_record_finder.rb`:

```ruby
AIRecordFinder.configure do |config|
  config.api_key = ENV.fetch("OPENAI_API_KEY")
  config.model_name = "gpt-4o-mini"
  config.max_limit = 100
  config.allowed_models = [Invoice, User]

  # Optional: allow controlled joins by model.
  config.allowed_associations = {
    "Invoice" => ["user"]
  }
end
```

## Usage

```ruby
relation = AIRecordFinder.query(
  prompt: "Unpaid invoices above 50000 from last quarter",
  model: Invoice
)

# Always ActiveRecord::Relation
relation.limit(10).pluck(:id)
```

For associated-table constraints, reference fields as `association.column` in natural language intent (for example: "invoices where `user.email` contains `@acme.com`"). The gem will auto-join needed associations, but they must still be whitelisted in `allowed_associations`.

## Security Model

`ai_record_finder` is fail-closed and built to avoid LLM-to-SQL injection:

- AI is forced to return JSON DSL only (no SQL allowed).
- AI output is sanitized (markdown/code fences stripped) and JSON-parsed safely.
- Unknown keys/operators/fields are rejected.
- Fields are validated against model schema introspection.
- `limit` is strictly validated and hard-capped by configuration.
- Models must be explicitly whitelisted in `allowed_models`.
- Optional joins are blocked unless explicitly whitelisted in `allowed_associations`.
- If model defines `current_tenant_scope`, it is always merged.
- No `eval`, no destructive operations, no raw SQL execution from AI output.

## Architecture Overview

Core components:

- `AIRecordFinder::Configuration`: runtime safety and API settings.
- `AIRecordFinder::SchemaIntrospector`: model table/column/association/enum summary.
- `AIRecordFinder::PromptBuilder`: strict system prompt with schema and DSL contract.
- `AIRecordFinder::Client`: OpenAI-compatible HTTP transport (Faraday).
- `AIRecordFinder::AIAdapter`: AI response extraction and JSON parsing.
- `AIRecordFinder::DSLParser`: validates DSL structure and values.
- `AIRecordFinder::SafetyGuard`: model authorization, limit policies, join policies, tenant scope.
- `AIRecordFinder::QueryBuilder`: converts validated DSL into `ActiveRecord::Relation`.
- `AIRecordFinder::Railtie`: auto-load support in Rails.

## Error Types

- `AIRecordFinder::InvalidModelError`
- `AIRecordFinder::InvalidDSL`
- `AIRecordFinder::AIResponseError`
- `AIRecordFinder::UnauthorizedModel`

## Testing

Run:

```bash
bundle exec rspec
```

Included tests cover:

- Valid query generation
- Invalid field rejection
- Limit overflow
- Unknown operator
- Unauthorized model
- JSON injection attempt

## Pro Roadmap

Potential Pro features:

- Query explain/preview before execution
- Auditable prompt and DSL logs with redaction controls
- Policy packs (SOC2/HIPAA presets)
- Per-tenant usage quotas and rate-limits
- Multi-model query planning with approval workflows
