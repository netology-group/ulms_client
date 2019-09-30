# This is an example of sending a broadcast message to a room.
# I used this one to test them when the broker part wasn't ready at the moment so at first
# it simulates the broker's job by sending `subscription.create` event to conference.
# Then it makes the `message.broadcast` request itself as a user.
# So this example illustrates working with events and multiple connections.

require 'json'
require 'ulms_client'

room_id = '3a7c5e97-726f-4313-8163-2b834f7317b3'

svc_audience = 'dev.svc.example.org'
usr_audience = 'dev.usr.example.org'
broker = agent('alpha', account('mqtt-gateway', svc_audience))
user = agent('web', account('fey', usr_audience))
conference = account('conference', svc_audience)

conn_opts = { host: 'localhost', port: 1883 }
broker_conn = connect conn_opts.merge(client: client(broker, mode: 'service-agents'))
user_conn = connect conn_opts.merge(client: client(user, mode: 'agents'))

# Put user online into the room.
broker_conn.publish "agents/#{user}/api/v1/out/#{conference}",
  payload: {
    subject: user,
    object: ['rooms', room_id, 'events']
  },
  properties: {
    type: 'event',
    label: 'subscription.create'
  }

# Send broadcast message.
response = user_conn.make_request 'message.broadcast', to: conference, payload: {
  room_id: room_id,
  data: JSON.dump(key: 'value')
}

# Receive broadcast message in the room's events topic.
response = user_conn.receive do |msg|
  msg.topic == "apps/#{conference}/api/v1/rooms/#{room_id}/events"
end

assert JSON.load(response.payload)['key'] == 'value'
