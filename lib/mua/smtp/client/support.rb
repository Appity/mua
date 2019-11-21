module Mua::SMTP::Client::Support
  # == Module and Mixin Methods =============================================

  # Expands a standard SMTP reply into three parts: Numerical code, message
  # and a boolean indicating if this reply is continued on a subsequent line.
  def unpack_reply(reply)
    reply.match(/\A(\d+)([ \-])(.*)/) and [ $1.to_i, $3, $2 == '-' ? :continued : nil ].compact
  end

  # Encodes the given user authentication paramters as a Base64-encoded
  # string as defined by RFC4954
  def encode_auth(username, password)
    base64("\0#{username}\0#{password}")
  end
  
  # Encodes the given data for an RFC5321-compliant stream where lines with
  # leading period chracters are escaped.
  def encode_data(data)
    data.gsub(/((?:\r\n|\n)\.)/m, '\\1.')
  end

  # Encodes a string in Base64 as a single line
  def base64(string)
    [ string.to_s ].pack('m').gsub(/\n/, '')
  end

  extend self
end
