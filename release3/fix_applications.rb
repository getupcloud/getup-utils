#!/usr/bin/env oo-ruby



#require '/var/www/openshift/broker/config/environment'
require 'rubygems'
require 'moped'
require 'net/ssh'
require 'securerandom'

session = Moped::Session.new([ "localhost:27017"])
session.use "openshift_broker_dev"
session.login("openshift", "mooo")
users = session[:cloud_users]
domains = session[:domains]
applications = session[:applications]

def get_git(host, gear_uuid, cartridge_name, database = false)

gears_base = "/var/lib/openshift"

if database
	cmd = { "external_port" => "cat #{gears_base}/#{gear_uuid}/.env/OPENSHIFT_#{cartridge_name}_DB_PROXY_PORT",
		"internal_port" => "cat #{gears_base}/#{gear_uuid}/.env/OPENSHIFT_#{cartridge_name}_DB_PORT",
		"internal_address" => "cat #{gears_base}/#{gear_uuid}/.env/OPENSHIFT_#{cartridge_name}_DB_HOST"
		} 
	else

	cmd = { "external_port" => "cat #{gears_base}/#{gear_uuid}/.env/OPENSHIFT_#{cartridge_name}_PROXY_PORT &2> /dev/null",
		"internal_port" => "cat #{gears_base}/#{gear_uuid}/.env/OPENSHIFT_#{cartridge_name}_PORT",
		"internal_address" => "cat #{gears_base}/#{gear_uuid}/.env/OPENSHIFT_#{cartridge_name}_IP"
		} 
end

res = {} 
Net::SSH.start(
  host, 'root',
  :host_key => "ssh-rsa",
  :encryption => "blowfish-cbc",
  :keys => [ "/root/.ssh/rsync_id_rsa" ],
  :compression => "zlib"
) do |session|
    cmd.each do |k,v|
			res[k] = session.exec! v
		end
	end
	return res
end


users.find.each do |u|
	
	login = u['login']
	user_id = u['_id']

	dom = domains.find(owner_id: user_id).first

	if dom
		dom_id = dom['_id']
		dom_name =   dom['namespace'] 
	else
		puts "Usuario #{login} nao possui dominio!"
		next
	end

	apps = applications.find(domain_id: dom_id)

	apps.each do |a|


		secret_token = SecureRandom.urlsafe_base64(96, false)
		#members
	
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
			session[:applications].where("_id" => a['_id']).update( "$set" => {  secret_token: secret_token })
			session[:applications].where("_id" => a['_id']).update( "$push" => {  domain_requires: [ nil ] })

		 end

		#apps
		if a['scalable']
			puts "App escalavel -  #{a['canonical_name']} --- #{a['_id']}"
			@gi_id = []
			a['group_instances'].each do |gi|
				@gi_id << { _id: gi['_id'] }
				gi['gears'].each do |ge|	
					port_interfaces = Hash.new
					aport = []
		
					carts =  a['component_instances'].find_all { |id| id['group_instance_id'] == gi['_id'] }

					if  carts[0]['cartridge_name'] =~ /mysql/ or carts[0]['cartridge_name'] =~ /postgresql/ or carts[0]['cartridge_name'] =~ /mongo/
						puts "Banco #{carts[0]['cartridge_name']}"
						pi = get_git(ge['server_identity'], ge['uuid'], carts[0]['cartridge_name'].split("-").first.upcase, true)
						port_interfaces = { 
							_id: Moped::BSON::ObjectId.new,
							cartridge_name: carts[0]['cartridge_name'],
							external_port: pi['external_port'],
							internal_port: pi['internal_port'],
							protocols: [ carts[0]['cartridge_name'].split("-").first ],
							type: [ "database" ],
							mappings: [  ],
							internal_address: pi['internal_address']
						}
						aport << port_interfaces
					else
						puts "Web + LB"
						
						map_base = { frontend: "", backend: "" }
						map_web = { frontend: "/health", backend: "" }
						map_lb = { frontend: "/health", backend: "/configuration/health" }
						carts.each do |c|

							pi = get_git(ge['server_identity'], ge['uuid'], c['cartridge_name'].split("-").first.upcase)

							if c['cartridge_name'] =~/haproxy/
								puts "Haproxy ignorando endpoints"
=begin
								type = 'load_balancer'
								mappings = []
								mappings << map_base
								mappings << map_lb
								@eport = @eport.to_i + 1						
=end
							else
								type ='web_framework'
								mappings = []
								mappings << map_base
								mappings << map_web
								@eport = pi['external_port']
							
							port_interfaces = { 
								_id: Moped::BSON::ObjectId.new,
								cartridge_name: c['cartridge_name'],
								external_port: @eport,
								internal_port: pi['internal_port'],
								protocols: [ "http" ],
								type: [ type ],
								mappings: mappings,
								internal_address: pi['internal_address']
							}
							aport << port_interfaces
							end
						end
					end
					session[:applications].where("_id" => a['_id']).update("$pushAll" => { gears: [
						_id: ge['_id'],
						app_dns: ge['app_dns'],
						group_instance_id: gi['_id'],
						host_singletons: ge['host_singletons'],
						name: ge['name'],
						port_interfaces: aport, 
						quarantined: ge['quarantined'],
						server_identity: ge['server_identity'],
						sparse_carts: ge['sparse_carts'],
						uid: ge['uid'],
						uuid: ge['uuid']
						]
					})
				end
			end
			session[:applications].where("_id" => a['_id']).update( "$unset" => { group_instances: 1 } )
			@gi_id.each do |g|
				session[:applications].where("_id" => a['_id']).update( "$push" => { group_instances: g })
			end	
		elsif !a['scalable']
			gi_id = a['group_instances'].map { |gi| gi['_id'] }
			gears = a['group_instances'].map { |gi| gi['gears'] }.flatten
			gi_id = gi_id[0]
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
					group_instance_id: gi_id
				] 
			})

			session[:applications].where("_id" => a['_id']).update( "$unset" => { group_instances: 1 } )
			session[:applications].where("_id" => a['_id']).update( "$push" => { group_instances: { _id: gi_id} } )
		end
	end
end