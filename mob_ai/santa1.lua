local modname = minetest.get_current_modname()
local path = minetest.get_modpath(modname)

--don't set this higher unless you want to die instantly at night
attack_speed = 3

--npc just walking around
chillaxin_speed = 1.5

-- Player animation speed
animation_speed = 30

-- Player animation blending
-- Note: This is currently broken due to a bug in Irrlicht, leave at 0
animation_blend = 0

-- Default player appearance
default_model = "character.x"
santa_textures = {
	texture_1 = {"santa.png", },
}

-- Frame ranges for each player model
function player_get_animations(model)
	if model == "character.x" then
		return {
		stand_START = 0,
		stand_END = 79,
		sit_START = 81,
		sit_END = 160,
		lay_START = 162,
		lay_END = 166,
		walk_START = 168,
		walk_END = 187,
		mine_START = 189,
		mine_END = 198,
		walk_mine_START = 200,
		walk_mine_END = 219
		}
	end
end

local player_model = {}
local player_anim = {}
local player_sneak = {}
local ANIM_STAND = 1
local ANIM_SIT = 2
local ANIM_LAY = 3
local ANIM_WALK  = 4
local ANIM_WALK_MINE = 5
local ANIM_MINE = 6

function santa_update_visuals(self)
	--local name = get_player_name()

	visual = default_model
	player_anim = 0 -- Animation will be set further below immediately
	--player_sneak[name] = false
	prop = {
		mesh = default_model,
		textures = santa_textures["texture_1"],
		visual_size = {x=1, y=1},
	}
	self.object:set_properties(prop)
end

function navigate(self)
	NPC = self.object:getpos()
	for x = -1,1 do
		for z = -1,1 do
			if x == 1 or x == -1 then
				if z == 1 or z == -1 then
					if minetest.get_node({x=math.floor(0.5+NPC.x)+x,y=NPC.y,z=math.floor(0.5+NPC.z)}).name == "air" then
						TARGET = {x=math.floor(0.5+NPC.x)+x,y=NPC.y,z=math.floor(0.5+NPC.z)}
						break
					end
				end
			end
		end
	end
	if TARGET == nil then
		print("WHOA BABY WE GOTZ OURSELF A BUG!")
		return
	end
	self.vec = {x=TARGET.x-NPC.x, y=TARGET.y-NPC.y, z=TARGET.z-NPC.z}
	self.yaw = math.atan(self.vec.z/self.vec.x)+math.pi^2
	if TARGET.x > NPC.x then
		self.yaw = self.yaw + math.pi
	end
	self.yaw = self.yaw - 8
	--self.object:setyaw(self.yaw)
	self.turn_speed = 0.1
end


SANTA = {
	physical = true,
	collisionbox = {-0.3,-1.0,-0.3, 0.3,0.8,0.3},
	visual = "mesh",
	mesh = "character.x",
	--textures = {"character.png"},
	player_anim = 0,
	timer = 0,
	turn_timer = 0,
	vec = 0,
	yaw = 0,
	yawwer = 0,
	newyaw = 0,
	state = 1,
	jump_timer = 0,
	door_timer = 0,
	attacker = "",
	attacking_timer = 0,
	makes_footstep_sound = true,
	hurt = false,
	present_timer = 0,
	turn_speed = 0,
}

SANTA.on_activate = function(self)
	santa_update_visuals(self)
	self.anim = player_get_animations(visual)
	self.object:set_animation({x=self.anim.stand_START,y=self.anim.stand_END}, animation_speed_mod, animation_blend)
	self.player_anim = ANIM_STAND
	self.object:setacceleration({x=0,y=-10,z=0})
	self.state = math.random(1,2)
	self.turn_speed = 0.1
end

SANTA.on_punch = function(self, puncher)
	minetest.sound_play("santa_hurt", {pos=self.object:getpos(), gain=1.5, max_hear_distance=2*64})
end

SANTA.on_rightclick = function()
	print(dump(minetest.env:get_timeofday()))
end

SANTA.on_step = function(self, dtime)
	self.timer = self.timer + 0.01
	
	self.turn_timer = self.turn_timer + 0.01
	self.jump_timer = self.jump_timer + 0.01
	if self.timer > math.random(2,5) then
		self.state = math.random(1,2)
		self.timer = 0
		if self.object:getvelocity().y ~= 0 then
			self.state = 2
		end
	end
	local turndiff = self.object:getyaw()-self.yaw
	if turndiff > 0 and turndiff > 0.15 then
		self.object:setyaw(self.object:getyaw()-self.turn_speed)
	elseif turndiff < 0 and turndiff < 0.15 then
		self.object:setyaw(self.object:getyaw()+self.turn_speed)
	end
	
	if self.state == 1 then
		--STANDING
		self.yawwer = true
		for _, object in ipairs(minetest.env:get_objects_inside_radius(self.object:getpos(), 3)) do
			if object:is_player() then
				self.yawwer = false
				NPC = self.object:getpos()
				PLAYER = object:getpos()
				self.vec = {x=PLAYER.x-NPC.x, y=PLAYER.y-NPC.y, z=PLAYER.z-NPC.z}
				self.yaw = math.atan(self.vec.z/self.vec.x)+math.pi^2
				if PLAYER.x > NPC.x then
					self.yaw = self.yaw + math.pi
				end
				self.yaw = self.yaw - 8.3
				self.object:setyaw(self.yaw)
			end
		end
		if self.turn_timer > math.random(1,2) then
			self.yaw = 6 * math.random()
			self.turn_timer = 0
			self.turn_speed = 0.09
		end
		self.object:setvelocity({x=0, y=self.object:getvelocity().y, z=0})
		if self.player_anim ~= ANIM_STAND then
			self.anim = player_get_animations(visual)
			self.object:set_animation({x=self.anim.stand_START, y=self.anim.stand_END}, animation_speed_mod, animation_blend)
			self.player_anim = ANIM_STAND
		end
	elseif self.state == 2 then
		--WALKING
		self.direction = {x = math.sin(self.object:getyaw())*-1, y = -10, z = math.cos(self.object:getyaw())}
		if self.direction ~= nil then
			self.object:setvelocity({x=self.direction.x*chillaxin_speed,y=self.object:getvelocity().y,z=self.direction.z*chillaxin_speed})
		end
		
		if self.turn_timer > math.random(3,7) then
			self.yaw = 6 * math.random()
			self.turn_timer = 0
			self.turn_speed = 0.1 * math.random()
			
		end
		if self.player_anim ~= ANIM_WALK then
			self.anim = player_get_animations(visual)
			self.object:set_animation({x=self.anim.walk_START,y=self.anim.walk_END}, animation_speed_mod, animation_blend)
			self.player_anim = ANIM_WALK
		end
		--jump
		if self.direction ~= nil then
			if self.jump_timer > 0.45 then
				if minetest.registered_nodes[minetest.get_node({x=self.object:getpos().x + self.direction.x,y=self.object:getpos().y-0.35,z=self.object:getpos().z + self.direction.z}).name].walkable then
					--self.object:setvelocity({x=self.object:getvelocity().x,y=5,z=self.object:getvelocity().z})
					self.object:setvelocity({x=self.object:getvelocity().x,y=5,z=self.object:getvelocity().z})
					self.jump_timer = 0
				end
			end
		end
		
	end
end

minetest.register_entity("mcl_santa:santa", SANTA)

minetest.register_node("mcl_santa:santa_spawner", {
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