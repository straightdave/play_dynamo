import Config

config :ex_aws,
  debug_requests: false,
  access_key_id: "abcd",
  secret_access_key: "1234",
  region: "us-east-1"

config :ex_aws, :dynamodb,
  scheme: "http://",
  host: "192.168.99.102",
  port: 8000,
  region: "us-east-1"
