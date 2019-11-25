require_relative 'context_extensions'

Mua::SMTP::Server::Context = Mua::State::Context.define(
  :read_task,
  :message,
  :remote_host,
  :smtp_username,
  :smtp_password,
  :tls_key_path,
  :tls_cert_path,
  :local_ip,
  :local_port,
  :remote_ip,
  :remote_port,
  hostname: {
    default: 'localhost'
  },
  smtp_timeout: {
    default: Mua::Constants::TIMEOUT_DEFAULT
  },
  protocol: {
    default: :esmtp
  },
  tls: {
    default: false,
    boolean: true
  },
  messages: {
    default: -> { [ ] }
  },
  includes: [
    Mua::SMTP::Common::ContextExtensions,
    Mua::SMTP::Server::ContextExtensions
  ]
)
