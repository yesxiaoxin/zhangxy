exports = this


@lang_keys = {
	'zh_cn':{
		'Visit Site': '访问网站',
		'Logout': '登出',
		'Save Configs': '保存设置',
		'Configs are saved!': '设置已经保存了!',
		'Image Uploading, Wait...': '图片上传中, 请稍等...',
		'Image Uploaded, Done!': '图片已上传成功!'
	},
	'zh_tw':{
		'Visit Site': '訪問網站',
		'Logout': '登出',
		'Save Configs': '保存設置',
		'Configs are saved!': '設置已經保存了!',
		'Image Uploading, Wait...': '圖片上傳中，請稍等...',
		'Image Uploaded, Done!': '圖片已上傳成功!'
	}
}


user_lang = window.navigator.userLanguage or navigator.language

@lang = user_lang.toLowerCase().replace('-', '_')

@canvas_allowed = Boolean(document.createElement('canvas').getContext)


@get_text = (key, keys)->
	if lang_keys? and not keys
		keys = lang_keys
	texts = keys[lang]
	if texts
		return texts[key+'_'+lang] or texts[key] or key
	else
		return key

content_gateway = '/service/gateway/sync'
admin_data_gateway = '/admin/data'



ImageUploader = (dom) ->
	self = this
	@canvas =  document.createElement('canvas')
	@cx = @canvas.getContext('2d')

	@dom = $(dom)
	@raw_dom = $(dom)[0]
	@image_path = @dom.attr('src').split('?')[0]

	@drop_event = (event) =>
		@dom.removeClass('drag_over')
		files = event.dataTransfer.files
		url = window.URL or window.webkitURL
		objURL = url.createObjectURL or false

		for file in files
			if file.type.indexOf( 'image' ) == -1
				continue
			if objURL
				@load_image(objURL(file))
			else
				reader = new FileReader()
				reader.readAsDataURL(file)
				reader.onload = (ev)=>
					@load_image(ev.target.result)
		event.preventDefault()

	@drag_over_event = (event) =>
		@dom.addClass('drag_over')
		event.preventDefault()

	@drag_leave_event = (event) =>
		@dom.removeClass('drag_over')
		event.preventDefault()

	@add_drop_event = =>
		@raw_dom.addEventListener('drop', @drop_event, false)
		@raw_dom.addEventListener('dragover', @drag_over_event, false)
		@raw_dom.addEventListener('dragleave', @drag_leave_event, false)

	@remove_drop_event = =>
		@raw_dom.removeEventListener('drop', @drop_event)
		@raw_dom.removeEventListener('dragover', @drag_over_event)
		@raw_dom.removeEventListener('dragleave', @drag_leave_event)


	@load_image = (file)=>
		@raw_dom.src = file

		# get the image data and upload to server, then replace the img dom with the image path (src)
		@dom.one 'load', ->
			width = @naturalWidth or @width
			height = @naturalHeight or @height
			thumb_height = 2560
			thumb_width = 1280
			width_r = width/thumb_width
			height_r = height/thumb_height
			max_r = Math.max(width_r, height_r)
			w = if max_r>1 then width/max_r else width
			h = if max_r>1 then height/max_r else height

			self.canvas.width = w
			self.canvas.height = h
			self.cx.drawImage(this, 0, 0, w, h)

			if self.image_path.indexOf('.png') != -1
				image_type = 'image/png'
			else
				image_type = 'image/jpeg'

			request_data = {path: self.image_path, base64: self.canvas.toDataURL(image_type, 0.96)}

			Essage.show({message: get_text('Image Uploading, Wait...'), status: 'success'}, 30000)
			$.post content_gateway, request_data, (resposne_data, status)->
				if status == 'success'
					Essage.show({message: get_text('Image Uploaded, Done!'), status: 'success'}, 5000)

		if @raw_dom.complete
			@dom.load()

	return this



# 将原始的data中的config_pages转为knockout比较容易处理的数据
@ConfigPages = (data)->
	raw_config_pages = if data.interface? then data.interface else []
	site = data.site

	@i18n = (obj, key)=>
		obj[key + '_' + lang] or obj[key] or ''


	@get_config_value = (key, default_value)=>
		if site.configs and key of site.configs
			value = site.configs[key]
		else
			if key of site
				value = site[key]

		if $.type(value) == 'array'
			value = value.join('\n')

		# somethings true means 'yes'
		if default_value?
			if default_value in ['yes', 'no']
				if not value? # undefinde by site[key]
					value = default_value
				if value == true
					return 'yes'
				if value == false
					return 'no'

		return value

	@re_config_parts = (raw_parts)=>
		parts = []
		for row in raw_parts
			part = {}
			part.key = row.key
			part.id = 'fb_' + row.key
			part.title = @i18n(row, 'title')
			part.default_value = row.default_value or ''
			part.value = @get_config_value(part.key, part.default_value)
			if part.key == 'domain' and part.value and part.value.indexOf('r.farbox.com/')>=0 # the tmp domain
				part.value = ''
			part.placeholder = row.placeholder or row.default_value or ''
			if not row.model then row.model = 'text'
			part.model = row.model

			if part.model == 'image'
				part.raw_value =row.value
				if row.width and row.height
					src_url = row.value + '?width='+row.width+'&height='+row.height
					styles_in_admin = 'max-width:' + row.width + 'px; max-height:' + row.height + 'px'
				else if row.width
					src_url = row.value + '?width='+row.width
					styles_in_admin = 'max-width:' + row.width + 'px'
				else if row.height
					src_url = row.value + '?height='+row.height
					styles_in_admin = 'max-height:' + row.height + 'px'
				else
					src_url = row.value
					styles_in_admin = ''
				part.value = src_url
				part.styles = row.styles_in_admin or styles_in_admin

			if part.model == 'select'
				part.options = @i18n(row, 'options')
				if part.options == 'root'
					part.options = [{title: '/', value: '/'}]
					for folder in data.folders
						part.options.push({title: folder.path, value: folder.path})

			if part.model == 'check'
				part.checked = @get_config_value(part.key, part.default_value) in ['on', 'yes', true]

			if part.model == 'textarea'
				part.is_list = row.is_list or false

			parts.push(part)
		return parts


	config_pages = []
	for config_page,i in raw_config_pages
		config_page.title = @i18n(config_page, 'title')
		if config_page.icon?
			config_page.icon_css = 'fa fa-'+config_page.icon
		else
			if i of [0,1,2]
				icon = ['home', 'newspaper-o', 'wrench'][i]
			else
				icon = 'link'
			config_page.icon_css = 'fa fa-'+icon

		for group in config_page.groups or []
			group.title = @i18n(group, 'title')
			if group.hidden in ['on', 'yes', true]
				group.visible = false
			else
				group.visible = true
			for cell in group.cells or []
				cell.parts = @re_config_parts(cell.parts)
		config_pages.push(config_page)

	return config_pages

# 将页面的表单，转化成site.txt的内容
@configs_to_text = ->
	doms = $('.fb_config')
	if not doms.length
		return ''

	text = '---\n'
	for dom in doms
		dom_tag_name = dom.tagName.toLowerCase()
		id = dom.id.replace('fb_', '')
		dom = $(dom) # to Jquery type
		if dom_tag_name == 'textarea' and id!='raw_content'
			raw_text_value = $.trim(dom.val())
			if not raw_text_value
				text += id + ': \n'
				continue
			lines = raw_text_value.split('\n')
			if dom.hasClass('is_list') # a list
				text += id + ':\n'
				for line in lines
					text += '- ' + line + '\n'
			else # plain text
				text += id + ': |\n'
				for line in lines
					text += '  ' + line + '\n'
		else
			dom_type = dom.attr('type')
			if dom_type in ['text', 'hidden'] or dom_tag_name == 'select'
				text += id + ': ' + dom.val() + '\n'
			if dom_type == 'checkbox'
				text += id + ': ' + (if dom.attr('checked') then 'yes' else 'no') + '\n'
	text += ('client_date: '+new Date().getTime()+'\n')
	text += '---\n'

	content_dom = $('#fb_raw_content')
	if content_dom.length
		text += content_dom.val()

	return text


DashBoard = (data)=>
	@data = data
	@image_uploaders = []
	@config_pages = ko.observableArray(new ConfigPages(data))
	@current_config_page = ko.observable(0)
	@site = @data.site
	@site.domain = @site.domain or @site.tmp_domain
	@url_query_part = ko.observable(location.search)

	@current_site_domain = ko.observable(@site.domain)
	@current_site_domain.subscribe (domain)->
		if domain
			window.location.href = 'http://'+ domain + '/admin' + '?account_id=' + cross_account_id
		else
			alert('domain of this site is not valid')


	@save_configs = =>
		submit_dom = $('button')
		submit_dom.removeClass('pure-button-primary')
		submit_dom.text('Working...')
		config_path = @site.config_path or 'site.txt'
		$.post content_gateway, {path: config_path, raw_content: configs_to_text() }, ->
			submit_dom.addClass('pure-button-primary')
			submit_dom.text(get_text('Save Configs'))
			Essage.show({message: get_text('Configs are saved!'), status: 'success'}, 3000)
	# setup ends

	@config_for_images = =>
		for dom in $('.drag_and_upload')
			if canvas_allowed
				uploader = new ImageUploader(dom)
				uploader.add_drop_event()
				@image_uploaders.push(uploader)
			else
				dom.title = 'your current browser does not support for dragging image to upload it!'
				return false

	@reset_for_images = =>
		for uploader in @image_uploaders
			uploader.remove_drop_event()
		@image_uploaders = []


	@reset = =>
		$.getJSON admin_data_gateway, {}, (data)=>
			@config_pages(new ConfigPages(data))
			@reset_for_images()
			@config_for_images()

	if @site.error_info
		Essage.show({message: @site.error_info, status: 'error'}, 5000)

	return this


exports.DashBoard = DashBoard

$(document).ready ->
	$.getJSON admin_data_gateway, {}, (data)->
		dashboard = new DashBoard(data)
		exports.dashboard = dashboard
		ko.applyBindings(dashboard)
		dashboard.config_for_images()
		$('#layout').css('display', 'block')





