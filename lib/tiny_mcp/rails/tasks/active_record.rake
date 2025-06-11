# frozen_string_literal: true

require 'rails/generators'
require 'tiny_mcp/rails/generators/active_record_generator'

namespace :tiny_mcp do
  namespace :activerecord do
    desc "Expose a model to TinyMCP for read-only operations"
    task :expose, [:models] => :environment do |t, args|
      models = args[:models]&.split(',') || []
      generator_args = ['tiny_mcp:active_record'] + models
      ::Rails::Generators.invoke 'tiny_mcp:active_record', models
      puts "Done exposing models to TinyMCP"
    end

    desc "Expose all models to TinyMCP for read-only operations"
    task expose_all: :environment do
      ::Rails::Generators.invoke 'tiny_mcp:active_record', []
      puts "Done exposing all models to TinyMCP"
    end

    desc "List all models exposed to TinyMCP"
    task list: :environment do
      ::Rails.application.eager_load!
      exposed_models = TinyMCP::Rails::ActiveRecord.exposed_models
      
      if exposed_models.any?
        puts "Models exposed to TinyMCP:"
        exposed_models.each do |model|
          puts "- #{model.name}"
          puts "  Options: #{model.tiny_mcp_exposure[:options].inspect}"
        end
      else
        puts "No models are currently exposed to TinyMCP."
        puts "To expose models, run: rake tiny_mcp:activerecord:expose[model1,model2]"
        puts "To expose all models, run: rake tiny_mcp:activerecord:expose_all"
      end
    end
  end
end

