#!/usr/bin/env oo-ruby

require 'rubygems'
require 'getoptlong'


require "/var/www/openshift/broker/config/environment"
# Disable analytics for admin scripts
Rails.configuration.analytics[:enabled] = false

cart_version = {
"php-5.3" => '0.0.10',
"php-5.4" => '0.0.10',
"php-5.5" => '0.0.10',
"ruby-1.8" => '0.0.10',
"ruby-1.9" => '0.0.10',
"nodejs-0.10" => '0.0.8',
"python-2.6" => '0.0.8',
"python-2.7" => '0.0.8',
"python-3.3" => '0.0.8',
"jbossews-1.0" => '0.0.9',
"jbossews-2.0" => '0.0.9',
"jbossas-7" => '0.0.9',
"haproxy-1.4" => '0.0.11',
"mysql-5.1" => '0.2.6',
"mongodb-2.2" => '0.2.5',
"postgresql-8.4" => '0.3.5',
"postgresql-9.2" => '0.3.5',
"cron-1.4" => '0.0.8',
"perl-5.10" => '0.0.7',
}

Application.each do |app|
  dom = Domain.find_by( :_id =>  app.domain_id )
  user = CloudUser.find_by( :_id =>  dom.owner_id )
  app.group_instances.each do |gi|
    gi.gears.each do |g|
      acp = g.get_proxy
      args = acp.build_base_gear_args(g)
      args["--node"]=acp.id
      gi.all_component_instances.map{ |ci| ci.cartridge_name }.each do |cartridge|
        args["--cartridge"]=cartridge
#        print "./migrate #{args['--node']} -a #{args['--with-container-uuid']} -n #{args['--with-namespace']} -m #{args['--with-app-name']} -c #{args['--cartridge']} -l #{user.login} \n"
        print " \"#{args['--with-container-uuid']}\":{\"fqdn\":\"#{args['--with-container-name']}.#{args['--with-namespace']}.getup.io\",\"container_name\": \"#{args['--with-container-name']}\", \"namespace\":\"#{args['--with-namespace']}\"}\n"
      end
    end
  end
end