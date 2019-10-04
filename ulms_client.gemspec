Gem::Specification.new do |s|
  s.name = 'ulms_client'
  s.version = "0.1.1"
  s.date = '2019-10-04'
  s.summary = 'DSL for writing ULMS interaction scenarios'
  s.authors = ['Timofey Martynov']
  s.email = 't.martynov@talenttech.ru'
  s.files = ["lib/ulms_client.rb"]
  s.homepage = 'https://rubygems.org/gems/ulms_client'
  s.license = 'MIT'
  s.add_runtime_dependency 'mqtt', '~> 0.5'
end

