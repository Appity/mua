module Mua
  VERSION = File.readlines(File.expand_path('../../VERSION', __dir__)).first.chomp.freeze

  def self.version
    VERSION
  end
end
