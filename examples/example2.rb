# This is an example of talking to janus-conference.
# It can't use svc-agent because of Janus Gateway's architecture so the protocol is quite different.
# Because of that we can't use `make_request` but have to call raw `publish` and `subscribe`.
# Before making the actual request Janus requires use to create a session and a plugin handle
# in order to save the state between requests and route messages to plugins.

require 'ulms_client'

rtc_id = '00716b55-8cbf-412b-96df-199c171b1d33'

audience = 'dev.svc.example.org'
conference = agent("alpha", account('conference', audience))
janus = agent("alpha", account('janus-gateway', audience))
janus_inbox = "agents/#{janus}/api/v1/in/#{conference.account}"

conn = connect host: 'localhost', port: 1883, mode: 'service', agent: conference
conn.subscribe "apps/#{janus.account}/api/v1/responses"

# Get session.
conn.publish janus_inbox, payload: { janus: 'create', transaction: 'txn-session' }
response = conn.receive { |msg| msg['transaction'] == 'txn-session' }
assert response['janus'] == 'success'
session_id = response['data']['id']

# Get handle.
conn.publish janus_inbox, payload: {
  janus: 'attach',
  session_id: session_id,
  plugin: 'janus.plugin.conference',
  transaction: 'txn-handle'
}

response = conn.receive { |msg| msg['transaction'] == 'txn-handle' }
assert response['janus'] == 'success'
handle_id = response['data']['id']

# Make `stream.upload` request.
conn.publish janus_inbox, payload: {
  janus: 'message',
  session_id: session_id,
  handle_id: handle_id,
  transaction: 'txn-upload',
  body: {
    method: 'stream.upload',
    id: rtc_id,
    bucket: "origin.webinar.#{audience}",
    object: "#{rtc_id}.source.mp4"
  }
}

response = conn.receive { |msg| msg['transaction'] == 'txn-upload' }
assert response['janus'] == 'ack'

response = conn.receive(30) { |msg| msg['transaction'] == 'txn-upload' }
assert response['janus'] == 'event'
assert response['plugindata']['data']['status'] == '200'
