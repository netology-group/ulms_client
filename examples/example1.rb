# This is an example of a request chain to conference.
# We make a request, get the result id, put it into the next one and so on.

require 'ulms_client'

me = agent('web', account('fey', 'dev.usr.example.org'))
conference = account('conference', 'dev.svc.example.org')

conn = connect host: 'localhost', port: 1883, client: client(me, mode: 'agents')

# Create a room.
response = conn.make_request 'room.create', to: conference, payload: {
  audience: 'dev.svc.example.org',
  time: [nil, nil]
}

assert response.properties['status'] == '200'

# Create an rtc in the room.
response = conn.make_request 'rtc.create', to: conference, payload: {
  room_id: response['id']
}

assert response.properties['status'] == '200'

# Connect to the rtc.
conn.make_request 'rtc.connect', to: conference, payload: {
  id: response['id']
}

assert response.properties['status'] == '200'
