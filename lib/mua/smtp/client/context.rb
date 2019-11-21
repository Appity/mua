Mua::SMTP::Client::Context = Mua::State::Context.with_attributes(
  :username,
  :password,
  :remote,
  initial_state: :greeting,
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
  proxy: {
    default: false,
    boolean: true
  },
  timeout: {
    default: Mua::Constants::TIMEOUT_DEFAULT
  },
  includes: Mua::SMTP::Client::ContextExtensions
)
