require 'httparty'

# TODO: Add pagination (lever limits to 100)

module Lever
  class Client
    include HTTParty

    attr_accessor :base_uri

    def initialize(token, options = {})
      if options[:sandbox]
        @base_uri = 'https://api.sandbox.lever.co/v1'
      else
        @base_uri = 'https://api.lever.co/v1'
      end
      
      @options = { basic_auth: { username: token } }
    end
    
    def users(id: nil, on_error: nil)
      get_resource('/users', Lever::User, id, { on_error: on_error })
    end

    def opportunities(id: nil, on_error: nil)
      get_resource(
        '/opportunities',
        Lever::Opportunity,
        id,
        { query: id ? 'expand=applications&expand=stages' : {}, on_error: on_error }
      )
    end

    def postings(id: nil, on_error: nil)
      get_resource('/postings', Lever::Posting, id, { on_error: on_error })
    end

    def add_note(opportunity_id, body)
      post_resource("/opportunities/#{opportunity_id}/notes", { value: body })
    end

    def post_resource(path, body)
      response = self.class.post("#{base_uri}#{path}", @options.merge({ body: body }))

      response.parsed_response
    end

    def get_resource(base_path, objekt, id = nil, options = {})
      path = id.nil? ? base_path : "#{base_path}/#{id}"

      add_query = options[:query]
      on_error = options[:on_error]

      response = self.class.get("#{base_uri}#{path}", @options.merge({ query: add_query }))
      if response.success?
        include_properties = { client: self }

        if id
          objekt.new(response.parsed_response.dig('data').merge(include_properties))
        else
          response.parsed_response.dig('data').map do |hash|
            objekt.new(hash.merge(include_properties))
          end
        end
      else
        on_error&.call(response)
      end
    end
  end
end