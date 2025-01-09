local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)
local S = minetest.get_translator(modname) -- Загрузка локализатора

-- Настройки скорости
local chillaxin_speed = 1.5

-- Скорость анимации
local animation_speed = 30
local animation_blend = 0

-- Модель и текстуры
local default_model = "character.x"
local santa_textures = {"santa.png"}

-- Радиус движения от точки спавна
local roam_radius = 10

local STATE_NONE = 0
local STATE_STAND = 1
local STATE_WALK = 2
local STATE_DROP = 3

-- Получение анимаций для модели
local function player_get_animations(model)
	if model == "character.x" then
		return {
			stand_START = 0,
			stand_END = 79,
			walk_START = 168,
			walk_END = 187,
		}
	end
end

-- Создание NPC "SANTA"
local SANTA = {
	physical = true,
	collisionbox = {-0.3, -1.0, -0.3, 0.3, 0.8, 0.3},
	visual = "mesh",
	mesh = default_model,
	textures = santa_textures,
	spawn_pos = nil, -- точка спавна
	state = STATE_STAND, -- состояния: "stand" или "walk"
	target_pos = nil, -- текущая цель
	timer = 0,
}

-- Обновление внешнего вида NPC
local function update_visuals(self)
	local prop = {
		mesh = default_model,
		textures = self.textures or santa_textures,
		visual_size = {x = 1, y = 1},
	}
	self.object:set_properties(prop)
end

-- Выбор случайной точки в пределах радиуса от точки спавна
local function choose_random_target(spawn_pos, radius)
	local angle = math.random() * 2 * math.pi
	local distance = math.random() * radius
	return {
		x = spawn_pos.x + math.cos(angle) * distance,
		y = spawn_pos.y,
		z = spawn_pos.z + math.sin(angle) * distance,
	}
end

-- Активация NPC
SANTA.on_activate = function(self, staticdata)
	self.spawn_pos = self.object:get_pos()
	update_visuals(self)
	self.animations = player_get_animations(default_model)
	self.object:set_animation({x = self.animations.stand_START, y = self.animations.stand_END}, animation_speed, animation_blend)
	self.object:set_acceleration({x = 0, y = -10, z = 0}) -- Гравитация
	self.timer = 0 -- Инициализация таймера
	self.target_pos = nil -- Сбрасываем цель
end

-- Определение вероятностей для состояний
local state_probabilities = {
	[STATE_STAND] = 0.2,  -- 20% вероятность стояния
	[STATE_WALK] = 0.6,   -- 60% вероятность ходьбы
	[STATE_DROP] = 0.2,   -- 20% вероятность выпадения угля
}

-- Функция для выбора состояния на основе вероятностей
local function get_random_state()
	local rand = math.random()
	local cumulative_probability = 0

	for state, probability in pairs(state_probabilities) do
		cumulative_probability = cumulative_probability + probability
		if rand <= cumulative_probability then
			return state
		end
	end

	-- Возвращаем значение по умолчанию (если что-то пошло не так)
	return STATE_NONE
end

local function get_random_prize_name()
	-- Определение вероятностей для призов
	local prizes_probabilities = {
		["mcl_core:coal_lump"] = 0.4,      -- 20% вероятность угля
		["mcl_farming:wheat_item"] = 0.4,   -- 60% вероятность пшеницы
		["mcl_raw_ores:raw_iron"] = 0.2,      -- 20% вероятность железного слитка
	}

	local rand = math.random()  -- Генерация случайного числа от 0 до 1
	local cumulative_probability = 0

	-- Проходим по всем призам и их вероятностям
	for prize, probability in pairs(prizes_probabilities) do
		cumulative_probability = cumulative_probability + probability
		if rand <= cumulative_probability then
			return prize
		end
	end
end

local function santa_stand(self)
	--minetest.chat_send_all(S("STATE_STAND"))

	--minetest.log("action", "serega: STATE_STAND")
	self.object:set_velocity({x = 0, y = self.object:get_velocity().y, z = 0})
	self.object:set_animation({x = self.animations.stand_START, y = self.animations.stand_END}, animation_speed, animation_blend)
end

local function santa_walk(self)
	--minetest.chat_send_all(S("STATE_WALK"))
	--minetest.log("action", "serega: STATE_WALK")

	self.target_pos = choose_random_target(self.spawn_pos, roam_radius) -- Выбираем новую цель
	local santa_pos = self.object:get_pos()
	local vec = vector.subtract(self.target_pos, santa_pos)
	local yaw = math.atan2(vec.z, vec.x)-math.pi/2
	self.object:set_yaw(yaw)
	
	-- Если цель достигнута, переключиться в состояние "stand"
	local distance = vector.length(vec)
	if distance < 1 then
		self.state = STATE_STAND
		self.timer = 0 -- Сбрасываем основной таймер
		self.target_pos = nil
		return
	end

	local direction = vector.normalize(vec)
	self.object:set_velocity({x = direction.x * chillaxin_speed, y = self.object:get_velocity().y, z = direction.z * chillaxin_speed})
	self.object:set_animation({x = self.animations.walk_START, y = self.animations.walk_END}, animation_speed, animation_blend)
end

local function santa_drop(self)
	--minetest.chat_send_all(S("STATE_DROP"))
	local pos = self.object:get_pos()

	-- Добавляем уголь в мир рядом с Santa
	local prize_count = math.random(3, 7) -- Здесь задается количество приза
	local prize_name = get_random_prize_name()
	for i = 1, prize_count do
		local prize_pos = {x = pos.x + math.random(-2, 2), y = pos.y, z = pos.z + math.random(-2, 2)}
		minetest.add_item(prize_pos, prize_name)
	end

	-- Возвращаем Санту к состоянию "stand"
	self.state = STATE_STAND
	self.timer = 0 -- Сбрасываем основной таймер
	self.target_pos = nil
end

-- Обработка шага SANTA
SANTA.on_step = function(self, dtime)
	if self.timer == 0 then
		-- Инициализация таймера до смены состояния
		self.change_timer = math.random(3, 7) -- Генерируем новый интервал для следующего изменения состояния
		self.state = get_random_state()
		--minetest.log("action", "serega: set change_timer=" .. minetest.serialize(self.change_timer) .. " state=" .. minetest.serialize(self.state))

		if self.state == STATE_STAND then
			-- SANTA стоит
			santa_stand(self)
		elseif self.state == STATE_WALK then
			-- SANTA идёт
			santa_walk(self)
		elseif self.state == STATE_DROP then
			-- SANTA выкидывание приза
			santa_drop(self)
		end
	end

	self.timer = self.timer + dtime
	--minetest.log("action", "serega: timer=" .. minetest.serialize(self.timer) .. " dtime=" .. minetest.serialize(dtime))

	if self.state == STATE_STAND then
		for _, object in ipairs(minetest.env:get_objects_inside_radius(self.object:getpos(), 3)) do
			if object:is_player() then
				local PLAYER_pos = object:getpos()
				local SANTA_pos = self.object:getpos()
				local vec = vector.subtract(PLAYER_pos, SANTA_pos)
				local yaw = math.atan2(vec.z, vec.x)-math.pi/2
				self.object:setyaw(yaw)
			end
		end
	end

	if self.timer >= self.change_timer then
		-- Смена состояния каждые 3–7 секунд
		self.timer = 0 -- Сбрасываем основной таймер
		self.target_pos = nil -- Сбрасываем цель
		--minetest.log("action", "serega: reset timer")
	end
end

SANTA.on_punch = function(self, puncher)
	local is_player = puncher:is_player()
	local player_name = puncher:get_player_name()

	-- Проверяем, является ли игрок креативным
	if puncher and is_player then
		--minetest.log("action", "serega: creative punch")
		if minetest.is_creative_enabled(player_name) then
			--minetest.log("action", "serega: player_name=" .. minetest.serialize(player_name) .. " is creative")
			-- Уничтожаем Санту
			self.object:remove()
			minetest.chat_send_player(player_name, S("Santa destroyed!"))
			return
		else
			-- Если игрок не в креативе, блокируем атаку
			minetest.chat_send_player(player_name, S("You cannot kill Santa!"))
		end
	end

	-- Звук при атаке (если не в креативном режиме)
	minetest.sound_play("santa_hurt", {pos = self.object:get_pos(), gain = 1.5, max_hear_distance = 64})

	return true
end

-- Регистрация NPC
minetest.register_entity(modname .. ":santa", SANTA)

-- Спавнер для NPC
minetest.register_node(modname .. ":santa_spawner", {
	description = "Santa Spawner",
	image = "ornament.png",
	inventory_image = "ornament.png",
	wield_image = "ornament.png",
	paramtype = "light",
	tiles = {"spawnegg.png"},
	is_ground_content = true,
	drawtype = "nodebox",
	groups = {crumbly=3},
	selection_box = {
		type = "fixed",
		fixed = {0,0,0,0,0,0}
	},
	node_box = {
	type = "fixed",
		fixed = {  {0,0,0,0,0,0}, }
	},
	sounds = mcl_sounds.node_sound_dirt_defaults(),
	on_place = function(itemstack, placer, pointed)
		pos = pointed.above
		pos.y = pos.y + 1
		minetest.env:add_entity(pointed.above,"mcl_santa:santa")
		minetest.sound_play("hohoho", {pointed.above, gain=1.5, max_hear_distance=2*64})
	end
})