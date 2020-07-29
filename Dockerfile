FROM     ubuntu:18.04

# ---------------- #
#   Installation   #
# ---------------- #

ENV DEBIAN_FRONTEND noninteractive

# Install all prerequisites
RUN     apt-get -y update &&\ 
	apt-get -y install software-properties-common python-django-tagging python-simplejson \
	python-memcache python-ldap python-cairo python-pysqlite2 python-pip \
	gunicorn supervisor nginx-light git wget curl openjdk-8-jre build-essential python-dev libffi-dev python3 python3-pip graphite-web graphite-carbon python-whisper 

RUN     pip install --upgrade pip
RUN     pip install Twisted==19.10.0
RUN     pip install pytz

RUN	curl -sL https://deb.nodesource.com/setup_6.x | bash -
RUN	apt install -y nodejs
RUN     apt install -y npm
RUN	npm install -g wizzy

# Checkout the stable branches of Graphite, Carbon and Whisper and install from there
RUN     mkdir /src
RUN     git clone https://github.com/graphite-project/whisper.git /src/whisper            &&\
        cd /src/whisper                                                                   &&\
        git checkout 1.1.x                                                                &&\
        python3 setup.py install

RUN     git clone https://github.com/graphite-project/carbon.git /src/carbon              &&\
        cd /src/carbon                                                                    &&\
        git checkout 1.1.x                                                                &&\
        python3 setup.py install


RUN     git clone https://github.com/graphite-project/graphite-web.git /src/graphite-web  &&\
        cd /src/graphite-web                                                              &&\
        git checkout 1.1.x                                                                &&\
        python3 setup.py install                                                           &&\
        pip3 install -r requirements.txt                                                   &&\
        python3 check-dependencies.py

# Install StatsD
RUN     git clone https://github.com/etsy/statsd.git /src/statsd                          &&\
        cd /src/statsd                                                                    &&\
        git checkout v0.8.6

# Install Grafana
RUN     mkdir /src/grafana                                                                                    &&\
        mkdir /opt/grafana                                                                                    &&\
        wget https://dl.grafana.com/oss/release/grafana-7.1.1.linux-amd64.tar.gz -O /src/grafana.tar.gz &&\
        tar -xzf /src/grafana.tar.gz -C /opt/grafana --strip-components=1                                     &&\
        rm /src/grafana.tar.gz

#Install Java 11 (logstash)
RUN     apt-get -y install openjdk-11-jdk

# Install logstash
RUN     wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -                                              &&\
        apt-get install apt-transport-https                                                                    &&\
        echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | tee -a /etc/apt/sources.list.d/elastic-7.x.list     &&\
        apt-get update                                                                                         &&\
        apt-get install logstash

#install logstash statsd plugin
RUN     /usr/share/logstash/bin/logstash-plugin install logstash-output-statsd


# Install ES
#ENV PATH=$PATH:/usr/share/elasticsearch/bin
#RUN wget -qO - http://packages.elasticsearch.org/GPG-KEY-elasticsearch | apt-key add - && \
#    echo 'deb https://artifacts.elastic.co/packages/5.x/apt stable main' \
#      | tee -a /etc/apt/sources.list.d/elastic-5.x.list && \
#    apt-get update && \
#    apt-get install elasticsearch

#apt-get install --no-install-recommends -y elasticsearch

# Install metricbeat
RUN     curl -L -O https://artifacts.elastic.co/downloads/beats/metricbeat/metricbeat-7.5.1-amd64.deb       &&\
        dpkg -i metricbeat-7.5.1-amd64.deb

# Install hearthbeat
RUN     curl -L -O https://artifacts.elastic.co/downloads/beats/heartbeat/heartbeat-7.5.1-amd64.deb       &&\
        dpkg -i heartbeat-7.5.1-amd64.deb                                                               

# ----------------- #
#   Configuration   #
# ----------------- #

# Configure StatsD
ADD     ./statsd/config.js /src/statsd/config.js

# Configure Whisper, Carbon and Graphite-Web
ADD     ./graphite/initial_data.json /opt/graphite/webapp/graphite/initial_data.json
ADD     ./graphite/local_settings.py /opt/graphite/webapp/graphite/local_settings.py
ADD     ./graphite/carbon.conf /opt/graphite/conf/carbon.conf
ADD     ./graphite/storage-schemas.conf /opt/graphite/conf/storage-schemas.conf
ADD     ./graphite/storage-aggregation.conf /opt/graphite/conf/storage-aggregation.conf
RUN     mkdir -p /opt/graphite/storage/whisper
RUN     touch /opt/graphite/storage/graphite.db /opt/graphite/storage/index
RUN     chown -R www-data /opt/graphite/storage
RUN     chmod 0775 /opt/graphite/storage /opt/graphite/storage/whisper
RUN     chmod 0664 /opt/graphite/storage/graphite.db
RUN     cp /src/graphite-web/webapp/manage.py /opt/graphite/webapp
RUN     cd /opt/graphite/webapp/ && python manage.py migrate --noinput

# Configure Grafana and wizzy
ADD     ./grafana/custom.ini /opt/grafana/conf/custom.ini
RUN	cd /src && wizzy init 										&&\
	extract() { cat /opt/grafana/conf/custom.ini | grep $1 | awk '{print $NF}'; }			&&\
	wizzy set grafana url $(extract ";protocol")://$(extract ";domain"):$(extract ";http_port")	&&\		
	wizzy set grafana username $(extract ";admin_user")						&&\
	wizzy set grafana password $(extract ";admin_password")
# Add the default datasource and dashboards
RUN 	mkdir /src/datasources
ADD	./grafana/datasources/* /src/datasources
RUN     mkdir /src/dashboards
ADD     ./grafana/dashboards/* /src/dashboards/
ADD     ./grafana/export-datasources-and-dashboards.sh /src/

# Configure nginx and supervisord
ADD     ./nginx/nginx.conf /etc/nginx/nginx.conf
ADD     ./supervisord.conf /etc/supervisor/supervisord.conf

# Configure metricbeat
ADD     ./conf/metricbeats.yml /etc/metricbeat/metricbeat.yml

# Configure heartbeat
ADD     ./conf/heartbeat.yml /etc/heartbeat/heartbeat.yml

# Configure collectD
ADD     ./conf/collectd.conf /etc/collectd/collectd.conf

# Configure logstash
ADD     ./conf/logstash.conf /etc/logstash/logstash.conf 

ADD     ./entrypoint.sh /entrypoint.sh 

#Configure ES
#RUN     chown -R elasticsearch:elasticsearch /usr/share/elasticsearch/bin/
#COPY    ./conf/esconfig /usr/share/elasticsearch/config
#RUN     chown -R elasticsearch:elasticsearch /usr/share/elasticsearch/config
#RUN     mkdir /usr/share/elasticsearch/logs
#RUN     chown -R elasticsearch:elasticsearch /usr/share/elasticsearch/logs
#RUN     mkdir /usr/share/elasticsearch/data
#RUN     chown -R elasticsearch:elasticsearch /usr/share/elasticsearch/data

#RUN /etc/init.d/heartbeat restart
RUN /etc/init.d/metricbeat restart
# ---------------- #
#   Expose Ports   #
# ---------------- #

# Grafana
EXPOSE  80

# StatsD UDP port
EXPOSE  8124/udp

# StatsD Management port
EXPOSE  8126

# Graphite web port
EXPOSE 81

# ES port
EXPOSE 9300
EXPOSE 9200

# -------- #
#   Run!   #
# -------- #

#CMD     ["/usr/bin/supervisord"]
ENTRYPOINT ["sh", "/entrypoint.sh"]
