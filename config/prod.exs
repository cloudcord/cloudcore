config :libcluster,
  topologies: [
    firehose: [
      strategy: Cluster.Strategy.Kubernetes,
      config: [
        # mode: :dns,
        kubernetes_node_basename: "discord-gateway-gs",
        kubernetes_selector: "app=discord-gateway-gs",
        polling_interval: 10_000,
      ]
    ]
  ]

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
  redis_host: "redis-master",
  internal_api: "http://internal-data-api"