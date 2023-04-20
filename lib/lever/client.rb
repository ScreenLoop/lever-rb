# frozen_string_literal: true

require 'lever/application'
require 'lever/archive_reason'
require 'lever/feedback_template'
require 'lever/interview'
require 'lever/offer'
require 'lever/opportunity_collection'
require 'lever/posting'
require 'lever/stage_collection'
require 'lever/user'

require 'lever/error'

require 'httparty'
require 'retriable'

module Lever
  class Client
    include HTTParty

    BASE_PATHS = {
      opportunities: '/opportunities',
      stages:        '/stages'
    }

    DEFAULT_SCOPES = 'offline_access opportunities:read:admin archive_reasons:read:admin users:read:admin interviews:read:admin postings:read:admin feedback_templates:read:admin notes:write:admin'

    attr_accessor :base_uri
    attr_accessor :oauth_base_uri
    attr_reader :options

    def initialize(options = {sandbox: true})
      if options[:sandbox]
        @base_uri = 'https://api.sandbox.lever.co/v1'
        @oauth_base_uri = 'https://sandbox-lever.auth0.com'
      else
        @base_uri = 'https://api.lever.co/v1'
        @oauth_base_uri = 'https://auth.lever.co'
      end

      if options[:headers]
        @options[:headers] = options[:headers]
      else
        @options = options
      end
    end

    def set_auth_api_token(token)
      @options = @options.merge(basic_auth: { username: token })
    end

    def set_auth_oauth_token(token)
      if @options[:headers].present?
        @options[:headers][:Authorization] = "Bearer #{token}"
      else
        @options = @options.merge(headers: { Authorization: "Bearer #{token}" })
      end
    end

    def request_authorization_url(client_id, redirect_uri, state, scopes = DEFAULT_SCOPES)
      "#{@oauth_base_uri}/authorize?client_id=#{client_id}&redirect_uri=#{redirect_uri}&state=#{state}&response_type=code&scope=#{scopes}&prompt=consent&audience=#{@base_uri}/"
    end

    def request_access_token(client_id, client_secret, redirect_uri, code)
      body = { body: {
        client_id: client_id,
        client_secret: client_secret,
        grant_type: 'authorization_code',
        code: code,
        redirect_uri: redirect_uri
      }}
      self.class.post("#{@oauth_base_uri}/oauth/token", body)
    end

    def refesh_access_token(client_id, client_secret, refresh_token)
      body = { body: {
        client_id: client_id,
        client_secret: client_secret,
        grant_type: 'refresh_token',
        refresh_token: refresh_token
      }}
      self.class.post("#{@oauth_base_uri}/oauth/token", body)
    end

    def users(id: nil, on_error: nil, query: {limit: 100})
      get_resource('/users', Lever::User, id, { query: query, on_error: on_error })
    end

    def opportunities(id: nil, contact_id: nil, on_error: nil, return_opportunity_collection: false, query: {limit: 100}, **query_params)
      # Here we're taking the first step in a larger journey to allow methods like this to return a `ResourceCollection`
      #
      # To start, we aim not to change current expected usage. The scenarios are:
      # client.opportunities                            # returns an Array of Lever::Opportunity objects (unchanged)
      # client.opportunities(contact_id: 123)           # returns an Array of Lever::Opportunity objects (unchanged)
      # client.opportunities(id: 456)                   # returns a Lever::Opportunity (unchanged)
      # client.opportunities(id: 456, contact_id: 123)  # returns a Lever::Opportunity (unchanged)
      # client.opportunities(return_opportunity_collection: true) # returns a Lever::OpportunityCollection (this is new)
      # client.opportunities(some: :param_val)                    # returns a Lever::OpportunityCollection (this is new)
      # client.opportunities(contact_id: 123, some: :param_val)           # contact_id will be added to query_params
      # client.opportunities(id: 456, on_error: [proc], some: :param_val) # raises an error (mixing old/new interfaces)
      #
      if query_params.any? || return_opportunity_collection
        if [id, on_error].compact.any?
          raise Lever::Error, "`Lever::Client#opportunities`'s new interface for returning an OpportunityCollection "\
                              "does not allow for `id:` or `on_error:` keyword args"
        end
        query_params.merge!(contact_id: contact_id) unless contact_id.nil?

        return Lever::OpportunityCollection.new(client: self, query_params: query_params)
      end

      # query = if id
      #   'expand=applications&expand=stage'
      # else
      #   contact_id ? { contact_id: contact_id } : {}
      # end

      get_resource(
        BASE_PATHS[__method__],
        Lever::Opportunity,
        id,
        { query: query, on_error: on_error }
      )
    end

    def interviews(opportunity_id:, id: nil)
      get_resource("/opportunities/#{opportunity_id}/interviews", Lever::Interview, id)
    end

    def stages(id: nil, on_error: nil, return_stage_collection: false, **query_params)
      # Here we're taking the first step in a larger journey to allow methods like this to return a `ResourceCollection`
      #
      # To start, we aim not to change current expected usage. The scenarios are:
      # client.stages                   # returns an Array of Lever::Stage objects (unchanged)
      # client.stages(id: 123)          # returns a Lever::Stage (unchanged)
      # client.stages(return_stage_collection: true) # returns a Lever::StageCollection (this is new)
      # client.stages(some: :param_val)              # returns a Lever::StageCollection (this is new)
      # client.opportunities(id: 123, on_error: [proc], some: :param_val) # raises an error (mixing old/new interfaces)
      #
      if query_params.any? || return_stage_collection
        if [id, on_error].compact.any?
          raise Lever::Error, "`Lever::Client#stages`'s new interface for returning a StageCollection "\
                              "does not allow for `id:` or `on_error:` keyword args"
        end

        return Lever::StageCollection.new(client: self, query_params: query_params)
      end

      get_resource(BASE_PATHS[__method__], Lever::Stage, id, { on_error: on_error })
    end

    def feedback_templates(id: nil, on_error: nil, query: {limit: 100})
      get_resource('/feedback_templates', Lever::FeedbackTemplate, id, { query: query, on_error: on_error })
    end

    def postings(id: nil, on_error: nil, query: {limit: 100})
      get_resource('/postings', Lever::Posting, id, { query: query, on_error: on_error })
    end

    def archive_reasons(id: nil, on_error: nil, query: {limit: 100})
      get_resource('/archive_reasons', Lever::ArchiveReason, id, { on_error: on_error, query: query })
    end

    def hired_archive_reasons(on_error: nil)
      get_resource('/archive_reasons', Lever::ArchiveReason, nil, { on_error: on_error, query: { type: 'hired' } })
    end

    def offers(opportunity_id:, on_error: nil)
      get_resource("/opportunities/#{opportunity_id}/offers", Lever::Offer, nil, { on_error: on_error })
    end

    def add_note(opportunity_id, body, perform_as = nil)
      post_resource("/opportunities/#{opportunity_id}/notes#{'?perform_as=' + perform_as if perform_as.present?}", { value: body })
    end

    def post_resource(path, body)
      response = self.class.post("#{base_uri}#{path}", @options.merge({ body: body }))

      response.parsed_response
    end

    def with_retries
      return yield if using_with_retries

      begin
        # Eventually we want to have lower-level methods like #get_resource implement retries automatically
        # So let's disallow nested `with_retries` blocks just in case we add it there but forget to remove it from
        #   higher-level methods
        self.using_with_retries = true

        Retriable.retriable(on: [Lever::TooManyRequestsError, Lever::ServerError, Lever::ServiceUnavailableError]) do
          yield
        end
      ensure
        self.using_with_retries = false
      end
    end

    def get_resource(base_path, objekt, id = nil, options = {})
      path = id.nil? ? base_path : "#{base_path}/#{id}"

      add_query = options[:query]
      on_error = options[:on_error]

      response = self.class.get("#{base_uri}#{path}", @options.merge(query: add_query))
      if response.success?
        parsed_response = response.parsed_response

        yield parsed_response if block_given?

        include_properties = { client: self }

        result = if id
          objekt.new(parsed_response.dig('data').merge(include_properties))
        else
          parsed_response.dig('data').map do |hash|
            objekt.new(hash.merge(include_properties))
          end
        end

        {data: result, next: parsed_response.dig('next'), hasNext: parsed_response.dig('hasNext')}
      else
        if on_error
          on_error.call(response)
        else
          error = case response.code
                  when 400
                    Lever::InvalidRequestError
                  when 401
                    Lever::UnauthorizedError
                  when 403
                    Lever::ForbiddenError
                  when 404
                    Lever::NotFoundError
                  when 429
                    Lever::TooManyRequestsError
                  when 500
                    Lever::ServerError
                  when 503
                    Lever::ServiceUnavailableError
                  else
                    Lever::Error
                  end

          raise error.new(response.code, response.code)
        end
      end
    end

    private

    attr_accessor :using_with_retries # see #with_retries
  end
end
