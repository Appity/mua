require_relative 'context_extensions'

Mua::SMTP::Client::Context = Mua::State::Context.define(
  :username,
  :password,
  :remote,
  :read_task,
  features: {
    default: -> { { } }
  },
  hostname: {
    default: 'localhost'
  },
  protocol: {
    default: :smtp
  },
  auth_required: {
    default: false,
    boolean: true
  },
  tls_requested: {
    default: true,
    boolean: true
  },
  tls_required: {
    default: false,
    boolean: true
  },
  proxy: {
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
  includes: Mua::SMTP::Client::ContextExtensions
)
