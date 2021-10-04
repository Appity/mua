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
  :authenticated_as,
  :auth_username,
  :logger,
  id: {
    default: -> { SecureRandom.uuid }
  },
  connected: {
    default: true,
    boolean: true
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
  size_limit: {
    default: 33554432
  },
  protocol: {
    default: :esmtp
  },
  pipelining: {
    default: false,
    boolean: true
  },
  auth: {
    default: [ :plain, :login ]
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
  smtp_loggers: {
    default: -> { [ ] }
  },
  includes: [
    Mua::SMTP::Common::ContextExtensions,
    Mua::SMTP::Server::ContextExtensions
  ]
)
