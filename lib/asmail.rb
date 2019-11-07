require 'asmail/version'

module ASMail
  class Error < StandardError
  end
end

require_relative 'asmail/imap'
require_relative 'asmail/smtp'
require_relative 'asmail/socks5'
