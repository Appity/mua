require_relative 'context_extensions'
require_relative '../state'

Mua::Client::Context = Mua::State::Context.define(
  :smtp_host,
  :smtp_port,
  :smtp_username,
  :smtp_password,
  :proxy_username,
  :proxy_password,
  :proxy_host,
  :proxy_port,
  :remote_host,
  :read_task,
  :reply_code,
  :reply_message,
  features: {
    default: -> { { } }
  },
  hostname: {
    default: 'localhost'
  },
  protocol: {
    default: :smtp
  },
  tls_requested: {
    default: true,
    boolean: true
  },
  tls_required: {
    default: false,
    boolean: true
  },
  timeout: {
    default: Mua::Constants::TIMEOUT_DEFAULT
  },
  message_queue: {
    default: -> { [ ] }
  },
  message: {
    default: nil
  },
  close_requested: {
    boolean: true,
    default: false
  },
  includes: Mua::Client::ContextExtensions
)
