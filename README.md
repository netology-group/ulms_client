# Ruby DSL for ULMS interactions with MQTT

The DSL is useful for development, testing and debugging by enabling quickly writing MQTT
interaction scenarios.

Advantages over `mosquitto`:

1. Less boilerplate. Actually while providing all the options to `mosquitto` I can easily forget
   what I actually want to do with it. This is damn slow.
2. Ruby is much more nice to read and edit than bash.
3. Request chains are possible. With `mosquitto` you have to open two terminals and copy-paste
   ids from one to another manually which is wild and tedious especially when you have to do it
   many times while debugging.
4. Single connection for pub/sub. With `mosquitto` you have two separate connections with different
   agent labels so it's impossible to deal with unicasts.
5. Multiple publishes in a single session are possible which is necessary for certain cases.

## Usage

Install:

```bash
gem install ulms_client
```

Require the DSL to your script:

```ruby
require 'ulms_client'
```

See examples and documentation in `lib/ulms_client.rb` for available methods.

