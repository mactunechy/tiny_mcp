# frozen_string_literal: true

module TinyMCP
  module Generators
    # Generator for exposing ActiveRecord models to TinyMCP
    class ActiveRecordGenerator < Rails::Generators::Base
      desc "Expose ActiveRecord models to TinyMCP for read-only operations"
      
      argument :models, type: :array, default: [], desc: "Models to expose (leave empty to expose all)"
      
      class_option :only, type: :array, default: [], desc: "Fields to include (comma-separated)"
      class_option :except, type: :array, default: [], desc: "Fields to exclude (comma-separated)"
      class_option :limit, type: :numeric, default: 100, desc: "Maximum number of records to return"
      class_option :skip_large_fields, type: :boolean, default: true, desc: "Skip text and binary fields"
      
      def generate_exposure
        if models.empty?
          # Get all models if none specified
          Rails.application.eager_load!
          model_classes = ActiveRecord::Base.descendants.reject { |c| c.abstract_class? }
          expose_models(model_classes)
        else
          # Get specified models
          model_classes = models.map { |name| name.classify.constantize rescue nil }.compact
          if model_classes.empty?
            say "No valid models found", :red
            return
          end
          expose_models(model_classes)
        end
      end
      
      private
      
      def expose_models(model_classes)
        model_classes.each do |model_class|
          expose_model(model_class)
        end
        
        # Create initializer to create tools for exposed models
        create_initializer if model_classes.any?
      end
      
      def expose_model(model_class)
        say "Exposing model: #{model_class.name}", :green
        
        # Add expose_mcp to the model
        inject_into_file model_path(model_class), after: "class #{model_class.name} < ApplicationRecord\n" do
          options_str = build_options_string
          "  # Expose this model to TinyMCP for read-only operations\n  expose_mcp :read_only#{options_str}\n\n"
        end
      rescue => e
        say "Error exposing #{model_class.name}: #{e.message}", :red
      end
      
      def model_path(model_class)
        Rails.root.join('app', 'models', "#{model_class.name.underscore}.rb")
      end
      
      def build_options_string
        options_parts = []
        
        # Add limit
        options_parts << "limit: #{options[:limit]}" if options[:limit] != 100
        
        # Add only fields
        if options[:only].any?
          fields = options[:only].map { |f| ":#{f}" }.join(', ')
          options_parts << "only: [#{fields}]"
        end
        
        # Add except fields
        if options[:except].any?
          fields = options[:except].map { |f| ":#{f}" }.join(', ')
          options_parts << "except: [#{fields}]"
        end
        
        # Add skip_large_fields
        options_parts << "skip_large_fields: false" unless options[:skip_large_fields]
        
        options_parts.any? ? ", #{options_parts.join(', ')}" : ""
      end
      
      def create_initializer
        create_file 'config/initializers/tiny_mcp_models.rb', <<~RUBY
          # frozen_string_literal: true
          
          # Create TinyMCP tools for exposed ActiveRecord models
          Rails.application.config.after_initialize do
            # Create the tools when ActiveRecord models are loaded
            model_tools = TinyMCP::Rails::ActiveRecord.create_tools
            
            # Add the tools to TinyMCP's available tools
            # They will be available along with any tools in app/mcp_tools
            TinyMCP::Rails.mcp_tools ||= []
            TinyMCP::Rails.mcp_tools.concat(model_tools)
          end
        RUBY
      end
    end
  end
end

