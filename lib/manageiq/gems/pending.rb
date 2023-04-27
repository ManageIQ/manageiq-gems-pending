require "manageiq/gems/pending/version"
require 'manageiq/gems/pending/zeitwerk'

module ManageIQ
  module Gems
    module Pending
      def self.root
        @root ||= Pathname.new(__dir__).join("../../..")
      end
    end
  end
end
