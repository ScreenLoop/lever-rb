require 'lever/base'

module Lever
  class FeedbackTemplate < Base
    property :id
    property :text
    property :group
    property :instructions
    property :created_at, from: :createdAt, with: ->(value) { Time.at(value) }
    property :updated_at, from: :updatedAt, with: ->(value) { Time.at(value) if value }
    property :stage
    property :fields
  end
end
