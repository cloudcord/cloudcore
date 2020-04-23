# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# INTERNAL KUBERNETES STATSD ENDPOINT: 10.59.254.231

config :statix, 
  prefix: "",
  host: "10.59.254.231",
  port: 8125

config :instruments, 
  reporter_module: Instruments.Statix,
  fast_counter_report_interval: 2_000,
  probe_prefix: "probes",
  statsd_port: 8125

config :discord_gateway_gs,
  redis_host: "localhost",
  internal_api: "http://localhost:8888"