#!/usr/bin/env oo-ruby



#require '/var/www/openshift/broker/config/environment'
require 'rubygems'
require 'moped'


session = Moped::Session.new([ "localhost:27017"])
session.use "openshift_broker_dev"
session.login("openshift", "mooo")
users = session[:cloud_users]
domains = session[:domains]
applications = session[:applications]



users.find.each do |u|
	login = u['login']
	user_id = u['_id']

	dom = domains.find(owner_id: user_id).first

	dom_id = dom['_id']
	dom_name =   dom['namespace'] 

	apps = applications.find(domain_id: dom_id)

	apps.each do |a|

	if !a['members'].is_a? Array
		puts "Corrigindo app -  #{a['canonical_name']}"
		session[:applications].where("_id" => a['_id']).update( "$pushAll" => { members:  [ 
				_id: user_id,
				_type: nil ,
				n: login,
				r: 'admin',
				f: [ [
							'domain', 'admin'
				] ],
				e: nil,
			]
		})

		session[:applications].where("_id" => a['_id']).update( "$set" => {  owner_id: user_id })
		session[:applications].where("_id" => a['_id']).update( "$set" => {  domain_id: dom_id })
		session[:applications].where("_id" => a['_id']).update( "$set" => {  domain_namespace: dom_name })
		session[:applications].where("_id" => a['_id']).update( "$push" => {  domain_requires: [ nil ] })


		gi_id = a['group_instances'].map { |gi| gi['_id'] }
		gears = a['group_instances'].map { |gi| gi['gears'] }.flatten

		session[:applications].where("_id" => a['_id']).update( "$pushAll" => {  gears: [
				_id: gears[0]['_id'],
				app_dns: gears[0]['app_dns'],
				host_singletons: gears[0]['host_singletons'],
				name: gears[0]['name'],
				quarantined: gears[0]['quarantined'],
				server_identity: gears[0]['server_identity'],
				sparse_carts: gears[0]['sparse_carts'],
				uid: gears[0]['uid'],
				uuid: gears[0]['uuid'],
				group_instance_id: gi_id[0]
			] 
		})


		session[:applications].where("_id" => a['_id']).update( "$unset" => { group_instances: [ gears: 1] } )
		session[:applications].where("_id" => a['_id']).update( "$push" => { group_instances: { _id: gi_id[0]} } )

		else 
			puts "App bom #{a['canonical_name']}"

		end
	end
end