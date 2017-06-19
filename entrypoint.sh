# Create log dirs and files
mkdir -p $( dirname $(cat /etc/supervisor/supervisord.conf  | grep logfile= | grep "\.log" | sed s/.*logfile=// ) )
touch $( cat /etc/supervisor/supervisord.conf  | grep logfile= | grep "\.log" | sed s/.*logfile=// )
mkdir /var/log/supervisor
touch /var/log/supervisor/nginx.log
touch /var/log/supervisor/nginx_error.log
touch /var/log/supervisor/carbon-cache.log
touch /var/log/supervisor/grafana-webapp.log
touch /var/log/supervisor/graphite-webapp.log
touch /var/log/supervisor/statsd.log
touch /var/log/supervisor/dashboard-loader.log
touch /var/log/supervisor/set-local-graphite-source.log
touch /var/log/supervisor/metricbeat.log
touch /var/log/supervisor/logstash.log

# Then run supervisord
/usr/bin/supervisord
