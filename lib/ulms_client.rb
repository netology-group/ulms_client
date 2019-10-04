require 'json'
require 'logger'
require 'securerandom'
require 'timeout'
require 'mqtt'

LOG = Logger.new(STDOUT)
LOG.level = Logger::INFO;

DEFAULT_TIMEOUT = 5

###############################################################################

class AssertionError < StandardError; end

class Account
  attr_reader :label, :audience

  def initialize(label, audience)
    @label = label
    @audience = audience
  end

  def to_s
    "#{@label}.#{@audience}"
  end
end

class Agent
  attr_reader :label, :account

  def initialize(label, account)
    @label = label
    @account = account
  end

  def to_s
    "#{@label}.#{@account}"
  end
end

class Client
  attr_reader :version, :mode, :agent

  def initialize(version:, mode:, agent:)
    @version = version
    @mode = mode
    @agent = agent
  end

  def to_s
    "#{@version}/#{@mode}/#{@agent}"
  end
end

class Connection
  OPTIONS = [:username, :password, :clean_session, :keep_alive]

  def initialize(host:, port:, client:, **kwargs)
    @client = client

    @mqtt = MQTT::Client.new
    @mqtt.host = host
    @mqtt.port = port
    @mqtt.client_id = client.to_s

    OPTIONS.each do |option|
        @mqtt.send("#{option}=", kwargs[option]) if kwargs[option] != nil
    end
  end

  # Establish the connection.
  def connect
    @mqtt.connect
    LOG.info("#{@client} connected")
  end

  # Disconnect from the broker.
  def disconnect
    @mqtt.disconnect
    LOG.info("#{@client} disconnected")
  end

  # Publish a message to the `topic`.
  #
  # Options:
  #   - `payload`: An object that will be dumped into JSON as the message payload (required).
  #   - `properties`: MQTT publish properties hash.
  #   - `retain`: A boolean indicating whether the messages should be retained.
  #   - `qos`: An integer 0..2 that sets the QoS.
  def publish(topic, payload:, properties: {}, retain: false, qos: 0)
    envelope = {
      payload: JSON.dump(payload),
      properties: properties
    }

    @mqtt.publish(topic, JSON.dump(envelope), retain, qos)

    LOG.info <<~EOF
      #{@client.agent} published to #{topic} (q#{qos}, r#{retain ? 1 : 0}):
      Payload: #{JSON.pretty_generate(payload)}
      Properties: #{JSON.pretty_generate(properties)}
    EOF
  end

  # Subscribe to the `topic`.
  #
  # Options:
  #   - `qos`: Subscriptions QoS. An interger 0..2.
  def subscribe(topic, qos: 0)
    @mqtt.subscribe([topic, qos])
    LOG.info("#{@client.agent} subscribed to #{topic} (q#{qos})")
  end

  # Waits for an incoming message.
  # If a block is given it passes the received message to the block.
  # If the block returns falsey value it waits for the next one and so on.
  # Returns the received message.
  # Raises if `timeout` is over.
  def receive(timeout=DEFAULT_TIMEOUT)
    Timeout::timeout(timeout, nil, "Timed out waiting for the message") do
      loop do
        topic, json = @mqtt.get
        envelope = JSON.load(json)
        payload = JSON.load(envelope['payload'])
        message = IncomingMessage.new(topic, payload, envelope['properties'])

        LOG.info <<~EOF
          #{@client.agent} received a message from topic #{topic}:
          Payload: #{JSON.pretty_generate(message.payload)}
          Properties: #{JSON.pretty_generate(message.properties)}
        EOF

        return message unless block_given?

        if yield(message)
          LOG.info "The message matched the given predicate"
          return message
        else
          LOG.info "The message didn't match the given predicate. Waiting for the next one."
        end
      end
    end
  end

  # A high-level method that makes a request and waits for the response on it.
  #
  # Options:
  #   - `to`: the destination service `Account` (required).
  #   - `payload`: the publish message payload (required).
  #   - `properties`: additional MQTT properties hash.
  #   - `qos`: Publish QoS. An integer 0..2.
  #   - `timeout`: Timeout for the response awaiting.
  def make_request(method, to:, payload:, properties: {}, qos: 0, timeout: DEFAULT_TIMEOUT)
    correlation_data = SecureRandom.hex

    properties.merge!({
      type: 'request',
      method: method,
      correlation_data: correlation_data,
      response_topic: "agents/#{@client.agent}/api/v1/in/#{to}"
    })

    topic = "agents/#{@client.agent}/api/v1/out/#{to}"
    publish(topic, payload: payload, properties: properties, qos: qos)

    receive(timeout) do |msg|
      msg.properties['type'] == 'response' &&
        msg.properties['correlation_data'] == correlation_data
    end
  end
end

class IncomingMessage
  attr_reader :topic, :payload, :properties

  def initialize(topic, payload, properties)
    @topic = topic
    @payload = payload
    @properties = properties
  end

  # A shortcut for payload fields. `msg['key']` is the same as `msg.payload['key']`.
  def [](key)
    @payload[key]
  end
end

###############################################################################

# Raises unless the given argument is truthy.
def assert(value)
  raise AssertionError.new("Assertion failed") unless value
end

# Builds an `Agent` instance.
def agent(label, account)
  Agent.new(label, account)
end

# Builds an `Account` instance.
def account(label, audience)
  Account.new(label, audience)
end

# Builds a `Client` instance.
#
# Options:
#  - `mode`: Connection mode (required). Available values: `agents`, `service-agents`, `bridge-agents`, `observer-agents`.
#  - `version`: Always `v1` for now.
def client(agent, mode:, version: 'v1')
  Client.new(version: version, mode: mode, agent: agent)
end

# Connects to the broker and subscribes to the client's inbox topics.
#
# Options:
#   - `host`: The broker's host (required).
#   - `port`: The broker's TCP port for MQTT connections (required).
#   - `client`: The `Client` object (required).
#   - `username`: If the broker has authn enabled this requires any non-empty string.
#   - `password`: If the broker has authn enalbed this requires the password for the `client`'s account.
#   - `clean_session`: A boolean indicating whether the broker has to clean the previos session.
#   - `keep_alive`: Keep alive time in seconds.
def connect(host: 'localhost', port: 1883, client:, **kwargs)
  conn = Connection.new(host: host, port: port, client: client, **kwargs)
  conn.connect
  conn.subscribe("agents/#{client.agent}/api/v1/in/#")
  conn
end
