require 'securerandom'

require_relative 'context_extensions'

Mua::SOCKS5::Server::Context = Mua::State::Context.define(
  :remote_ip,
  :remote_port,
  :proxy_username,
  :proxy_password,
  :target_addr,
  :target_addr_type,
  :target_port,
  :target_stream,
  :auth_methods,
  id: {
    default: -> { SecureRandom.uuid }
  },
  auth_required: {
    default: false,
    boolean: true
  },
  includes: [
    Mua::SMTP::Common::ContextExtensions,
    Mua::SOCKS5::Server::ContextExtensions
  ]
)
