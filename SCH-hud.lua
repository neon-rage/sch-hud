_addon.name = 'SCH-hud'
_addon.author = 'NeoNRAGE, plaidman'
_addon.version = '2.0'
_addon.commands = {'schhud','schud'}

texts = require('texts')
images = require('images')
config = require('config')

local defaults = {x = 100, y = 100, enabled = true}
local settings = config.load(defaults)
local temp_disabled = false

local tick = 0
local dragging = nil
local last_book = 'hide'

function init_book()
	element = images.new()

	element:pos(settings.x, settings.y)
	element:size(170, 120)
	element:fit(false)
	element:color(255, 255, 255)
	element:alpha(255)
	element:repeat_xy(1, 1)

	-- we will handle drag/drop ourself
	element:draggable(false)
	element:visible(false)

	return element
end

function init_text_element(x, y, size, color, strokeColor)
	element = texts.new("")

	element:pos(x, y)
	element:bg_alpha(0)
	element:size(size)
	element:font('Arial')
	element:color(color, color, color)
	element:bold(true)
	element:stroke_width(1.5)
	element:stroke_color(strokeColor, strokeColor, strokeColor)

	-- we will handle drag/drop ourself
	element:draggable(false)
	element:visible(false)

	return element
end

local strat_count_text = init_text_element(settings.x + 43, settings.y + 30, 35, 0, 255)
local timer_text = init_text_element(settings.x + 95, settings.y + 38, 22, 255, 0)
local book_image = init_book()

function set_book_texture(name)
	local textures = {
		['dark'] = windower.addon_path .. 'assets/grimoire-d.png',
		['dark-a'] = windower.addon_path .. 'assets/grimoire-da.png',
		['light'] = windower.addon_path .. 'assets/grimoire-l.png',
		['light-a'] = windower.addon_path .. 'assets/grimoire-la.png',
		['neutral'] = windower.addon_path .. 'assets/grimoire-l.png',
	}

	book_image:path(textures[name])
end

function set_transparency(alpha, alpha2)
	book_image:alpha(alpha)
	strat_count_text:alpha(alpha2)
	strat_count_text:stroke_alpha(alpha)
	timer_text:alpha(alpha2)
	timer_text:stroke_alpha(alpha)
end

function update_position(x, y)
	settings.x = x
	settings.y = y
	book_image:pos(settings.x, settings.y)
	strat_count_text:pos(settings.x + 43, settings.y + 30)
	timer_text:pos(settings.x + 95, settings.y + 38)
end

function get_sch_level()
	local player = windower.ffxi.get_player()

	if not player then
		return -1
	elseif player.main_job == 'SCH' then
		return player.main_job_level
	elseif player.sub_job == 'SCH' then
		return player.sub_job_level
	end

	temp_disabled = true
	return -1
end

function get_max_strats(sch_level)
	if sch_level < 30 then
		return 1
	elseif sch_level < 50 then
		return 2
	elseif sch_level < 70 then
		return 3
	elseif sch_level < 90 then
		return 4
	else
		return 5
	end
end

function is_buff_active(buff_num)
	for k,v in pairs(windower.ffxi.get_player().buffs) do
		if v == buff_num then
			return true
		end
	end

	return false
end

function which_book_active(sch_level)
	if sch_level < 10 then
		return 'hide'
	elseif is_buff_active(359) then
		return 'dark'
	elseif is_buff_active(358) then
		return 'light'
	elseif is_buff_active(401) then
		return 'light-a'
	elseif is_buff_active(402) then
		return 'dark-a'
	else
		return 'neutral'
	end
end

function render_book(sch_level)
	local active_buff = which_book_active(sch_level)
	if active_buff == last_book then return end

	if active_buff == 'hide' then
		-- not sch or not high enough level to use strategems
		strat_count_text:visible(false)
		timer_text:visible(false)
		book_image:visible(false)
		last_book = 'hide'
		return
	end

	if last_book == 'hide' then
		strat_count_text:visible(true)
		timer_text:visible(true)
		book_image:visible(true)
	end

	set_book_texture(active_buff)
	set_transparency(
		active_buff == 'neutral' and 100 or 255,
		active_buff == 'neutral' and 50 or 255
	)

	last_book = active_buff
end

function render_strat_count(sch_level)
	if sch_level < 10 then return end

	local max_strats = get_max_strats(sch_level)

	-- current strategem recast countdown -- total recast is 240 seconds by default
	-- jp 550 or more, reduces the total recast countdown to 165 seconds (33 sec per point)
	-- time to regen one strategem is the total recast time divided by the number of strategems available at your level
	local job_points = windower.ffxi.get_player().job_points.sch.jp_spent
	local one_strat_time = (job_points >= 550 and 165 or 240) / max_strats

	local total_strat_timer = math.floor(windower.ffxi.get_ability_recasts()[231])	
	local cur_strats = math.floor(max_strats - (total_strat_timer / one_strat_time))
	local next_strat_timer = total_strat_timer % one_strat_time

	strat_count_text:text("" .. tostring(cur_strats))
	if (total_strat_timer ~= 0) then
		timer_text:visible(true)
		if (next_strat_timer > 9) then
			timer_text:text("" .. tostring(next_strat_timer))
		else
			timer_text:text("0" .. tostring(next_strat_timer))
		end
	else
		timer_text:visible(false)
	end
end

function delete()
	book_image:destroy()
	strat_count_text:destroy()
	timer_text:destroy()
end

windower.register_event('prerender', function()
	if (not settings.enabled) or temp_disabled then return end
	if os.time() == tick then return end


	local sch_level = get_sch_level()
	render_book(sch_level)
	render_strat_count(sch_level)

	tick = os.time()
end)

windower.register_event('unload', function()
	delete()
end)

-- Handle drag and drop
windower.register_event('mouse', function(type, x, y, delta, blocked)
	if blocked then return end

	-- Mouse drag
	if type == 0 then
		if dragging then
			update_position(x - dragging.x, y - dragging.y)
			return true
		end

	-- Mouse left click
	elseif type == 1 then
		if book_image:hover(x, y) or strat_count_text:hover(x, y) or timer_text:hover(x, y) then
			dragging = {x = x - settings.x, y = y - settings.y}
			return true
		end

	-- Mouse left release
	elseif type == 2 then
		if dragging then
			update_position(x - dragging.x, y - dragging.y)
			config.save(settings, 'all')
			dragging = nil
			return true
		end
	end

	return false
end)

windower.register_event('addon command', function (command, ...)
    local args = {...}
    command = command and command:lower() or 'toggle'

	if command == 'toggle' then
		settings.enabled = not settings.enabled
		book_image:visible(settings.enabled)
		strat_count_text:visible(settings.enabled)
		timer_text:visible(settings.enabled)
		config.save(settings, 'all')
	end

	if command == 'reset' then
		update_position(defaults.x, defaults.y)
		settings.enabled = defaults.enabled
		temp_disabled = false
		book_image:visible(settings.enabled)
		strat_count_text:visible(settings.enabled)
		timer_text:visible(settings.enabled)
		config.save(settings, 'all')
	end

	if command == 'help' then
		windower.add_to_chat(207, 'SCH-hud commands:')
		windower.add_to_chat(207, '  //schhud toggle - toggle the hud on/off')
		windower.add_to_chat(207, '  //schhud reset - reset the hud position to default')
		windower.add_to_chat(207, '  //schhud enable - enable the hud')
		windower.add_to_chat(207, '  //schhud disable - disable the hud')
		windower.add_to_chat(207, '  //schhud help - show this help message')
	end

	if command == 'enable' then
		settings.enabled = true
		book_image:visible(settings.enabled)
		strat_count_text:visible(settings.enabled)
		timer_text:visible(settings.enabled)
		config.save(settings, 'all')
	end

	if command == 'disable' then
		settings.enabled = false
		book_image:visible(settings.enabled)
		strat_count_text:visible(settings.enabled)
		timer_text:visible(settings.enabled)
		config.save(settings, 'all')
	end
end)

windower.register_event('job change',function()
	temp_disabled = false
end)
