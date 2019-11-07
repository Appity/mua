module ASMail
  VERSION = File.readlines(File.expand_path('../../VERSION', __dir__)).first.chomp

  def self.version
    VERSION
  end
end
