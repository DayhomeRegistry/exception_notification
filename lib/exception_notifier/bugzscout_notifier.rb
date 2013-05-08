class ExceptionNotifier
  class CampfireNotifier

    attr_accessor :subdomain
    attr_accessor :token
    attr_accessor :room

    def initialize(options)
      begin
        url       = options.delete(:url)
        username  = options.delete(:username) || 'BugzScout'
        project   = options.delete(:project) || 'Inbox'
        area      = options.delete(:area) || 'Misc'
        forceNew  = options.delete(:forceNew) || false  

        @bugzscout = FogBugz::BugzScout.new url
        @bugzscout.username = username
        @bugzscout.project = project
        @bugzscout.area = area
        @bugzscout.new = forceNew

          
        end
        
      rescue
        @bugzscout = nil
      end
    end

    def call(exception, options={})
      @bugzscout.title = compose_subject
      @bugzscout.body = "A new exception occurred: '#{exception.message}' on '#{exception.backtrace.first}'" if active?
      @bugzscout.submit
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
  end
end
