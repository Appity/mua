require_relative 'context_extensions'

Mua::SMTP::Client::Context = Mua::State::Context.define(
  :username,
  :password,
  :remote,
  hostname: {
    default: 'localhost'
  },
  protocol: {
    default: :smtp
  },
  auth_support: {
    default: false,
    boolean: true
  },
  auth_required: {
    default: false,
    boolean: true
  },
  tls: {
    default: false,
    boolean: true
  },
  tls_supported: {
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
  includes: Mua::SMTP::Client::ContextExtensions
)
