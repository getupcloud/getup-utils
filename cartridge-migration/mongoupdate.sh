#!/bin/bash

#mongo update

mongo $1 <<EOF

db.applications.update(
{ 
	"group_overrides.components.comp":"nodejs-0.6" 
},{
	$set: { 
		"group_overrides.$.components.0.comp": "nodejs-0.10",
		"group_overrides.$.components.0.cart": "nodejs-0.10",
		"component_instances.$.cartridge_name": "nodejs-0.10",
		"component_instances.$.component_name": "nodejs-0.10" 
	}
},{
	multi: true
});
EOF