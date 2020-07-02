# This is an example of dynamically subscribing an agent to a broadcast events topic as a service.

require 'securerandom'
require 'ulms_client'

service = agent(SecureRandom.hex(), account('some_service', 'dev.svc.example.org'))
service_conn = connect host: 'localhost', port: 1883, agent: service, mode: 'service'

user = agent('web', account("user#{SecureRandom.hex()}", 'dev.usr.example.org'))
user_conn = connect host: 'localhost', port: 1883, agent: user

inbox_topic = "agents/#{user}/api/v1/in/#{service.account}"
user_conn.subscribe inbox_topic

# Service dynamically subscribes the user to the broadcast events topic.
correlation_data = SecureRandom.hex()

service_conn.publish inbox_topic,
  payload: {
    subject: user,
    object: %w(rooms 123 events)
  },
  properties: {
    type: 'request',
    method: 'subscription.create',
    response_topic: inbox_topic,
    correlation_data: correlation_data
  }

# User receives the response.
response = user_conn.receive do |msg|
  msg.properties['type'] == 'response' && msg.properties['correlation_data'] == correlation_data
end

assert response.properties['status'] == '200'

# Service sends a broadcast event.
broadcast_topic = "apps/#{service.account}/api/v1/rooms/123/events"

service_conn.publish broadcast_topic,
  payload: {
    message: 'hello world'
  },
  properties: {
    type: 'event',
    label: 'room.message'
  }

# User receives the broadcast event.
event = user_conn.receive do |msg|
  msg.topic == broadcast_topic && msg.properties['type'] == 'event'
end

assert event.properties["label"] == 'room.message'
assert event.payload['message'] == 'hello world'
