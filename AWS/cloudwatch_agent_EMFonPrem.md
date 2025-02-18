Add these configs in the location: /opt/aws/amazon-cloudwatch-agent/etc
```bash
==> amazon-cloudwatch-agent.toml <==
[agent]
  collection_jitter = "0s"
  debug = true
  flush_interval = "1s"
  flush_jitter = "0s"
  hostname = ""
  interval = "60s"
  #logfile = "/opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log"
  logtarget = "lumberjack"
  metric_batch_size = 1000
  metric_buffer_limit = 10000
  omit_hostname = false
  precision = ""
  quiet = false
  round_interval = false
  run_as_user = "lopa"

[outputs]

  [[outputs.cloudwatchlogs]]
    force_flush_interval = "5s"
    log_stream_name = "lopa-wsl"
    mode = "OP"
    region = "us-east-1"
    profile = "admin"
    region_type = "CM"
    shared_credential_file = "/home/lopa/.aws/credentials"

==> common-config.toml <==
# This common-config is used to configure items used for both ssm and cloudwatch access


## Configuration for shared credential.
## Default credential strategy will be used if it is absent here:
## 	Instance role is used for EC2 case by default.
##	AmazonCloudWatchAgent profile is used for onPremise case by default.
# [credentials]
#    shared_credential_profile = "{profile_name}"
#    shared_credential_file = "{file_name}"


## Configuration for proxy.
## System-wide environment-variable will be read if it is absent here.
## i.e. HTTP_PROXY/http_proxy; HTTPS_PROXY/https_proxy; NO_PROXY/no_proxy
## Note: system-wide environment-variable is not accessible when using ssm run-command.
## Absent in both here and environment-variable means no proxy will be used.
# [proxy]
#    http_proxy = "{http_url}"
#    https_proxy = "{https_url}"
#    no_proxy = "{domain}"

# [ssl]
#    ca_bundle_path = "{ca_bundle_file_path}"

#
# [imds]
#    imds_retries = 1

==> amazon-cloudwatch-agent.yaml <==
exporters:
    awscloudwatchlogs/emf_logs:
        certificate_file_path: ""
        emf_only: true
        endpoint: ""
        imds_retries: 1
        local_mode: false
        log_group_name: emf/logs/default
        log_retention: 0
        log_stream_name: lopa-wsl
        max_retries: 2
        middleware: agenthealth/logs
        no_verify_ssl: false
        num_workers: 8
        profile: ""
        proxy_address: ""
        raw_log: true
        region: us-east-1
        request_timeout_seconds: 30
        resource_arn: ""
        retry_on_failure:
            enabled: true
            initial_interval: 5s
            max_elapsed_time: 5m0s
            max_interval: 30s
            multiplier: 1.5
            randomization_factor: 0.5
        role_arn: ""
        sending_queue:
            enabled: true
            num_consumers: 1
            queue_size: 1000
extensions:
    agenthealth/logs:
        is_usage_data_enabled: true
        stats:
            operations:
                - PutLogEvents
            usage_flags:
                mode: OP
                region_type: CM
    agenthealth/statuscode:
        is_status_code_enabled: true
        is_usage_data_enabled: true
        stats:
            usage_flags:
                mode: OP
                region_type: CM
    entitystore:
        mode: OP
        region: us-east-1
processors:
    batch/emf_logs:
        metadata_cardinality_limit: 1000
        send_batch_max_size: 0
        send_batch_size: 8192
        timeout: 5s
receivers:
    tcplog/emf_logs:
        encoding: utf-8
        id: tcp_input
        listen_address: 0.0.0.0:25888
        operators: []
        retry_on_failure:
            enabled: false
            initial_interval: 0s
            max_elapsed_time: 0s
            max_interval: 0s
        type: tcp_input
    udplog/emf_logs:
        encoding: utf-8
        id: udp_input
        listen_address: 0.0.0.0:25888
        multiline:
            line_end_pattern: .^
            line_start_pattern: ""
            omit_pattern: false
        operators: []
        retry_on_failure:
            enabled: false
            initial_interval: 0s
            max_elapsed_time: 0s
            max_interval: 0s
        type: udp_input
service:
    extensions:
        - agenthealth/logs
        - agenthealth/statuscode
        - entitystore
    pipelines:
        logs/emf_logs:
            exporters:
                - awscloudwatchlogs/emf_logs
            processors:
                - batch/emf_logs
            receivers:
                - tcplog/emf_logs
                - udplog/emf_logs
    telemetry:
        logs:
            development: false
            disable_caller: false
            disable_stacktrace: false
            encoding: console
            level: info
            sampling:
                enabled: true
                initial: 2
                thereafter: 500
                tick: 10s
        metrics:
            address: ""
            level: None
        traces: {}

==> env-config.json <==
{}
==> amazon-cloudwatch-agent.d/file_a.json <==
{
  "logs": {
    "metrics_collected": {
      "emf": { }
    }
  }
}
```

```bash
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent -config /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.toml -envconfig /opt/aws/amazon-cloudwatch-agent/etc/env-config.json -otelconfig /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.yaml -pidfile /opt/aws/amazon-cloudwatch-agent/var/amazon-cloudwatch-agent.pid
```

test
```bash
echo '{"_aws":{"Timestamp":1739876381783,"CloudWatchMetrics":[{"Namespace":"lopaAuditMetrics","Metrics":[{"Name":"lopaRequestCount","Unit":"Count"}],"Dimensions":[["LogGroup","ServiceName","ServiceType","lopaTenant"]]}],"LogGroupName":"AuditMetricsExploration-metrics"},"lopaRequestCount":1.0,"LogGroup":"AuditMetricsExploration-metrics","ServiceName":"AuditMetricsExploration","ServiceType":"auditservicemetrics","lopaTenant":"IAM"}' > dev/udp/127.0.0.1/25888
```
