# Prometheus Installation & Configration 
## !contents
* Installation
* NodeExporter Config
* ALertManger Config
* Mutal SSLconnectivity 
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

Add following lines to connect your promethus to external alertmanger in /etc/prmoetheus/promethus.yaml

# Alertmanager configuration
alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - awcator:9093
          # - alertmanager:9093


sudo chown prometheus:prometheus awcator_rules.yml 
systemctl restart prometheus
visit to confirm alerts are added : http://awcator:9090/alerts?search=

To stress the CPU run 
yes > /dev/null & 

#^run the Number of CPU times
#Example, if you have 4 CPU then do 4 times untill it trigger alert
#TO revert back,
killall yes
Refer configs/etc/prometheus/ for configs
```
## Mutal SSLconnectivity between NON SSL premethus and non ssl NodeExportyer
follow [Client Cert Auth](https://github.com/awcator/DevOpsJourneyWithArchLinux/blob/master/ngnix.md#client-certificate-autherization)
Once generated all keypairs and certificates for CA/Server/& CLient, follow this
```
cp ca.crt /etc/ssl/certs/prometheus-ca.crt
cp ca.key /etc/ssl/private/prometheus-ca.key
cp client.key /etc/prometheus/prometheus.key
chown prometheus:prometheus /etc/prometheus/prometheus.key
cp client.crt /etc/ssl/certs/prometheus.crt

Add the following lines to /etc/prometheus/prometheus.yml:
 - job_name: 'ssl_awcator_node_exporter'
    scrape_interval: 5s
    scheme: https
    tls_config:
      ca_file: /etc/ssl/certs/prometheus-ca.crt
      cert_file: /etc/ssl/certs/prometheus.crt
      key_file: /etc/prometheus/prometheus.key
    static_configs:
      - targets: ['awcator:8000']
      
! FOR SANs insted of CN
generate server certifcates as follows
Create OpenSSL conf file as follows and name it a.conf

# From http://apetec.com/support/GenerateSAN-CSR.htm
# Also,  https://stackoverflow.com/a/65711669

[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
[req_distinguished_name]
countryName = Country Name (2 letter code)
countryName_default = IN
stateOrProvinceName = Karnataka
stateOrProvinceName_default = MN
localityName = Bangalore
localityName_default = Bangalore
organizationalUnitName	= Organizational Unit Name (eg, section)
organizationalUnitName_default	= Domain Control Validated
commonName = Internet Widgits Ltd
commonName_max	= 64
[ v3_req ]
# Extensions to add to a certificate request
basicConstraints = CA:FALSE
extendedKeyUsage = clientAuth,serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1        = awcator
DNS.2        = bwcator
DNS.3        = cwcator
DNS.4        = ftp.awcator.com



openssl x509 -req -days 365 -sha256 -in target.csr -CA ca.crt -CAkey ca.key -set_serial 1 -out target.crt -extensions v3_req -extfile a.conf

```
