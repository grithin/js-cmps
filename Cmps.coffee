###

Methodologies:
-	A component can have singleton dependencies, which tend to be wrappers
-	When a component is destroyed, a debounce is used so that, if another component is created requiring some of the same dependecies, the dependencies are not needlessly destroyed

@TODO	cmp.destroy allowed to return promise, in which case, will wait for it
@TODO	no-debug version (clear `c` calls)
@TODO	write examples
###

window.Cmps =
	all: {} # dictionary of all component types, by name of component
	dependencies: {} # { name: < instance >, ... }
	loaded: {} # { name: < instance >, name: [< instance >, ...] }
	cache: {} # conveniences obj for Cmps to place re-usable instances of theselves
	log: console.log.bind(console)
	#	name: instance # for single instance Cmps that have significant construct costs, and perfer to partially-destroy, and reuse data on re-construction


# create Cmp if instance does not exist
Cmps.singleton = (name, options)->
	if !_.isString name
		throw new Error('Component name must be a string')
	if !@loaded[name]
		@loaded[name] = new @all[name](name, options)
		@loaded[name].state.trigger 'loaded', (new Date) # tell the component it was loaded
	@loaded[name]
# Type 1: not-dependency
Cmps.add_loaded = (instance)->
	if @loaded[instance.name]
		@loaded[instance.name].push instance
	else
		@loaded[instance.name] = [instance]
# Type 2: dependency
Cmps.require = (name, dependent, options)->
	if !@all[name]
		throw new Error('Unknown component dependency: "'+name+'"')

	if @dependencies[name]
		Cmps.log 'Cmps: dependency preloaded: '+name
		@dependencies[name].dependents.push dependent
		# @TODO remake this to use .state.on('change:reloaded')
		@dependencies[name].update('require', options) # tell the component it was re-required
	else
		Cmps.log 'Cmps: dependency loading: '+name
		@dependencies[name] = new @all[name](name, options)
		@dependencies[name].dependents = [dependent]
		@dependencies[name].state.trigger 'loaded', (new Date) # tell the component it was loaded
	@dependencies[name]
# remove self from loaded, and from dependents
Cmps.remove_loaded = (instance)->
	if _.isArray @loaded[instance.name]
		@loaded[instance.name] = @loaded[instance.name].filter (o)->
			o != instance
	else
		delete @loaded[instance.name]
	for name, o of @dependencies
		if o.dependents
			o.dependents = o.dependents.filter (o)->
				o != instance
# remove Cmps with empty dependents list
Cmps.gc = ()->
	for name, o of @dependencies
		if o.dependents && !o.dependents.length
			delete @dependencies[name]
			o.destroy()
# debounced garbage collecter
Cmps.dgc = _.debounce Cmps.gc.bind(Cmps), 100

# a primary singleton component serving as a page (the current page will be swapped out with the new page)
Cmps.page = scoped {current:false}, (name, args)->
	if @current
		@current.destroy()
	@current = Cmps.singleton.apply Cmps, arguments


###
Standard Attributes
-	name: the name of the component
-	state: if a component is stateful and that statefulness is potentially used by something external, store the state here
-	data: location to put the data, normally as a backbone collection or model
-	events: array of events that should be attached when the component is created and detached when destroyed
	-	see code for details
-	$el: a single jquery element representing the component, which will be destroyed when the components is destroyed
-	$els: an array of jquery elements representing the component, which will be destroyed when the components is destroyed
	-	for named els:
	```
	@els = $nav: $('...')
	@$els.push @els.$nav
	```

Events
-	When loaded, `state` gets a "loaded" event, with the time
-	When destroyed, `state` gets a 'destroyed' event, with the time
-	When re-required as singleton, `update` method is called on the component with parameter `'require'`
-	When the component is updated, it should emit a 'update' event on the `@state`
###

window.Cmp = (name)->
	if !_.isString name
		throw new Error('Component name must be a string')
	@name = name
	if !@state
		@state = new (Backbone.Model.extend())

	if !@data
		@createData()

	if !@$els # component may have multiple elements
		@$els = []

	if !@events
		@events = []
	###
	@events = [
		{ name: 'click', target: $(), fn: (()->)	} # basic bubble event
		{ name: 'click', target: $(), selecter: '', fn: (()->)	} # delegation with selecter
		{ name: 'click', target: $(), fn: (()->), type:'capture'	} # capture event
	]
	###
Cmp::require = (name, options)->
	Cmps.require(name, @, options)
# Add/attach events
Cmp::construct = ()->
	if @events.length
		@attachEvents()
	Cmps.add_loaded(@)
Cmp::attachEvents = (events)->
	events = events || @events
	for event in events
		if event.type == 'capture'
			$(event.target).get(0).addEventListener(event.name, event.fn, true) # last argument indicates to capture
		else if event.selecter
			$(event.target).on(event.name, event.selecter, event.fn)
		else
			$(event.target).on(event.name, event.fn)
Cmp::detachEvents = (events)->
	events = events || @events
	for event in events
		if event.type == 'capture'
			$(event.target).get(0).removeEventListener(event.name, event.fn, true) # last argument indicates to capture
		else if event.selecter
			$(event.target).off(event.name, event.selecter, event.fn)
		else
			$(event.target).off(event.name, event.fn)
# Like with react, the notion is, when the data changes, there is a render update.   Consequently, the Cmp @data is a backbone model, which, when updated, calls the cmp update method
Cmp::createData = (data={})->
	if _.isArray(data)
		@data = new (Backbone.Collection.extend())(data)
	else
		@data = new (Backbone.Model.extend())(data)
	@data.on 'remove change add', _.partial @update.bind(@), 'data' # call `update` with a '"data"' parameter when changed
###
-	remove the primary element
-	remove events
###
Cmp::destroy = ()->
	Cmps.log 'Cmp: destroying: '+@name
	if @$el
		@$el.remove()
	for $element in @$els
		$element.remove()
	if @events
		@detachEvents()
	Cmps.remove_loaded(@)
	Cmps.dgc()
	@state.trigger('destroyed', new Date)
Cmp::createClass = (name, constructor)->
	# wrap to run final @construct()
	wrapped_constructor = ()->
		Cmps.log 'Cmp: constructing: '+name
		applied = constructor.call(@, arguments[1]) # the 2nd param is the options param.
		@construct()
		applied

	Cmps.all[name] = inherited Cmp, wrapped_constructor
	Cmps.all[name]::name = name
	Cmps.all[name]
# @param	context	< the context for which update is called.  "data", for data change, "require", for when Cmp is required. >
Cmp::update = ((context)-> c 'Cmp: updating: '+ @name)
Cmp::el_wrap = (html)->
	$wrap = $('<div class="cmp_content">')
	classable_name = @name.replace(/[^a-z0-9_]/gi,'_')
	$wrap.addClass(classable_name)
	$wrap.append(html)

#++ site specific {

Cmp::el_attached_wrap = (html)->
	@$el = @el_wrap(html)
	$('#pc').append @$el
	@$el

#++ }