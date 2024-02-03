#Instllation
```script
pacman -S rabbitmq
sudo rabbitmq-plugins enable rabbitmq_mqtt
sudo rabbitmq-plugins enable rabbitmq_management
sudo systemctl start rabbitmq
sudo rabbitmqctl add_user awcator dev
sudo rabbitmqctl set_user_tags awcator administrator
sudo rabbitmqctl set_permissions -p / awcator ".*" ".*" ".*"
# rabbitmqctl change_password <USERNAME> <NEWPASSWORD>
```
