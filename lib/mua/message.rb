require 'securerandom'

class Mua::Message
  # == Constants ============================================================

  STATES = %i[
    queued
    retry
    delivered
    test_passed
    test_failed
    rejected
    bounced
    failed
  ].freeze

  STATE_DEFAULT = :queued
  RETRY_LIMIT_DEFAULT = 2

  # == Extensions ===========================================================

  include Comparable

  # == Properties ===========================================================

  attr_reader :id
  attr_accessor :mail_from
  attr_reader :rcpt_to
  attr_accessor :data

  attr_accessor :state
  attr_accessor :remote_ip
  attr_accessor :auth_username

  attr_reader :result_code
  attr_accessor :result_message

  attr_reader :delivery_results

  attr_accessor :batch

  # == Class Methods ========================================================

  def self.states
    STATES
  end

  def self.from(message = nil, **args)
    case (message)
    when self
      message
    else
      new(**(message || { }).merge(args))
    end
  end

  # == Instance Methods =====================================================

  def initialize(args = nil)
    args ||= { }

    @id = args[:id] || args['id'] || SecureRandom.uuid
    @mail_from = args[:mail_from] || args['mail_from']
    @rcpt_to = [ args[:rcpt_to] || args['rcpt_to'] ].flatten.compact
    @data = (args[:data] || args['data']).to_s.gsub(/\r?\n/, "\r\n")
    @test = !!(args[:test] || args['test'])

    @remote_ip = args[:remote_ip] || args['remote_ip']
    @auth_username = args[:auth_username] || args['auth_username']

    @state = (args[:state] || args['state'] || STATE_DEFAULT).to_sym

    @batch = args[:batch]
    @retry_limit = args[:retry_limit]&.to_i || RETRY_LIMIT_DEFAULT

    @delivery_results = [ ]
    @processed = Async::Condition.new
  end

  def hash
    @id.hash
  end

  def <=>(message)
    @id <=> message.id
  end

  def eql?(message)
    self === message or @id == message.id
  end
  alias_method :equal?, :eql?

  def each_rcpt
    @each_rcpt ||= @rcpt_to.each
  end

  def test?
    @test
  end

  def valid?
    [ @mail_from, @rcpt_to, @data ].all? do |v|
      v and v.match?(/\S/)
    end
  end

  def requeue!
    return if (@retry_limit and @delivery_results.length >= @retry_limit)

    @batch&.requeue(self)
  end

  def processed!(result = nil)
    @batch&.processed(self)

    @processed.signal(result || @delivery_results.last)
  end

  def wait
    case (@state)
    when :queued
      @processed.wait
    else
      @delivery_results.last
    end
  end

  STATES.each do |s|
    define_method(:"#{s}?") do
      @state == s
    end

    define_method(:"#{s}!") do |**delivery_result|
      @delivery_results << Mua::Message::DeliveryResult.new(
        **delivery_result,
        message: self,
        state: s
      )

      @state = s
      @result_code ||= delivery_result[:result_code]
      @result_message ||= delivery_result[:result_message]
    end
  end

  def result_code=(v)
    @result_code = v
  end

  def inspect
    "<#{self.class}##{self.object_id} @id=#{@id.inspect} @mail_from=#{@mail_from.inspect} @rcpt_to=#{@rcpt_to.inspect} @delivery_results=#{@delivery_results.length}>"
  end
end

require_relative './message/batch'
require_relative './message/delivery_result'
