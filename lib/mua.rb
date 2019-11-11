require 'mua/version'

module Mua
  class Error < StandardError
  end
end

require_relative 'mua/interpreter'

require_relative 'mua/imap'
require_relative 'mua/smtp'
require_relative 'mua/socks5'
