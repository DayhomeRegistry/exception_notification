#Using our own implementation rather than the bugzscout gem 
#because that code uses rest-client which borks on the 
#URI.encode for the templated response.
require "#{File.dirname(__FILE__)}/Bugzscout"
require 'pp'
require 'uri'

class ExceptionNotifier
  class BugzscoutNotifier

    attr_accessor :url
    attr_accessor :username
    attr_accessor :project
    attr_accessor :area
    attr_accessor :forceNew

    def initialize(options)
      begin
        Rails.logger.debug "BugzScoutNotifier.initialize"
        Rails.logger.debug "Options: #{options.to_json}"
        url       = options.delete(:url)
        username  = options.delete(:username) || 'BugzScout'
        project   = options.delete(:project) || 'Inbox'
        area      = options.delete(:area) || 'Misc'      
        forceNew  = options.delete(:forceNew) || false  
        
        # attr_accessor :url, :user, :project, :area, :new, :title, :body, :email
        @bugzscout = FogBugz::BugzScout.new url
        @bugzscout.user = username
        @bugzscout.project = project
        @bugzscout.area = area
        @bugzscout.forceNew = forceNew if !forceNew.nil?
      rescue
        @bugzscout = nil
      end
    end

    def call(exception, options={})
      Rails.logger.debug "BugzScoutNotifier.call"
      #Rails.logger.debug "options: #{options}"

      @exception  = exception      
      @bugzscout.title = compose_subject if active?
      #@bugzscout.body = "A new exception occurred: '#{exception.message}' on '#{exception.backtrace.first}'" if active?
      begin

        message = create_message(@exception,options).to_str 
        @bugzscout.body = message.html_safe if active?
      rescue => e
        Rails.logger.fatal "Rendering bugzscout message #{exception.message} on #{exception.backtrace.first} failed: #{e.message}: #{e.backtrace}"
      end
      Rails.logger.debug("@bugzscout before submit: #{@bugzscout.to_json}")
      @bugzscout.submit if active?
    end

    class ErrorFormatter < AbstractController::Base
      include AbstractController::Rendering
      include AbstractController::Layouts
      include AbstractController::Helpers
      include AbstractController::Translation
      include AbstractController::AssetPaths

      # Append application view path to the ExceptionNotifier lookup context.
      self.append_view_path "#{File.dirname(__FILE__)}/views"

      class MissingController
        def method_missing(*args, &block)
        end
      end

      def error_notification(env, exception, options={})
        load_custom_views

        if !env.nil?
          @env        = env
          @request    = ActionDispatch::Request.new(env)
          @kontroller = env['action_controller.instance'] 
          @data       = (env['exception_notifier.exception_data'] || {}).merge(options[:data] || {})
          @options    = options.reverse_merge(env['exception_notifier.options'] || {})
          @sections   = @options[:sections] || %w(request session environment backtrace)
        else
          @kontroller = MissingController.new
          @data       = options[:data] || {}
          @options    = options
          @sections   = @options[:sections] || %w(backtrace data)
        end
        @exception  = exception
        @backtrace  = exception.backtrace ? clean_backtrace(exception) : []
        @sections   = @sections + %w(data) unless @data.empty?

        #Rails.logger.debug "@env: #{@env}"
        #Rails.logger.debug "@request: #{@request}"
        #Rails.logger.debug "@kontroller: #{@kontroller}"
        #Rails.logger.debug "@data: #{@data}"
        #Rails.logger.debug "@options: #{@options}"
        #Rails.logger.debug "@exception: #{@exception}"
        #Rails.logger.debug "@backtrace: #{@backtrace}"
        #Rails.logger.debug "@sections: #{@sections}"

        set_data_variables

        render "error_notification"
      end

      private

      def clean_backtrace(exception)
        if defined?(Rails) && Rails.respond_to?(:backtrace_cleaner)
          Rails.backtrace_cleaner.send(:filter, exception.backtrace)
        else
          exception.backtrace
        end
      end
      def set_data_variables
        @data.each do |name, value|
          instance_variable_set("@#{name}", value)
        end
      end
      def load_custom_views
        self.prepend_view_path Rails.root.nil? ? "app/views" : "#{Rails.root}/app/views" if defined?(Rails)
      end

      helper_method :inspect_object
      def inspect_object(object)
        case object
        when Hash, Array
          object.inspect
        else
          object.to_s
        end
      end
    end

    private

    def active?
      !@bugzscout.nil?
    end

    def compose_subject
      subject = "BugzScout: "
      subject << " (#{@exception.class})"
      subject << " #{@exception.message.inspect}"
      subject.length > 120 ? subject[0...120] + "..." : subject
    end
    def create_message(exception, options={})
      env = options.delete(:env)
      ErrorFormatter.new.error_notification(env,exception, options)
    end
  end
end
