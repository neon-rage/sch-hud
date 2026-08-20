_addon.name = 'SCH-hud'
_addon.author = 'NeoNRAGE'
_addon.version = '2.0'

texts = require('texts')
images = require('images')
config = require('config')

local defaults = {x = 1100, y = 700}
local settings = config.load(defaults)

local tick = 0
local dragging = nil

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
		['grimoire-d'] = windower.addon_path .. 'assets/grimoire-d.png',
		['grimoire-da'] = windower.addon_path .. 'assets/grimoire-da.png',
		['grimoire-l'] = windower.addon_path .. 'assets/grimoire-l.png',
		['grimoire-la'] = windower.addon_path .. 'assets/grimoire-la.png',
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
	end

	if player.main_job == 'SCH' then
		return player.main_job_level
	end

	if player.sub_job == 'SCH' then
		return player.sub_job_level
	end

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

function render_hud()
	local sch_level = get_sch_level()

	if sch_level < 10 then
		-- not sch or not high enough level to use strategems
		strat_count_text:visible(false)
		timer_text:visible(false)
		book_image:visible(false)
		return
	else
		strat_count_text:visible(true)
		timer_text:visible(true)
		book_image:visible(true)
	end

	if is_buff_active(359) then
		-- Dark arts
		set_book_texture('grimoire-d')
		set_transparency(255, 255)
	elseif is_buff_active(358) then
		-- Light Arts
		set_book_texture('grimoire-l')
		set_transparency(255, 255)
	elseif is_buff_active(401) then
		-- Addendum White
		set_book_texture('grimoire-la')
		set_transparency(255, 255)
	elseif is_buff_active(402) then
		-- Addendum Black
		set_book_texture('grimoire-da')
		set_transparency(255, 255)
	else
		-- No Arts Active
		set_transparency(100, 50)
		set_book_texture('grimoire-l')
	end

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
	if os.time() > tick then
		tick = os.time()
		render_hud()
	end
end)

windower.register_event('unload', function()
	delete()
end)

-- Handle drag and drop
windower.register_event('mouse', function(type, x, y, delta, blocked)
	if blocked then
		return
	end

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
