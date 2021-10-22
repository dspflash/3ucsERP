bomimport 
material not empty
	import uom if not exsist in sys
	import material item if not exist in sys,recvsubinv default 1 if empty
product not empty
	import uom if not exsist in sys
	import product item if not exist in sys,recvsubinv default 1 if empty
	create bom_routing_header if not exist
	bom operation not empty
		import bom operation if operation and not exist in sys
		department not empty 
		import bom department if not exist in sys
		create bom_routing_line if not exist
	material not null
		create bom header if not exist
		create bom line if not exist
	
