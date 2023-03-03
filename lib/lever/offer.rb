require 'lever/base'

module Lever
  class Offer < Base
    property :id
    property :status
    property :creator
    property :fields
    property :sent_document, from: :sentDocument
    property :signed_document, from: :signedDocument
    property :created_at, from: :createdAt
  end
end
