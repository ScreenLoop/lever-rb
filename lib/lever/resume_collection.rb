# frozen_string_literal: true

require 'lever/resume'
require 'lever/resource_collection'

module Lever
  class ResumeCollection < ResourceCollection
    def initialize(*args, **kw_args)
      kw_args.merge!(resource_class: Resume)
      super
    end
  end
end
