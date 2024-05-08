require 'lever/base'

module Lever
  class Resume < Base
    property :id
    property :created_at, from: :createdAt
    property :file
    property :parsed_data, from: parsedData
  end
end
