# frozen_string_literal: true

require_relative "lib/ai_record_finder/version"

Gem::Specification.new do |spec|
  spec.name = "ai_record_finder"
  spec.version = AIRecordFinder::VERSION
  spec.authors = ["Jijo Bose"]
  spec.email = ["bosejijo@gmail.com"]

  spec.summary = "Natural language to safe ActiveRecord::Relation queries"
  spec.description = "AIRecordFinder converts natural language into validated, schema-aware and tenant-safe ActiveRecord queries via an AI-generated JSON DSL."
  spec.homepage = "https://ai-record-finder.local/docs"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/CHANGELOG.md"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rubocop.yml])
    end
  end

  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", ">= 2.7"
  spec.add_dependency "json", ">= 2.6"

  spec.add_development_dependency "activerecord", ">= 7.1"
  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "sqlite3", ">= 1.6"
end
