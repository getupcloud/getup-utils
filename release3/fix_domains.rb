#!/usr/bin/env oo-ruby



#require '/var/www/openshift/broker/config/environment'
require 'rubygems'
require 'moped'


session = Moped::Session.new([ "localhost:27017"])
session.use "openshift"
session.login("openshift", "moo")
users = session[:cloud_users]
domains = session[:domains]



users.find.each do |u|
	login = u['login']
	id = u['_id']

	dom = domains.find(owner_id: id)
	dom.map { |d| 
		if !d['members'].is_a? Array
			
			puts "Corrigindo dominio #{d['_id']}"
			session[:domains].where("_id" => d['_id']).update( "$pushAll" => { members:  [ 
				_id: id,
				_type: nil ,
				n: login,
				r: 'admin',
				f: [ [
						'owner', 'admin'
					] ],
				e: nil,
				    ]
				})

			session[:domains].where("_id" => d['_id']).update( "$unset" => { user_ids: ""} )
			session[:domains].where("_id" => d['_id']).update( "$push" => { allowed_gear_sizes: 'small' })

		else 
			puts "Dominio bom #{d['_id']}"
		end
	}
end