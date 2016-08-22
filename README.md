# Purpose
**Note**: For the daring only

I wanted something just a little bit more than Backbone views, but without the rigid structure of Marionette.  I wanted components which could declare parents/wrappers/dependencies.  



# Example
```coffee
# Create a wrapper
standard: ()->
	@$el = $(Template['layout/standard.html']())
	$('body').append @$el

# Create a wrapper that uses another wrapper
Cmp::createClass 'site_standard', ()->
	@require('standard')

	$shadow = $('<div id="h1_shadow"></div>')
	$('#h1').after($shadow)
	@$els.push $shadow

	$links = $(Template['component/header.html']())
	$('#h1').append $links
	@$els.push $links

# Create a wrapper that uses another wrapper
Cmp::createClass 'site_user_standard', ()->
	@require('site_standard')
	@$els.push @$nav = $(Template['side_nav.html']())
	$('#n1 .nav_list').append @$nav


# Create what will be a page
Cmp::createClass 'about', ()->
	@require('site_standard')
	@el_attached_wrap Template['site/about.html']()

# instantiate a singleton exclusive component
Cmps.page('about')
```