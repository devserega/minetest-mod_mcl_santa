--don't set this higher unless you want to die instantly at night
passive_attack_speed = 3

--npc just walking around
passive_chillaxin_speed = 1.5

-- Player animation speed
animation_speed = 30

-- Player animation blending
-- Note: This is currently broken due to a bug in Irrlicht, leave at 0
animation_blend = 0

-- Default player appearance
default_model = "character.x"
passive_available_npc_textures = {
	texture_1 = {"jordan4ibanez.png", },
	texture_2 = {"zombie.png", },
	texture_3 = {"celeron55.png", },
	texture_4 = {"steve.png", }
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

function player_update_visuals(self)
	--local name = get_player_name()

	visual = default_model
	player_anim = 0 -- Animation will be set further below immediately
	--player_sneak[name] = false
	prop = {
		mesh = default_model,
		textures = default_textures,
		textures = npc_available_npc_textures["texture_"..math.random(1,4)],
		visual_size = {x=1, y=1},
	}
	self.object:set_properties(prop)
end
