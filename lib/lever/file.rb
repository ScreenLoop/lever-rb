require 'lever/base'

module Lever
  class File < Base
    property :download_url, from: :downloadUrl
    property :ext
    property :name
    property :status
    property :size
    property :uploaded_at, from: :uploadedAt
  end
end
