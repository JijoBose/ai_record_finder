# frozen_string_literal: true

require "rails/railtie"

module AIRecordFinder
  # Rails integration hook.
  class Railtie < Rails::Railtie
    initializer "ai_record_finder.configure" do
      AIRecordFinder.configuration
    end
  end
end
