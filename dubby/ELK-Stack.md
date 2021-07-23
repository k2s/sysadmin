On 07-22-2021 we wanted to try pushing our mailserver-logs to an elasticsearch and visualising with kibana, which are modern DevOps-Tools for Monitoring.
We used this [guide](https://techviewleo.com/install-elastic-stack-7-elk-on-debian/)

#### Let's update
```
$ sudo apt upgrade
$ sudo apt full-upgrade
$ sudo reboot now
```
Install OpenJDK 11
```
$ sudo apt install openjdk-11-jdk -y
$ java --version
```
Add Elasticsearch apt repo
```
$ wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
$ sudo apt install apt-transport-https
$ echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-7.x.list
```
Install Elasticsearch. For me it was 7.13.4
```
$ sudo apt update
$ sudo apt install elasticsearch
```
We could edit elasticsearch settings in `/etc/elasticsearch/elasticsearch.yml`, but for us the default will do. elasticsearch will listen on localhost:9200.

Now let's edit the JVM Heap allocation settings. I've set it to 1024m on the 2G VM that the dubby-test-system is currently running on. Note: 1024 bricked the VM for me. You should use less!
`/etc/elasticsearch/jvm.options.d/heapsizelimit`
```
-Xms512m
-Xmx512m
```
Then, let's start the elasticsearch service.
```
$ sudo systemctl enable --now elasticsearch
```
Now let's install kibana
```
$ sudo apt install kibana
```
Here you can edit kibanas settings
`/etc/kibana/kibana.yml`
```                                                                                                                                 
server.port: 5601
                                                                                                                            
server.host:"localhost"

elasticsearch.hosts: ["http://localhost:9200"]
```
```
$ sudo systemctl status kibana
```
