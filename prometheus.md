# Prometheus Installation & Configration 
### Installation
```diff
pacman -S prometheus
prometheus --version
# prometheus, version 2.38.0 (branch: tarball, revision: 2.38.0)
# build user:       someone@builder
# build date:       20220817-07:08:26
# go version:       go1.19
# platform:         linux/amd64

#config at  /etc/prometheus/prometheus.yml
systemctl start prometheus.service
systemctl enable prometheus.service
systemctl status prometheus.service

#more about the version can we found at http://awcator:9090/status
#metrics at http://awcator:9090/metrics

- Alternatively, you can download it from 
PROMETHEUS_VERSION="2.2.1"
wget https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
tar -xzvf prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
cd prometheus-${PROMETHEUS_VERSION}.linux-amd64/
# if you just want to start prometheus as root
#./prometheus --config.file=prometheus.yml
# create user
useradd --no-create-home --shell /bin/false prometheus 

# create directories
mkdir -p /etc/prometheus
mkdir -p /var/lib/prometheus

# set ownership
chown prometheus:prometheus /etc/prometheus
chown prometheus:prometheus /var/lib/prometheus

# copy binaries
cp prometheus /usr/local/bin/
cp promtool /usr/local/bin/

chown prometheus:prometheus /usr/local/bin/prometheus
chown prometheus:prometheus /usr/local/bin/promtool

# setup systemd
echo '[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target
[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
    --config.file /etc/prometheus/prometheus.yml \
    --storage.tsdb.path /var/lib/prometheus/ \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries
[Install]
WantedBy=multi-user.target' > /etc/systemd/system/prometheus.service

systemctl daemon-reload
systemctl enable prometheus
systemctl start prometheus
```

### Nodeexporter Congfig 
```diff
pacman -S extra/prometheus-node-exporter #prometheus-node-exporter-1.3.1-2
systemctl start prometheus-node-exporter.service  #Runs at 9100 port
systemctl status prometheus-node-exporter.service
#metrics at http://awcator:9100/metrics

! Add new configs under scrape_configs in /etc/prometheus/prometheus.yml
  - job_name: 'awcator_node_exporter'
    scrape_interval: 5s
    static_configs:
      - targets: ['awcator:9100']

#targets can be found at http://awcator:9090/targets?search=
systemctl restart prometheus
#use node_memory_MemFree_bytes to view free space memoery
```
### Alerts config
```diff
#install alert manger extra/alertmanager0.24.0
pacman -S extra/alertmanager
systemctl start alertmanager.service
systemctl enable alertmanager.service
systemctl status alertmanager.service

#runs at port :9093
Add the following lines and substitute with correct values to /etc/alertmanager/alertmanager.yml:

global:
  smtp_smarthost: 'localhost:25'
  smtp_from: 'alertmanager@prometheus.com'
  smtp_auth_username: ''
  smtp_auth_password: ''
  smtp_require_tls: false
templates:
- '/etc/alertmanager/template/*.tmpl'
route:
  repeat_interval: 1h
  receiver: operations-team
receivers:
- name: 'operations-team'
  email_configs:
  - to: 'operations-team+alerts@example.org'
  slack_configs:
  - api_url: https://hooks.slack.com/services/XXXXXX/XXXXXX/XXXXXX
    channel: '#prometheus-course'
    send_resolved: true
  
  
#end of config
This formula/Prometheus expression: CPU usage  gives 100-irate(node_cpu_seconds_total{job="awcator_node_exporter",mode="idle"}[5m])*100
we will check if this croess abov 90% to report alert

! create a rule file called awcator_rules.yml with contetnt

groups:    
- name: example    
  rules:    
  - alert: cpuUsage              
    expr: 100-irate(node_cpu_seconds_total{job="awcator_node_exporter",mode="idle"}[5m])*100 > 90    
    for: 1m     
    labels:    
      severity: critical    
    annotations:    
      summary: Muklari usage CPU  
      
sudo chown prometheus:prometheus awcator_rules.yml 
systemctl restart prometheus
visit to confirm alerts are added : http://awcator:9090/alerts?search=

Refer configs/etc/prometheus/ for configs
```
