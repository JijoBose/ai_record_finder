# AIRecordFinder

`ai_record_finder` converts natural language prompts into safe `ActiveRecord::Relation` objects.

It is designed for B2B Rails applications that need strict query safety, tenant boundaries, and model-level authorization.

Documentation homepage: `docs/HOME.md`

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

## Providers

`ai_record_finder` ships with native adapters for two providers. Select one
with `config.provider` (default: `:openai`).

### OpenAI (default)

```ruby
AIRecordFinder.configure do |config|
  config.provider = :openai
  config.api_key  = ENV.fetch("OPENAI_API_KEY")
  # config.model_name defaults to "gpt-4o-mini"
end
```

This also covers any OpenAI-compatible endpoint (Azure OpenAI, OpenRouter,
LiteLLM, Ollama, vLLM, ...) — point `api_base_url` at the gateway:

```ruby
config.api_base_url = "https://openrouter.ai/api/v1"
```

### Anthropic (native Messages API)

The Anthropic adapter talks to the native `/v1/messages` API (`x-api-key`
auth, `anthropic-version` header, top-level `system` prompt, `content`-block
responses) — not the OpenAI-compatibility shim.

```ruby
AIRecordFinder.configure do |config|
  config.provider = :anthropic
  config.api_key  = ENV.fetch("ANTHROPIC_API_KEY")
  config.model_name = "claude-sonnet-4-6" # default; override for your account access

  # Anthropic-specific knobs:
  config.max_tokens        = 1024         # required by the Messages API; default 1024
  config.anthropic_version = "2023-06-01" # default
end
```

When `provider` is set, `model_name` and `api_base_url` resolve to that
provider's defaults unless you assign them explicitly.

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

- `AIRecordFinder::Configuration`: runtime safety, provider, and API settings.
- `AIRecordFinder::SchemaIntrospector`: model table/column/association/enum summary.
- `AIRecordFinder::PromptBuilder`: strict system prompt with schema and DSL contract.
- `AIRecordFinder::Providers`: provider registry and per-vendor transports
  (`Providers::OpenAI`, `Providers::Anthropic`) built on a shared
  `Providers::Base` (Faraday).
- `AIRecordFinder::Client`: transport facade that selects and delegates to the
  configured provider.
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
- `AIRecordFinder::ConfigurationError` (missing API key, unknown provider)

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
