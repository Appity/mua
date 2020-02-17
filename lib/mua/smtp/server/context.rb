require 'securerandom'

require_relative 'context_extensions'

Mua::SMTP::Server::Context = Mua::State::Context.define(
  :read_task,
  :message,
  :helo_hostname,
  :smtp_username,
  :smtp_password,
  :tls_key_path,
  :tls_cert_path,
  :local_ip,
  :local_port,
  :remote_ip,
  :remote_port,
  id: {
    default: -> { SecureRandom.uuid }
  },
  connected_at: {
    default: -> { Time.now.utc }
  },
  hostname: {
    default: 'localhost'
  },
  smtp_timeout: {
    default: Mua::Constants::TIMEOUT_DEFAULT
  },
  protocol: {
    default: :esmtp
  },
  tls_initial: {
    default: false,
    boolean: true
  },
  tls_advertise: {
    default: false,
    boolean: true
  },
  tls_required: {
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
