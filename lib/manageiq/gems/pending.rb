# In case this is required directly
require 'manageiq-gems-pending'

require "manageiq/gems/pending/version"

module ManageIQ
  module Gems
    module Pending
      def self.root
        @root ||= Pathname.new(__dir__).join("../../..")
      end
    end
  end
end
