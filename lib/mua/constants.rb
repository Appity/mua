module Mua::Constants
  # == Constants ============================================================
  
  LINE_REGEXP = /\A.*?\r?\n/.freeze
  CRLF_DELIMITER_REGEXP = /\r?\n/.freeze
  CRLF = "\r\n".freeze
  LF ="\n".freeze
  
  SERVICE_PORT = {
    smtp: 25,
    imap: 993,
    socks5: 1080
  }.freeze

  TIMEOUT_DEFAULT = 30

  # -- RFC1928/RFC1929 ------------------------------------------------------

  SOCKS5_VERSION = 5

  SOCKS5_METHOD = {
    no_auth: 0,
    gssapi: 1,
    username_password: 2
  }.freeze
  
  SOCKS5_COMMAND = {
    connect: 1,
    bind: 2
  }.freeze
  
  SOCKS5_REPLY = {
    0 => 'Succeeded',
    1 => 'General SOCKS server failure',
    2 => 'Connection not allowed',
    3 => 'Network unreachable',
    4 => 'Host unreachable',
    5 => 'Connection refused',
    6 => 'TTL expired',
    7 => 'Command not supported',
    8 => 'Address type not supported'
  }.freeze
  
  SOCKS5_ADDRESS_TYPE = {
    ipv4: 1,
    fqdn: 3,
    ipv6: 4
  }.freeze
end
