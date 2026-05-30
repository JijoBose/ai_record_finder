## [Unreleased]

## [0.2.0] - 2026-05-30

### Added
- Multi-provider support. `config.provider` selects the AI backend (`:openai`
  default, or `:anthropic`). The Anthropic adapter speaks the native Messages
  API (`/v1/messages`, `x-api-key` + `anthropic-version` headers, top-level
  `system` prompt, `content`-block responses) rather than the OpenAI-compat
  shim. New config: `provider`, `max_tokens`, `anthropic_version`.
- `model_name` and `api_base_url` now fall back to per-provider defaults when
  not explicitly set.

### Changed (potentially breaking)
- A missing API key now raises `AIRecordFinder::ConfigurationError` instead of
  `AIRecordFinder::AIResponseError`. Both inherit from `AIRecordFinder::Error`,
  so code rescuing the base `Error` is unaffected; code rescuing
  `AIResponseError` specifically for this case must switch to
  `ConfigurationError` (or the base `Error`).

### Fixed
- Endpoint paths are now resolved relative to the configured base URL, so a
  base URL containing a path segment (e.g. `.../v1`) is preserved instead of
  being dropped by a leading-slash request path.

## [0.1.0] - 2026-02-19

- Initial release
