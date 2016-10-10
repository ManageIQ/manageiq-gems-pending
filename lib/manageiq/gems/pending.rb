module ManageIQ
  module Gems
    module Pending
      def self.root
        Pathname.new(File.join(__dir__, "../../.."))
      end
    end
  end
end

$LOAD_PATH << ManageIQ::Gems::Pending.root.join("lib", "gems", "pending").to_s
$LOAD_PATH << ManageIQ::Gems::Pending.root.join("lib", "gems", "pending", "util").to_s
