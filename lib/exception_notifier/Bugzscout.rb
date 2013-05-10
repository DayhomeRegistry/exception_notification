# This library that gives you easy access to the excellent BugzScout feature of FogBugz (http://fogcreek.com/fogbugz).
# For those that don't know, BugzScout allows bug data (exceptions, user input, etc) to be reported back to your FogBugz install
# for further diagnosis.
#
# Author:: Michael Gorsuch (mailto:michael@styledbits.com)
# Copyright:: Copyright (c) 2009 Michael Gorsuch
# License:: Distributed under the same terms as Ruby

require 'nestful'
require 'uri'

module FogBugz
  # This is the core class that does all of the heavy lifting.
  class BugzScout
    attr_accessor :url, :user, :project, :area, :title, :forceNew, :body, :email

    # provide BugzScout with the URL of your FogBugz instance, including the 'scoutsubmit.asp' entry point
    # example: https://styledbits.fogbugz.com/scoutsubmit.asp
    def initialize(url)
      Rails.logger.info "#{self.class}.initialize"
      self.url = url
    end

    # send the response to FogBugz
    # return true if all goes well
    # throw a BugzScoutError exception along with the error text if otherwise.
    def submit
      Rails.logger.info "FogBugz::BugzScout.submit"

      # ensure that the required fields are included
      validate

      body = {
        :ScoutUserName => self.user,
        :ScoutProject => self.project,
        :ScoutArea => self.area,
        :Description => self.title,
        :ForceNewBug => self.forceNew,
        :Extra => self.body,
        :Email => self.email,
        :ScoutDefaultMessage => "",
        :FriendlyResponse => 0
      }


      begin
        Rails.logger.info "Calling FogBugz"
        response = Nestful.post(url, body).to_json
      rescue => e
        Rails.logger.fatal "#{e.message}:#{e.backtrace}"
        raise(BugzScoutError, e.message)
      end

      if response =~ /<Error>(.*)<\/Error>/
        # if we see an error response, we know that we fudged some of our input values to BugzScout
        # the error message should contain where we went wrong.
        # We raise the exception so the user can catch it and log if necessary.  No one likes things that fail silently!
        Rails.logger.fatal "BugzScoutError:#{$1}"
        raise(BugzScoutError, $1)
      else
        Rails.logger.info "FogBugz success."
        # we'll return 'true' for the sake of clarity
        return true
      end
    end

    def validate
      raise(BugzScoutError, 'You have to provide a user name') unless self.user
      raise(BugzScoutError, 'You must provide a FogBugz project') unless self.project
      raise(BugzScoutError, 'You have to provide an area') unless self.area
    end

    def self.submit(url)
      scout = BugzScout.new(url)
      yield(scout)
      scout.submit
    end

  end

  # just a simple custom exception
  class BugzScoutError < RuntimeError ; end
end