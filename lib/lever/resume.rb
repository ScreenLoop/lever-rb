require 'lever/base'

module Lever
  class Resume < Base
    property :id
    property :created_at, from: :createdAt
    property :file, from: :parse_resume_file
    property :parsed_data, from: :parsedData

    def parse_resume_file
      raise Error, "what the file? #{file&.to_json}"
      return if file.blank?

      Lever::File.new(file.merge(client: client))
    end
  end
end
