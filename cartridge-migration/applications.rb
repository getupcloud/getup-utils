#!/usr/bin/env oo-ruby

require 'rubygems'
require 'getoptlong'


require "/var/www/openshift/broker/config/environment"
# Disable analytics for admin scripts
Rails.configuration.analytics[:enabled] = false

Application.each do |app|
  app.group_instances.each do |gi|
    gi.gears.each do |g|
      acp = g.get_proxy
      args = acp.build_base_gear_args(g)
      args["--node"]=acp.id
      gi.all_component_instances.map{ |ci| ci.cartridge_name }.each do |cartridge|
        args["--cartridge"]=cartridge
        print "./migrate #{args['--node']} -a #{args['--with-container-uuid']} -n #{args['--with-namespace']} -m #{args['--with-app-name']} -c #{args['--cartridge']} \n"
      end
    end
  end
end