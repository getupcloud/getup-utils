#!/usr/bin/env oo-ruby
#!/usr/bin/env ruby

load '/usr/sbin/oo-stats'

stats = OOStats.new
result = stats.get_db_stats

apps = result[0][:apps]
gears = result[0][:gears]

system ( "source /etc/profile.d/aws-api-tools.sh ; /opt/cloudwatch/bin/mon-put-data -u Count --metric-name Applications --namespace \"Openshift\" --value #{apps}" )
system ( "source /etc/profile.d/aws-api-tools.sh ; /opt/cloudwatch/bin/mon-put-data -u Count --metric-name Gears --namespace \"Openshift\" --value #{gears}" )