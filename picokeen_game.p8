pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
 -- tiles and math (ew!) ∧

function or_many(l,v)
 for i = 1,#l do
  if (l[i] == v) return true
 end
 return false
end

function in_range(v,l,u)
 return v >= l and v <= u
end

function decel(v,a)
 return v - a < 0 and 0 or v - a
end

function accel(v,a,vm)
 return v + a > vm and vm or v + a
end

function rect_in_rect(x1,y1,x1r,y1r,x2,y2,x2r,y2r)
 return not (x1r < x2 or x1 > x2r) and not (y1r < y2 or y1 > y2r)
end

function rect_pobj_8x8(o,ins)
	if (ins == nil) ins = 0
 return rect_in_rect(px+ins,py-4+ins,px+7-ins,py+7-ins,o.x,o.y,o.x+7,o.y+7)
end

--di,dj,axis = nil


-- -----------------------
-- get -1,0,+1 i,j offsets
-- for directions.
-- use mn,mx as extra vals
-- to create new ranges
-- -1,0,8 in coll boxes.
-- -----------------------

function set_dij(r,mn,mx)
	if (mn == nil) mn,mx = -1,1

	axis = r % 2 == 1
	di,dj = 0,0
	local _sign = r >= 2 and mx or mn
	if axis then di = _sign
									else dj = _sign
	end
end

-- ============================

-- tiles ▤

-- ============================

t_flip = false
t_anim_timer,t_conveyor,t_burner = 5,0,0
tiles,tiles_rot = {},{}
function init_map()

	-- init
	
	switches,breakers = {},{}

	for i = 0,16 do 
	 switches[i] = {}
	end
	
	read_map()
	
 -- init tile grid to size
 
 for i = 1,tiles_w do
 	add(tiles,{})
 	add(tiles_rot,{})
  for j = 1,tiles_h do
 		add(tiles[i],0)
 		add(tiles_rot[i],0)
 	end
 end
 
 -- read from memory

 load_map()
 
end

function ij_oob(i,j)
 return  (i < 1 or i > tiles_w or j < 1 or j > tiles_h)
end

function t_at(i,j)
 return ij_oob(i,j) and 0 or	tiles[i][j]
end

function t_set(i,j,t)
 if (not ij_oob(i,j)) tiles[i][j] = t
end

function t_pole(v) 
 return v == 83 or v == 89
end

function find_bonus_at(i,j,t)

	local _b,_t
	for k = 0,3 do 
	 set_dij(k)
	 _b = bonus_at(i + di,j + dj,t)
	 if (_b != 0) return _b
	end
	return 0
	
end

function bonus_at(i,j,t)
	local _t = t_at(i,j)
 if _t == t then
  t_set(i,j,0)
  return tiles_rot[i][j] + 1
 end
 return 0
end

function load_in_scene(i,j,t,r)
	
	local x,y,_t = to_xy(i),to_xy(j),0
			
	-- -------------
	-- scene entites
	-- no i,j block
	-- -------------
	
	-- pspawn
 if t == 1 then
  px,py,checkpoint_x,checkpoint_y = x,y,x,y
  	
 -- exit
 elseif t == 2 then
  exit.x,exit.y = x,y
  	
 -- checkpoint
 elseif t == 6 then
  checkpoint(x,y)
  	
 -- bg door
 elseif t == 60 then
  add(doors,{x=x,y=y,id= find_bonus_at(i,j,62)})
  	
 -- moving platforms
 elseif t == 4 then
  
  local _id = find_bonus_at(i,j,62)
  local _mp = {
			x=x,y=y,dir=r,on=_id==0
		}
		
		add(m_platforms,_mp)
		if (_id != 0) add(switches[_id],function() _mp.on = not _mp.on end)
	 
 -- pickups
 elseif in_range(t,48,56) then
  if (t >= 56) t += r
  add(pickups, {x=x,y=y,id=t-47})
 
 -- enemies
 elseif in_range(t,37,45) then
 	enemy(x,y,t-36,r == 0,r)

 -- default tiles.
 else _t = t end
 		
 -- switches
 if (t == 3 or t == 7) add(switches, {i=i,j=j,id = find_bonus_at(i,j,62),jumpon = t==3,on = false})

 -- toggle blocks
  	
 if in_range(t,87,88) then
  add(switches[r],
  		function() 
	  		tiles[i][j] = tiles[i][j] == 88 and 87 or 88
  		end
  		)
 end
  	
 -- breaker blocks
  	
 if (t == 100) add(breakers,{i=i,j=j,state=0,timer=0})
  	
 -- turrets + beamers 
 		
	if in_range(t,33,36) then
 	
 	local _pick,_rot = t <= 34,r==0
 	local _bonus = find_bonus_at(i,j, _pick and 61 or 62)

 	r = (t % 2 == 1) and (_rot and 0 or 2) or (_rot and 1 or 3)
 	
 	local _bort = {
				x=x,y=y,dir=r,shooton=_bonus * 10,
		 	i=i,j=j,
		 	on = false,
	  	timed = _bonus==0
		}
 		 
 	if _pick then 
 		 
 		-- turret --
 		add(turrets,_bort)
 		 
 	else 
 	
		 add(beamers,_bort)
		 if _bonus !=0  then
		   beamer_toggle(_bort)
		   add(switches[_bonus],function() beamer_toggle(_bort) end)
		 end
		end
	end
	
 	t_set(i,j,_t)

end

function update_tiles()
	
	-- update break tiles
	
	for k,b in pairs(breakers) do
	 
	 -- grab tile data.
	 
	 local i,j,s,t = b.i,b.j,b.state
	 
	 if s == 0 then t = 100
	 elseif s == 1 then t = 224
	 else t = 225 end
	 
	 tiles[i][j] = t
	 
	 -- update breaker anim.
	 
	 if s != 0 then
	  b.timer -= 1
	  
	  if b.timer <= 0 then
	   
	   b.state += 1
	   
	   if (b.state > 2) b.state = 0
	  	if (b.state == 2) b.timer = 90
	  	
	  end
	 end
	end
	
	
	-- animate some tiles.
	
	t_conveyor += 1
	if (t_conveyor > 3) t_conveyor = 0	
	
	if t_anim_timer <= 0 then
		t_burner += 1
		if (t_burner > 2) t_burner = 0
 	t_flip = not t_flip
 	t_anim_timer = 5
 else
  t_anim_timer -= 1
 end
	
end

-- ============================

-- 					draw all tiles.

-- ============================

function draw_tiles()

	-- tiles layer
	
	x0,y0 = to_tile(cx),to_tile(cy)

 for i = ci,ci+16 > tiles_w and tiles_w or ci+16 do
  for j = cj,cj+16 > tiles_h and tiles_h or cj+16 do
			
 		local x,y = x0,y0
 		
			-- handle unique tiles.
		
   local _hflip,_vflip = false,false
   t = tiles[i][j]
   r = (or_many({5,87,88},t)) and 0 or tiles_rot[i][j]

   
   _hflip = r % 2 == 1
   _vflip = r >= 2
   
   -- zappers.
   
   if t == 32 or t == 31 then
   	if t == 32 then _flip = i % 2 == 0 else _flip = j % 2 == 0 end
   	if (t_flip) _flip = not _flip
   	if t == 32 then _hflip = _flip else _vflip = _flip end
   end
   
   -- climb poles
   
   if t_pole(t) then
   	local _below = tiles[i][j+1]
    if (_below == 0 or (_below != 89 and t == 89)) t+=1
   	if (tiles[i][j-1] == 0) t+=2
   end
   
   -- jump switches
   
   if t == 3 or t == 139 then
   	spr(116,x,y)
    y-=2
    x-=2
    spr(140,x+8,y+1)
    if (t == 139) y+=2
   end
   
   if (t == 7 or t == 159) y-=4
  
   
   -- burners
   
   if (t == 29 and t_flip) t = 141
   if (t == 30 and t_burner > 0) t = 141 + t_burner
   
   -- conveyors.
   
   if t == 102 then
    
    -- belt ends.
    
    if tiles[i-1][j] == 0 then
     t = 131 + (r==0 and t_conveyor or (3-t_conveyor))
    	if (r==1) _hflip = false
    elseif tiles[i+1][j] == 0 then
     t = 131 + (r==1 and t_conveyor or (3-t_conveyor))
 				if (r==0) _hflip = true
    
    -- belts mids.
				else
		   t = t_conveyor == 0 and 102 or (127 + t_conveyor)
   	end
   end
   
   -- locked doors
   if t == 97 then
   	if (r > 0) gem_pal(r)
   	_hflip = false
   	_vflip = false
   	if (tiles[i][j+1] != 97) t = 98
   end
   
   -- invis enemy barrier.
   if (t == 59) t = 0
   -- invis scene modifiers.
   if (t >= 61 and t <= 63) t = 0

   -- draw it!
  
   if (t != 0) spr(t,x,y,1,1,_hflip,_vflip)
   y0 += 8
   pal()
  end
  x0 += 8
  y0 = to_tile(cy)
 end
 
 -- checkpoints
 
 for cp in all(checkpoints) do
  spr(cp.on and 158 or 6,cp.x,cp.y)
 end
 
end

function to_ij(v)
 return 1 + flr(v / 8)
end

function to_xy(v)
 return (v-1) * 8
end

function to_tile(v)
 return to_xy(to_ij(v))
end

function coll_at(x,y,r)
 local i,j = to_ij(x),to_ij(y)
 local _dx,_dy = to_xy(i),to_xy(j)
 if (i < 1 or i > tiles_w) return true
 if (j < 1 or j > tiles_h) return false

 local _t,_rot = tiles[i][j],tiles_rot[i][j]

 -- non solids.
 
 if (is_empty(_t)) return false
 if (_t == 114 or _t == 3) return false
 
 -- slopes : collide on y = x
 
 if _t == 112 and _rot == 0 then
 	if (not r) return false
 	return not (y-_dy <= 8-(x-_dx))
 end
 
 if _t == 112 and _rot == 1  then
  if (r) return false 
  return not (y-_dy <= x-_dx)
 end
 
 return true
 
end

function tile_at(x,y)
	local i,j = to_ij(x),to_ij(y)
 if (i < 1 or i > tiles_w or j < 1 or j > tiles_h) return 0
 return tiles[i][j]
end

function rot_at(x,y)
 	local i,j = to_ij(x),to_ij(y)
 if (i < 1 or i > tiles_w or j < 1 or j > tiles_h) return 0
 return tiles_rot[i][j]
end

function slope_at(x,y) 
 return tile_at(x,y) == 112

end

function grab_at(x,y)

 local _t = tile_at(x,y)
 if (in_range(_t,100,103)) return false
 return coll_at(x,y) 
 
end


function is_empty(t)
 return or_many({0,5,7,9,11,13,15,95,159,83,89,88,59,255,139,61,62,63,172,173,174,225},t) or in_range(t,115,127) or is_hazard(t)
end

function is_hazard(t)
 return in_range(t,29,32)
end

function is_platform(t)
 return or_many({3,114,95,9,11,13,15},t)
end


function open_door_at(i,j,dosfx)
 
 if (i < 1 or j < 1 or i > tiles_w or j > tiles_h) return
 local _t = tiles[i][j]
 local _r = tiles_rot[i][j]
 
 if _t == 97 and 
    keys[_r + 1] then
 			
 	if (dosfx) sfx(11)
	 tiles[i][j] = 124
	 open_door_at(i,j-1,false)
	 open_door_at(i,j+1,false)

 end
end

-------------------------------
-- level loading + compression
-------------------------------

maps = {}
loaded_map = ""
level_music = 0

-- =========================
-- get map string data from
-- 32k memory
-- =========================

symbols = "^*./0123456789abcdefghijklmnopqrstuvqxyz"
b_to_c = {}
bg_image_addr = 0

function read_map()

 -- expects 5 dashes
 
 local _dashes = 0
 local _results = {0,0,0,0,0}
	
	local _str,_char = "",""
	local i = 0
	
	while _dashes < 5 do
	 _char = b_to_c[peek(0x8000 + i)]
	 if _char == "/" then
	   _dashes += 1
	  _results[_dashes] = _str
	  _str = ""
	 else _str ..= _char end
	 i += 1
	end
	
	bg_image_addr = 0x8000 + i
	
	-- parse results
	
	--level_music = tonum(_results[2])
	tiles_w = tonum(_results[3])
	tiles_xr = tiles_w * 8
	tiles_h = tonum(_results[4])
	tiles_yr = tiles_h * 8
	loaded_map = _results[5] .. "/"

end

-- =======================

-- parse the map data as
-- a playable level!

-- =======================

function load_map()

  -- load from mapdata.txt
 
 to_load = loaded_map
 state = 0
 parsed,char,at = "","",0
 i,j = 1,1
 
 rot,num,tile = 0,0,0
 
 -- ===========
 -- co-routines
 -- ===========
 
 -- parse one character.
 function parse()
 	at += 1
		char = sub(to_load,at,at)
 end
 
 -- parse state at.
 function change_state()
  local _change = state
  if (char == "/") state = 4 -- finish
 	if (char == "*") state = 2 -- num of tiles
 	if (char == "^") state = 1 -- rotation 
 	
 	-- state : 1 or many tiles.
 	
 	if char == "." then 
 		state = 3 -- tile id
 		if (_change == state) return true
 	end
 	
 	return _change != state
 end
 
 -- =======
 -- states.
 -- =======
 
 -- parse ^, rotation value
 
 function parse_rot_num(isrot)
  parse()
 	if not change_state() then
 		parsed ..= char
 	else
 	 local _p = tonum(parsed)
 	 if isrot then rot = _p else num = _p end
 	 parsed = ""
 	end
 end
 
 -- parse ., a tile id.
 
 function parse_tile()
 	parse()
 	if not change_state() then
 		parsed ..= char
 	else
 	
 	 -- insert tiles into scene
 	 
 	 tile = tonum(parsed)
 	 
	  while num > 0 do
	  
	 	 tiles[i][j] = tile
	 	 tiles_rot[i][j] = rot
	 	 i += 1
	 	 if (i > tiles_w)	i = 1 j += 1
	 	 num -= 1

	 	end
	 	
	 	-- reset data.
	 	
	 	num = 1
	 	rot = 0
	 	
	 	parsed = ""
	 		
 	end
 end
 
 -- ==================
 -- state machine loop
 -- ==================
 
 -- set initial state.
 parse()
 change_state()
 
 -- run the state machine
 while state != 4 do
  if state == 1 then parse_rot_num(true)
  elseif state == 2 then parse_rot_num(false)
  else parse_tile() end
 end

	-- ==================
	-- parse raw tile id 
	-- to scene objects
	-- ===================

	for i = 1,tiles_w do
	 for j = 1,tiles_h do
	  load_in_scene(i,j,tiles[i][j],tiles_rot[i][j])
	 end
	end

end


-->8
-- player ♥ + camera + exit + checkpoints

key_jump,key_shoot,key_pogo = 29,27,6
exit = {}

checkpoint_x,checkpoint_y = 0,0

p_hanging,p_climbing,p_hang_reset_timer,
p_climb_wait,p_climb_anim,p_climb_anim_timer,
p_enter_door,p_enter_door_timer,
p_dead,p_set_dead,p_is_right
= false,false,10,0,false,0,false,0,false,true,true

p_on_door = nil

deady,px,py,pi,pir,pj,pjr,
py_fall,py_fall_trigger,
p_spd,p_spd_max,p_spd_flung,
p_spd_a,p_spd_d,p_grav,p_grav_a,
p_grav_max,p_ammo,p_lives
= 0,0,0,1,1,1,1,
		0,12,0,1.75,3,1,0.5,0,0.2,3,5,5

p_pass_tile,p_can_shoot,
p_shooting_anim,p_shooting_anim_timer,
p_grounded,p_moving = false,true,false,5,false,false

p_move_anim_frame,p_move_anim_timer,
p_move_sfx_flip,p_jumping,
p_jump_oomf,p_jump_oomf_pogo,
p_jump_oomf_max,p_pogo
 = 0,5,true,false,2,3.2,2.4,false

p_jumping_timer,p_jump_forgiveness,p_on_m_platform = 10,5
btnx_held,btnu_held,btno_held,btno_buffer = false,false,false,true

keys = {false,false,false,false}

-- ============================

-- player io control

-- ============================

function update_player()
	
	-- i,j pos and camera
	
	_b_up,_b_down,_b_left,_b_right = btn(⬆️),btn(⬇️),btn(⬅️),btn(➡️)
	
	pi,pir = to_ij(px),to_ij(px+7)
	pj = to_ij(py+4)
	
	local _down = p_grav < 0 and 0 or p_grav
	local _ydown = py+8+_down
		
	-- trigger a checkpoint
	
	for cp in all(checkpoints) do
	 if rect_pobj_8x8(cp) and not cp.on then
	  checkpoint_x,checkpoint_y,
	  active_text,at_timer = cp.x,cp.y,"checkpoint!",30
	  sfx(12) 

	  cp.on = true
	 end
	end

	-- trigger a level end
	
	if rect_pobj_8x8(exit) then
	 
	 sfx(12)
	 level_done = true
	 save_stats()
	 dset(level_num,1)
	 
	 return
	end
	
	-- enter / exit doors
	
	if (p_enter_door_timer > 0) p_enter_door_timer -= 1
	if p_enter_door then

	 if p_enter_door_timer <= 0 then
	  local _dest = find_door(p_on_door)
	 	px,py,p_enter_door,p_on_door = _dest.x,_dest.y,false
	 end
	 
	 return
	end
	
	------------------------------
	-- 				kill the player
	------------------------------
	
	if (py > tiles_yr) p_dead = true
	if p_dead then 
	
		-- on death trigger.
		
		if p_set_dead then
			
			p_lives -= 1
			save_stats()

			local rdx,rdy,rda,rdv
	
			for i = 1,10 do
				
				rdx,rdy = px+rnd(8),py+rnd(8)
				rda,rdv = rnd(1), rnd(2)
				
			 particle(rdx,rdy,rnd(5),14,5,rda,1)
			end
		
		 deady,dead_dy = py,-2

		 sfx(9)
		 p_set_dead = false
	
		-- keen style death jumps fx.
		
		else
		
			deady += dead_dy
			dead_dy = accel(dead_dy,0.1,8)
			
			-- restart at checkpoint
			
			if deady > cy+148 then
				dead_menu = true
				p_spd = 0
				dead_dy = 0
			end
			
		end
		return
	 
	end
	
	---------
	-- doors
	---------
	
	-- key gates.
	open_door_at(to_ij(px + (p_is_right and 8 or -1)),to_ij(py),true)

	-- passage doors
	local _on_door = false
	
	for k,d in pairs(doors) do
	 if rect_pobj_8x8(d) then
	 	_on_door = true
	 	if _b_up and p_grounded then
	 		p_enter_door,
	 		p_on_door,
	 		p_enter_door_timer,
	 		px = true,d,10,d.x
	 		sfx(13)

	 		return
	 	end
	 	break
	 end
	end
	
	---------------
	-- input buffer
	---------------

	local _b_pogo = stat(28,key_pogo)
	local _b_jump = stat(28,key_jump)
	local _b_shoot = stat(28,key_shoot)
	
	if (btnx_held and not _b_shoot) btnx_held = false
	if (btnu_held and not _b_pogo) btnu_held = false
	if (btno_held and not _b_jump) btno_held = false

	local _pogo = _b_pogo and not btnu_held and not p_hanging and not p_climbing
	local _shoot = _b_shoot and not btnx_held and not p_hanging
	local _jump = _b_jump and (not btno_held or btno_buffer)
	
	btno_held,btnx_held,btnu_held = _b_jump,_b_shoot,_b_pogo

	if (not btno_buffer and not btno_held or p_pogo) btno_buffer = true

	-- flip bg switches
	
	if btnp(⬆️) and p_grounded then
	  if (p_check_toggle(0,false)) p_enter_door_timer = 5
	end
			 
	-----------------------------
	-- 				apply gravity!
	-----------------------------
	
	-- local col for hazard blocks
	
	local _tl = tile_at(px+2,py+4)
	local _tr = tile_at(px+5,py+4)
	
	if is_hazard(_tl) or is_hazard(_tr) then
	 p_dead = true
	 return
	end


	-- pass through platforms

	local _pass_tile = is_platform(tile_at(px+6,py+8+_down)) or is_platform(tile_at(px+1,py+8+_down))
	if (_pass_tile and py+7 > to_tile(py+8+_down)) _pass_tile = false
	
	if p_pass_tile then
	 if (not _pass_tile) p_pass_tile = false
	 _pass_tile = false 
	end
	
	-- grounded?
	
	p_grounded = coll_at(px+1,_ydown,false) 
											or coll_at(px+6,_ydown,true)
											or _pass_tile or p_hanging or p_climbing
											
	-- moving platforms
	
	p_on_m_platform = nil
	
	for k,pl in pairs(m_platforms) do
		if not (px+6 < pl.x or px > pl.x+16)
		and py+7 <= pl.y and _ydown >= pl.y-1 then
		 	p_on_m_platform = pl
		 	p_grounded = true
		 	py_fall = py
		 break
		end
	end

	if p_on_m_platform != nil and not p_pogo then
	 py = p_on_m_platform.y-8
	 
	 set_dij(p_on_m_platform.dir)
	
	 if (p_on_m_platform.on and not coll_at(px+7,py+7) and not coll_at(px,py+7)) px += di

	end
	
	-- text boxes
	if tile_at(px+4,py+4) == 5 then
	 active_text,at_timer = level_text[rot_at(px+4,py+4)+1],60
	end
	
	-- get id + rotation of tile (ice,belt effects)
								
	local _on_tile = tile_at(px+7,_ydown)
	local _on_rot = rot_at(px+7,_ydown)
	if is_empty(_on_tile) then
	 _on_tile = tile_at(px,_ydown)
	 _on_rot = rot_at(px,_ydown)
	end
	
	-- ----------
	-- climbing!
	-- ----------
	
	if (p_climb_wait > 0) p_climb_wait -= 1
	
	
	-- set climbing state.
	
	if not p_climbing and p_climb_wait == 0 and btn(⬆️) and not _b_pogo and t_pole(tile_at(px+4,py+4)) then
	 p_climbing,p_pogo,
	 px,p_spd = true,false,to_tile(px+4),0
	end
	
	if p_climbing then
		
		-- move up / down poles if able.
	 if (_b_up and not coll_at(px+4,py-7) and t_pole(tile_at(px+4,py-1))) py -= 1
	 if (_b_down and not coll_at(px+4,py+8) and t_pole(tile_at(px+4,py+8))) py += 1 
	
		-- animations
		if _b_up or _b_down then
		 p_climb_anim_timer -= 1
		 if (p_climb_anim_timer <= 0) p_climb_anim_timer = 10 p_climb_anim = not p_climb_anim
		end
	end 
							
	if not p_grounded and p_on_m_platform == nil then
	
		-- ------------	
		-- apply grav.
		-- -----------
	
		if not p_jumping then
		 py += p_grav
		 p_grav = accel(p_grav,p_grav_a,p_grav_max)
	 end
	 p_jump_forgiveness = decel(p_jump_forgiveness,1)
	
		-- coll above
	
		if (coll_at(px+1,py-4) or coll_at(px+6,py-4)) then
			 
			 local _py = to_xy(to_ij(py-4))+8
			 if (py < _py) py = _py
			 p_jump_oomf = 0
			 if (p_grav < 1) p_grav = 1
			 
		end
		
		-- flip switches up.
		
		if p_jumping and (tile_at(px+1,py-4) == 139 or 
					tile_at(px+6,py-4) == 139) then
			 
				p_check_toggle(-1,true,false)
			 
			 p_jump_oomf = 0
			 if (p_grav < 1) p_grav = 1
		end
	
	--============================
	
	-- 				reset on ground.
	
	--============================
	
	else
	
	 -----------------------------------
		-- snap to block and handle slopes.
		-----------------------------------

		local _gpy = to_tile(py+_down)

		if not p_pass_tile and p_on_m_platform == nil then
		 	 
		 if py >= (py_fall + py_fall_trigger) and not p_pogo then
		  sfx(0,-1,0,4)
		  particle(px+(p_is_right and 1 or 6),py+7,3,7,2,0.25,1)
		 end
		 
		 if (not p_climbing and not p_hanging) py = _gpy
		 py_fall = py

		 -- breaker tiles.
	
			if _on_tile == 100 then
			 for k,b in pairs(breakers) do
			  if (b.i == pi or b.i == pir) and b.j == pj + 1 and b.state == 0 then
			   b.state,b.timer = 1,15
			   sfx(0,-1,0,16) 
			   particle(px+4,py+12,3,7,2,0.75,1)
			 	end
			 end
			end	
		
			-- flip switches down
			
			if _on_tile == 3 then
				p_check_toggle(1,true,true)
			end		 
				 
		end
		
		-----------------------------
	 -- snap to slope incline.
	 -----------------------------
	
		if tile_at(px+7,_ydown) == 112 and rot_at(px+7,_ydown) == 0 then
			py += 1 + (to_tile(px+7)-flr(px))
		elseif tile_at(px,_ydown) == 112 and rot_at(px,_ydown) == 1 then
			py += 1 + px-to_tile(px)
		end
	
		-- reset jump conds etc.
		
		p_jump_forgiveness = 4
		p_grav = 0
	 p_jumping = false
	 p_jump_oomf = 0
	 p_jumping_timer = 10
	 
	 -- fall through platforms
	 
	 if _b_down and _pass_tile and not p_pogo and not p_hanging then
	  p_grav = 1
	  p_pass_tile = true
	  py_fall = py-py_fall_trigger
	 end
	 
	 
	end

	-- ===========================
	
	-- 		move left or right!
	
	-- ===========================
	
 p_moving = _b_left or _b_right
 
 if (_b_right and not p_hanging) p_is_right = true
 if (_b_left and not p_hanging) p_is_right = false
 
 -- --------------------
 -- check if we can hang
 -- --------------------
 
 local _pdx = px + (p_is_right and 8 or -1)
 
 if p_moving and not p_pogo and not coll_at(px+4,py+12)
 							 and grab_at(_pdx,py)
 							 and not coll_at(_pdx,py - 2)
 							 and not p_grounded then
  
  p_hanging,p_pogo,p_spd,px = true,false,0,to_tile(px+4)
 
 end
 
 if _b_down and p_hanging then
	  p_hanging,py_fall,p_grav = false,py-py_fall_trigger,1
	end
	 	
 -- -------------
	-- not moving...
	-- -------------
	
	local _t_air,_t_icey = 
	_on_tile == 0 and p_on_m_platform == nil and not _pass_tile,
	_on_tile == 101 or _on_tile == 102
	
	
	if not p_moving then
	
		local _da = p_spd_d
		
		-- icey / conveyor
		if (_t_icey) _da = 0
		if (_t_air) _da = 0.05

		-- conveyor push
		if (_on_tile == 102) p_spd += (_on_rot == 0 and 0.2 or -0.2)


		if p_spd < 0 then
		 p_spd += _da
		 if (p_spd > 0) p_spd = 0
		elseif p_spd > 0 then
		 p_spd -= _da
		 if (p_spd < 0) p_spd = 0
		end
		
	-- -------
	-- moving!
	-- -------
	
	elseif not p_hanging and not p_climbing then
	
		-- accel player
		
		local _da = p_spd_a
		local _mxspd = p_spd_max
		
	 if (_on_tile == 101) _da = .05
		if (_t_air) _da = .25
		
		if _on_tile == 102 then
		 
		 local _w_dir = p_is_right
		 if (_on_rot != 0) _w_dir = not p_is_right
		 
		 _da = _w_dir and 0.5 or 0.02
		 _mxspd = _w_dir and p_spd_flung or 1
		end
		
		p_spd += _b_right and _da or -_da
		if (p_spd > _mxspd) p_spd = _mxspd
		if (p_spd < -_mxspd) p_spd = -_mxspd
		
	end
		
	-- check for collisions.
		
	local _spd_right = p_spd > 0
	local _pdx = px + p_spd + (_spd_right and 6 or 1)
	local _coll,_coll_head,_slope

	_coll = coll_at(_pdx,py,_spd_right) or
									coll_at(_pdx,py+6,_spd_right)
 
 _coll_head = coll_at(_pdx,py-2,_spd_right) 

 _slope = tile_at(_pdx,py) == 112
 									or tile_at(_pdx,py+7) == 112

 -- move if no colls!

	if (not _coll and not _coll_head) or
				(_slope and not _coll_head) then
	 px += p_spd
	 if (p_spd != 0 and _slope) py -= 1
	else
	 p_spd = 0
	end

 -- move animation
 
 if p_moving and p_grounded and not p_hanging and not p_climbing then
 	p_move_anim_timer -= 1
 	if p_move_anim_timer <= 0 then
 	 p_move_anim_frame += 1
 	 p_move_anim_timer = 6
			particle(px+(p_is_right and -1 or 8),py+7,1,13,3,0.25,0.25)
 
 	 if (p_move_anim_frame > 2)  p_move_anim_frame = 0
 	end
 end
 
 ------------------------------
 -- 							pogo + jump
 ------------------------------
 
 -- start pogo
	if (_pogo) p_pogo = not p_pogo
 
 -- start jump
 if (p_grounded or p_jump_forgiveness > 0) and _jump then
 	if (not p_jumping) sfx(1,-1,p_pogo and 8 or 0,8)
 	p_jump_oomf = p_pogo and p_jump_oomf_pogo or p_jump_oomf_max
 	p_jumping,p_grav,	
 	p_hanging,p_climbing,
 	p_climb_wait,btno_buffer
 	= true,0,false,false,10,false
 	
 	p_climb_wait = 10

 -- auto pogo
 elseif p_grounded and p_pogo then
  sfx(5)
  py -= 2
  p_grav = -1.25
 end  
 
 -- apply jump
 if p_jumping then
 	
 	-- timeout
 	if p_jump_oomf == 0 or (not btn(🅾️) and not p_pogo and p_jump_oomf <= 1) then
 	 p_jumping = false
 	 p_grav = 0
 	 py_fall = py-py_fall_trigger
 	end
  
  py -= p_jump_oomf
  p_jump_oomf = decel(p_jump_oomf,p_grav_a)
  p_jumping_timer -= 1
 end
 
 
 -- ---------------------------
 -- shooting!
 -- ---------------------------
 
 if _shoot then
  if p_can_shoot then 
  
  	p_can_shoot = false
  	p_shooting_anim = true
  	p_shooting_anim_timer = 15
  	local _dir = p_is_right and 3 or 1
  	
  	if (_b_up) _dir = 0
  	if (_b_down) _dir = 2
  	
  	if p_ammo > 0 then
  		
  		p_bullet(px,py - 2,_dir,false)
  		p_ammo -= 1
  	 sfx(2,1,0,8)
  	else
  	 sfx(4,1,0,4)
  	end
  end
 else
  p_can_shoot = true
 end
 
 if p_shooting_anim then
  p_shooting_anim_timer -= 1
  if (p_shooting_anim_timer <= 0) p_shooting_anim = false
 end
 
end

-- ============================

-- draw the player

-- ============================

function draw_player()

 -- exit sign
	
	if (t_flip) print_sga("exit",exit.x+4,exit.y-16,7,0)
	spr(238,exit.x-4,exit.y-8,2,2)

	-- body + face anims
	
	local _px,_py = px,py
	if (p_climbing) _px += p_is_right and -1 or 1
	
	local _s = p_moving and 209 + p_move_anim_frame or 208
	local _sf,_sla,_sra,_sbp = 1,241,243,227
	
	if (p_jump_oomf > 0 or p_jumping) _s,_sla,_sra = 245,244,246
	if (py >= py_fall + py_fall_trigger) _s,_sla,_sra = 215,228,246
	if (p_pogo) _s,_sla,_sra = 213,241,240 
	if (p_hanging) _s,_sla = 216,236
	if (p_climbing) _s = p_climb_anim and 219 or 218 _sla,_sra = 0,240

	if (level_done) _sf = 195 p_is_right = true
	
	-- draw body + gun + helmet


	
	if (_b_up) _sf = 192
	if (_b_down) _sf = 193
	if (p_enter_door_timer > 0) _sf,_s,_sla,_sra,_sbp =  196,217,232,234,0
 if (p_shooting_anim) _sf = 194
	if (p_dead) _py,_sf = deady,197
	
	local _dx = p_is_right and -8 or 8
 

	if (p_pogo) spr(p_grav < -1 and 230 or 229,px,_py+8,1,1,p_is_right)
	spr(_sla,_px-_dx,_py,1,1,p_is_right)
	spr(_sra,_px+_dx,_py,1,1,p_is_right)
	spr(_sbp,_px+_dx,_py-8,1,1,p_is_right)
	spr(_s,_px,_py,1,1,p_is_right)	
	spr(_sf,_px,_py-8,1,1,p_is_right) 

 if p_shooting_anim then
		local _sg = 54
		local _dx,_dy = p_is_right and 6 or -6,-2
		if (_b_down) _sg,_dy = 252,0 _dx /= 2
		if (_b_up) _sg,_dy = 253,-4 _dx /= 2
	
	 spr(_sg,_px+_dx,_py+_dy,1,1,p_is_right)
	end


end

-------------------------------
-- 					camera control
-------------------------------

cx,cy,ci,cj = 0,0,0,0

function set_p_camera()

 -- store camera x,y
 
 local _px,_py = px - 60,py - 60
 
 -- centre cam @ borders
 
 if (_px < 0) _px = 0
 if (_px > tiles_xr - 128) _px = tiles_xr - 128
 if (_py < 0) _py = 0
 if (_py > tiles_yr - 128) _py = tiles_yr - 128
 
 camera(_px,_py)
 
end 

function in_camera(x,y)
	return rect_in_rect(x,y,x+7,y+7,cx,cy,cx+127,cy+127)
end

checkpoints = {}

function checkpoint(x,y)
 add(checkpoints,{x=x,y=y,on=false})
end

function save_stats()
	if level_num != 0 then
	 dset(17,p_lives)
		dset(18,p_ammo)
		dset(19,score)
	end
end


-->8
-- interactibles ˇ

-- -----
-- doors
-- -----

doors = {}

function find_door(me)
 for d in all(doors) do
 	if (d != me and d.id == me.id) return d
 end 
end

function draw_doors()

	pal(11,0)
	
	local x,y
	for k,d in pairs(doors) do
	  
	  x,y = d.x,d.y
			spr(238,x-4,y-8,2,2)
			
	end
	pal()
end

-- ============================

-- player bullets

-- ============================

p_bullets = {}

function b_on_del(b)
	

	b.to_del = true
	if (in_camera(b.x,b.y)) sfx(6)
	
	local _c,_sz = b.is_enemy and 11 or 12,5
	for i = 1,2 do
		particle(b.x+4,b.y+4,_sz,_c,4,0,0)
		_c,_sz = 7,3
	end

end

function p_bullet(x,y,dir,is_enemy)
 add(p_bullets, {
 	x=x,y=y,dir=dir,ltime=60,
 	to_del=false,
 	is_enemy=is_enemy,
 	fxtimer = 0,
 	fxflip = true,
 })
end

function update_p_bullets()
 for k,b in pairs(p_bullets) do
 
 	-- timeout.
 	b.ltime -= 1
 	if b.ltime <= 0 or b.to_del then
 	 del(p_bullets,b)
 	else
 	
	 	local _dx,_dy = 0,0
	 	if (b.fxflip) particle(b.x+4,b.y+4,2,b.is_enemy and 3 or 2,2,0,0)
	 	b.fxflip = not b.fxflip
	 	
	 	-- move.
	 	
	 	local _spd = b.is_enemy and 4 or 5
	 	
	 	set_dij(b.dir,-_spd,_spd)

	 	b.x += di
	 	b.y += dj
	 	
	 	local x,y = b.x,b.y
	 	local xr,yr = x+7,y+7
	 	local _collided = false
	 	
	 	-- hit enemies or hit players
	 	
	 	if b.is_enemy then
	 		if rect_pobj_8x8(b,1) then
	 		 p_dead = true
	 		end
	 		
	 	else
		 	for k,e in pairs(enemies) do
		 	 if rect_in_rect(x,y,xr,yr,e.x-e.xo,e.y-e.yo,e.x+e.xr,e.y+e.yr) 
			 	and not e.dead then
			 	 if not e.immune then
				 	 e.hp -=1 
				 	 e.flashfx = true
				 	 e.flashfx_timer = 3
				 	end
				 	e.was_hit = true
				 	b_on_del(b)
				 	 
						break
			 	end
		 	end
	 	end
	 	
	 	-- collide.
	 	if coll_at(x+4,y+4) or
	 	  _collided then
	  		b_on_del(b)
	 	end
	 	
	 end
	end
end

function draw_p_bullets()
 for k,b in pairs(p_bullets) do
  spr(b.is_enemy and 223 or 207,b.x,b.y,1,1)
 end
end

-- ============================
--												 
-- ============================

score,score_to_life = 0,200
pickup_values,pickups = {1,2,5,10,20,50},{}

function update_pickups()

 for k,p in pairs(pickups) do

 	-- player pickup
 	if rect_pobj_8x8(p,1) then
 	 del(pickups,p)
 	 
 	 -- fx
 	 
 	 local _s,_d,_c = 4,2,7

 	 -- score
 	 local _offset = 0
 	 if p.id <= 6 then
				
				local _score = pickup_values[p.id]
				score += _score
				score_hint += _score
				score_hint_timer,score_flicker = 45,true
	 	 
	 	 if score > score_to_life then
	 	  score_to_life += 200
	 	  dset(22,score_to_life)
	 	  p_lives += 1
	 	  _offset = 16
	 	 end
	 	 
			-- ammo
 	 elseif p.id == 7 then
 	  p_ammo += 3
 	  _offset,_c = 8,12

 	 -- lives
 	 elseif p.id == 8 then
 	  p_lives += 1
 	  _offset,_c = 16,14

			-- keys
 	 else 
 	 	keys[p.id-8] = true
 	 	_offset = 24
 	 end
 	 
 	 if (p_ammo > 99) p_ammo = 99
 	 if (p_lives > 99) p_lives = 99
 	 particle(p.x + 4,p.y+4,_s,_c,_d,0,0) 
 		sfx(3,-1,_offset,8)
 	end
 end
end

gpal = {14,8,2}
gpals = {{11,3,1},{10,9,4},{12,13,1}}

function gem_pal(id)
	if (id == 0) return
 for i = 1,3 do pal(gpal[i],gpals[id][i]) end
end

pup_timer,pup_flash = 0,true
function draw_pickups()
	local _sp,x,y,_id
	
	-- update pupflash
	
	pup_timer -= 1
	if pup_timer < 0 then
	 
	 pup_flash = not pup_flash
	 pup_timer = 10
	end

	-- draw sprites.
 for k,p in pairs(pickups) do
 	
 	_id = p.id
 	_sp = 47 + _id
 	
	 pal()
	 if _id >= 9 then
	 	if (t_flip) pal(7,0)
	 	gem_pal(_id-9)
	 	_sp = 56
	 end

 	spr(_sp,p.x,p.y + (pup_flash and 1 or 0))
 	
 end
end

-->8
-- moving platforms / switches

m_platforms = {}

function draw_m_platforms()
	for k,p in pairs(m_platforms) do
	 spr(4,p.x,p.y)
	 spr(4,p.x+7,p.y,1,1,1)
	end
end

function update_m_platforms()
	for k,p in pairs(m_platforms) do
		
		if p.on then
			
			set_dij(p.dir)
	
			-- move!
		
			p.x += di
			p.y += dj
			
			-- collide and flip dir
			
			local _dx = di > 0  and p.x + 15 or p.x
			local _dy = dj > 0  and p.y + 7 or p.y
			if coll_at(_dx,_dy) or
			   tile_at(_dx,_dy) == 59 then
			 
			 p.dir += 2 
			 if (p.dir > 3) p.dir -= 4
			 
			end
		end
	end
end

-- switches

switches = {}

function p_check_toggle(dj,jumpon,v)
 for k,s in pairs(switches) do
		if (s.jumpon == jumpon and (pi == s.i or pi+1 == s.i) and pj + dj == s.j) toggle_switch_at(s,(v == nil and (not s.on) or v)) return true
	end
	return false
end

function toggle_switch_at(sw,on)
 sw.on = not sw.on
 
 local _son = sw.jumpon and 139 or 159
 local _soff = sw.jumpon and 3 or 7
 
 tiles[sw.i][sw.j] = on and _son or _soff
	sfx(14)
	for f in all(switches[sw.id]) do f() end
end


 

-->8
-- enemies + hazards! 🐱

enemies,turrets = {},{}


function enemy(x,y,id,facing,r)
 local e = {
 
  x=x,y=y,id=id,
  
  xo=0,xr=7,
  yo=0,yr=7,
  
  dangerous = true,
  revives = false,
  hp=1,
  vflip=r==2,
  slug_fall = false,
  right = facing,
  spd = 1,
  was_hit = false,
  dead = false,
  dead_anim_fx = 0,
  anim=0,anim_timer = 8,
  anim_timer_max = 3,
  flashfx = false,
  flashfx_timer = 4,
  flashfx_max = 4,
  chase_timer = 30,
  wait_timer = 30,
  wait_timer_max = 60,
  attacking = false,
  dir = facing and 3 or 1,
  wiggler_ignore = false,
  jumper_jumps = 3,
  immmune = false,
  shots = 1,
  shots_max = 1,
  grav = 0,
  deathfloat = true,
 }
 

 if (or_many({2,9,7},id)) e.yo = 8
 if (e.id == 1) e.anim_timer_max = 10 e.spd = 0.33
 
 if (id == 2) e.hp,e.spd,e.revives = 1,2,true
 if (id == 4) e.anim,e.revives = y % 3,true
 if (id == 5) e.dir,e.hp = r,2
 if (id == 6) e.immune,e.dir = true,r
 if (id == 7) e.hp,e.shots_max,e.shots,e.wait_timer_max = 8,3,3,10
 if (id == 8) e.spd,e.dangerous = 1.5,false

 add(enemies,e)
 
end

-- update all enemies

function update_enemies()
 for k,e in pairs(enemies) do
	 
	 local _dead = e.dead
	 
	 if e.revives and _dead then
	 	
	 	if (e.chase_timer <= 15) e.flashfx,e.flashfx_timer = not e.flashfx,3
	 	e.chase_timer -= 1
	  if (e.chase_timer <= 0) e.dead = false e.hp = 1
	 end	 
	 	 
	 if e.flashfx then
		 e.flashfx_timer -= 1
		 if (e.flashfx_timer <= 0) e.flashfx = false
		end
		
		if _dead and not coll_at(e.x+4,e.y+8) and e.id != 4 then
		 e.y += 1
		end
	 
	 if not _dead then
	 
		 -- die!
		 if e.hp <= 0 then
		 	e.chase_timer,e.dead = 50,true

		  sfx(7)
		 end
		 
			-- ====================
			
			-- all enemies in one!?
			
			-- ====================
			
			enemy_ai[e.id](e)
			
		
		 -- collide with player
		 
		 if e.dangerous and not p_enter_door and rect_pobj_8x8(e,1) then
		  p_dead = true
		 end 
		 
		 -- animate
		 
		 e.anim_timer -= 1
		
		 if e.anim_timer <= 0 then
		  e.anim_timer = e.anim_timer_max
		  e.anim += 1
		  if (e.anim > 2) e.anim = 0
		 end
	 
	 	e.was_hit = false
	 	
	 end
 end
end

-- draw all enemies

function draw_enemies()

 for k,e in pairs(enemies) do
  
  -- draw spr
  
		pal()
  if e.flashfx then
   for i = 0,15 do pal(i,7) end
		end
  
  enemy_draw[e.id](e)

  -- draw death halo
  
  if e.dead then
  	e.dead_anim_fx += 0.05
  	if (e.dead_anim_fx > 1) e.dead_anim_fx = 0
  	
  	local _x,_y = e.x + 4,e.y-e.yo - 6
  	local _cos,_sin = 4*cos(e.dead_anim_fx),2*sin(e.dead_anim_fx)
   circ(_x + _cos,
   					_y + _sin,1,7)
   pset(_x - _cos,
   					_y - _sin)
  end
 end
 pal()
end

-- enemy ai + draw scripts

function enemy_move(e,slopes)

	-- move about
	
	if e.chase_timer > 0 then
	 e.chase_timer -= 1
	end

	local _x = e.x + (e.right and 8 or -1)
	local _on_slope = false

	-- snap to ledges
	
	if slopes then
	
		if slope_at(e.x+7,e.y+8) and rot_at(e.x+7,e.y+8) == 0 then
			e.y = to_tile(e.y) + 1 + (to_tile(e.x+7)-flr(e.x))
		elseif slope_at(e.x,e.y+8) and rot_at(e.x,e.y+8) == 1 then
			e.y = to_tile(e.y) + 1 + flr(e.x)-to_tile(e.x)
		else
		 e.y = to_tile(e.y+4)
		 if slope_at(e.x,e.y) and rot_at(e.x,e.y) == 1 or 
		  		slope_at(e.x+7,e.y) and rot_at(e.x+7,e.y) == 0 then
			 e.y -= 1
		 end
		end
		
	end
	
	local _ds = e.right and 1 or -1
	local _on_slope = slope_at(e.x+7 + _ds,e.y+8) 
																or slope_at(e.x + _ds,  e.y+8)
	
	if (not slopes) _on_slope = false
	
	local _below = e.vflip and -1 or 8
	local _coll_below = coll_at(_x,e.y+_below) or tile_at(_x,e.y+_below) == 114
		
	if (coll_at(_x,e.y+4) or not _coll_below or tile_at(_x,e.y+4) == 59) and not _on_slope then
		 e.right = not e.right
	else
	 	e.x += e.right and e.spd or -e.spd
	end

end

function enemy_slug(e)

 if e.vflip and in_range(py,e.y,e.y+54) and in_range(px,e.x-5,e.x+5) then
  e.slug_fall,e.vflip = true,false
  sfx(4,-1,16)
 end
 
 if not e.slug_fall then
  enemy_move(e,false)
 else
  e.y += 2 
  if coll_at(e.x,e.y+9) then
   e.slug_fall,e.y = false,to_tile(e.y)
  end
 end
end

function can_see_player(e,right,sd)
				
		local _ex,_sd = e.x,sd
		
		while _sd > 0 do
		 _ex += right and 8 or -8

		 if (rect_pobj_8x8({x=_ex,y=e.y})) return true
			if (coll_at(_ex,e.y)) return false	
		 _sd -= 1
		end
		
		return false
		
end

function enemy_chaser(e)

	if not e.flashfx then

		enemy_move(e,true)
		
		-- can we see player?
			
		if not p_dead and can_see_player(e,not e.right,6)
			  and e.chase_timer == 0 then
		 e.right = px > e.x
		 e.chase_timer = 10
		end
		
	end
end

function enemy_eye(e)

	-- move!

	local _dx = e.right and 8 or -1
	
	if coll_at(e.x + _dx,e.y) or tile_at(e.x + _dx,e.y) == 59 then
	 e.right = not e.right
	end
	
	if (not e.attacking) e.x += e.right and 0.5 or -0.5

	-- sight : direction
	enemy_shoot_n_see(e)

end

function enemy_shoot_n_see(e)

		if (e.wait_timer > 0) e.wait_timer -= 1

	if can_see_player(e,e.right,6) and abs(e.y - py) <= 8 
	and not e.attacking and not p_dead and e.wait_timer == 0 then
	 e.attacking,e.chase_timer = true,20
	 sfx(8)
	end
	
	if e.chase_timer > 0 and e.attacking then
	 
	 e.chase_timer -= 1
	 
	 if e.chase_timer == 0 then
	  e.shots -= 1
	  p_bullet(e.x,e.y ,e.right and 3 or 1,true)
	  sfx(10)
	  if e.shots == 0 then
		  e.attacking,e.wait_timer,e.shots = false,e.wait_timer_max,e.shots_max  
	  else
	  	e.chase_timer = 5
	  end
	 end
	end

end

-- wigglers

function enemy_wiggler(e)
		
	local _dir = e.dir

 set_dij(_dir)

	e.x += di
	e.y += dj

	local x,y = e.x,e.y
	
	-- coll offset.
	
	if (not axis) di,dj = -di,-dj
	
	-- reversed direction.
	
	if not e.right then
	 _dir -= 1
	 if (_dir < 0) _dir = 3
	 di,dj = -di,-dj
	end
	
	-- move until wall or empty
	
	local _dx,_dy = _dir >= 2 and 0 or 7,
 															 (_dir == 0 or _dir == 3) and 7 or 0
	
	local _t = tile_at(x+_dx+dj,y+_dy+di)
	local _coll = coll_at(x+7-_dx,y+7-_dy)
	
	if (is_empty(_t) and _t != 30) or _coll then
	 
	 if (_coll) e.wiggler_ignore = false
	 
	 if not e.wiggler_ignore then
	 	local _v = e.right and 1 or -1
		 e.dir -= _coll and -_v or _v		 
		 e.dir = e.dir % 4
		 e.wiggler_ignore = true
		 
	 end
	else
	 e.wiggler_ignore = false
	end 

	if e.was_hit and e.hp == 0 then
		particle(x+4,y+4,4,7,2,0,0)
	end

end

-- jumpers

function enemy_jumper(e)

	if e.was_hit then
	 e.jumper_jumps = 1
	end

	if coll_at(e.x+4,e.y+8+e.grav) or e.was_hit then
	 e.jumper_jumps -= 1
	 if (e.jumper_jumps < 0) e.jumper_jumps = 3
	 e.grav = e.jumper_jumps == 0 and -2 or -0.5
	 
	 e.y -= 1
	else
	
	if (coll_at(e.x+4,e.y-1)) e.grav = 1
	 
	 local _dx = e.right and 8 or -1
	 
	 if (coll_at(e.x + _dx,e.y)) e.right = not e.right
		e.x += e.right and e.spd or -e.spd
	 
	 e.y += e.grav
	 e.grav += 0.1
	 if (e.grav > 2) e.grav = 2
	end
	
end

function enemy_squisher(e)
		
	set_dij(e.dir)
	
	e.x += di
	e.y += dj
	
	if coll_at(e.x+di,e.y+dj) or
				coll_at(e.x+7+di,e.y+7+dj) then
		e.dir += 2
		e.dir %= 4
	end

end

function enemy_doombot(e)
 if (not e.attacking) enemy_chaser(e)
 enemy_shoot_n_see(e)
end

function draw_e_with(dead,body,angry)
 return function(e)
  
  local x,y,id,r,anim = e.x,e.y,e.id,e.right,e.anim
 
  local _face,_body = (anim == 0 or or_many({3,5,6,9},id)) and (id + 36) or (143 + anim + (id - 1)*3),body
 	if (e.attacking) _face = angry
 	
 	if (id == 3 and not e.dead) y = y + 2*sin(x/16)
  if (id == 3) spr(150 + anim,x + (r and 4 or -4),y,1,1,not r)
  if (e.jumper_jumps == 0) _face = 188
  
  if (e.slug_fall) _face = 135
  spr(e.dead and dead or _face,x,y-e.yo,1,1,r,e.vflip)
  
  if (id == 2 or id == 9) _body += anim
  if (id == 3) _body = 150 + anim x += r and -8 or 8
  
  if id == 5 then
   if (e.dead) _body = 191  
   y -= 8  
  end
    
  spr(_body,x,y,1,1,r)
  
  if id == 7 then
  	local _gun = e.dead and 186 or 185
		 spr(_gun,x + (r and 6 or -6),y-1,1,1,r)

  end
 end
end

function enemy_pusher(e)
 enemy_chaser(e,true)
 if rect_pobj_8x8(e,-1) then
  p_spd = e.right and 3 or -3
 end
end

function enemy_grey(e)
 enemy_move(e,true)
 local _see = can_see_player(e,e.right,6)
 
 if _see then
  e.chase_timer = 20
	end
 
 _see = _see or e.chase_timer > 0
 
 e.spd = _see and 1.33 or 1
 e.attacking = _see
  

end

-- ===========================

-- 									turrets 

-- ===========================


turret_timer = 60

function update_turrets()
	
	-- global timer
	turret_timer -= 1
	if (turret_timer < 0) turret_timer = 60
	
	local _any_shot,_sx,sy = false

 for k,t in pairs(turrets) do
 
 	-- turret in view?
 	
  if turret_timer == t.shooton then
 		
 		-- fire a bullet!
 		if (in_camera(t.x,t.y)) _any_shot = true

	 	set_dij(t.dir,-8,8)
	 	_sx,_sy = t.x+di,t.y+dj

	  p_bullet(_sx,_sy,t.dir,true)
 	end
 end 
 
 if (_any_shot) sfx(10)
end

-- ===========================

-- 									beamers

-- ===========================

beamers = {}
beamer_timer = 1

function beamer_toggle(b)
 b.on = not b.on
 
 set_dij(b.dir)

 -- remove or add zappers.
 local _to_add = b.on and (axis and 32 or 31) or 0
 local _search = true
 local _i,_j,_t = b.i + di, b.j + dj
 
 while _search do
 	tiles[_i][_j] = _to_add
 	_i += di
 	_j += dj
 	_t = tiles[_i][_j]
  _search = _t == 0 or _t == 31 or _t == 32
 end
end

function update_beamers()
	
	beamer_timer -= 1
 if beamer_timer == 0 then
  beamer_timer = 40
 else return end

 for k,b in pairs(beamers) do
 	if b.timed then
 		beamer_toggle(b)
 	end
 end
end
-->8
-- ui, score, text, particles ✽

function print_shadow(t,x,y,c,s)
 print(t,x,y+1,s)
 print(t,x,y,c)
end

function print_centre(t,x,y,c,s)
 print_shadow(t,x - (#t*2),y,c,s)
end

function print_sga(t,x,y,c,s)
 poke(0x5f58,0x1 | 0x80)
 print_shadow(t,x - (#t*3),y,c,s)
 poke(0x5f58,0)
end

function print_title(t,t2,bg)
 local _sx,_sy = 48,16
 local _x,_y,_xr,_yr = 64-_sx,32-_sy,64+_sx-1,32+_sy+4-1
 rectfill(_x-1,_y-1,_xr+1,_yr+1,0)
 rect(_x,_y,_xr,_yr,7)
 
 local _dy = #t2 != 0 and 4 or 0
 
 print_centre(t,64,32-_dy,7,1)
 print_centre(t2,64,40-_dy,bg,1)
 
end

score_flicker,score_flicker_timer,
score_hint,score_hint_timer,
active_text,at_timer = false,4,0,60,"",60


function draw_ui()

	-- active text
	
	if #active_text != 0 then
		rectfill(2,16,125,40,0)
		rect(2,16,125,40,13)
	 print_centre(active_text,64,24,7,1)
	 print_sga(active_text,64,31,1)
	end
	
	if at_timer > 0 then
	 at_timer -= 1
	 if (at_timer <= 0) active_text = ""
	end

 -- ------------
 -- lives + ammo
 -- ------------

 spr(1,2,2)
 spr(54,118,2)
 print_centre(tostr(p_ammo),114,3,11,1)
 print_centre(tostr(p_lives < 0 and 0 or p_lives),15,3,11,1)
 
 -- -----
 -- score
 -- -----
 
 if score_hint_timer == 0 then
  score_hint = 0
 else  score_hint_timer -= 1 end
 
 local _c,_s = 7,1
	local _slen = #tostr(score)
	
	_x = 50
	
	rectfill(_x,2,_x + 26,7,0)
	
	-- hint
	
	if score_hint > 0 then
 	print_shadow("+" .. score_hint .. "00",_x + 16 - 4*#tostr(score_hint),9,7,0)
 end
 
 -- bg zeros
	
	for i = 1,5-_slen do 
		print_shadow("0",_x,2,_c,_s)
		_x += 4
	end
	
	local _y = score_flicker and 3 or 2
	
	if score > 0 then
	 _c,_s = 9,2
	end
	if (score_flicker) _c,_s = 14,7
	
	print_shadow(score,_x,_y,_c,_s)
	_x += 4*_slen
	
	for i = 0,1 do print_shadow("0",_x+(4*i),_y,_c,_s) end
	score_flicker = false

end

particles = {}

function particle(x,y,s,c,dm,a,v)
 add(particles, {
 	x=x,y=y,
 	size=s,colour=c,decay=dm,decay_max=dm,
 	angle=a,speed=v
 })
end

function update_particles()
 for k,p in pairs(particles) do
 	
 	-- move about
 	p.x += p.speed * cos(p.angle)
 	p.y += p.speed * sin(p.angle)
 	
 	-- decay out and fizzle.
 	p.decay -= 1
 	if p.decay <= 0 then
 	 p.size -= 1
 	 p.decay = p.decay_max
 	 if (p.size < 0) del(particles,p)
 	end
 end
end

function draw_particles()
 for k,p in pairs(particles) do
 	circfill(p.x,p.y,p.size,p.colour)
 end
end




-->8
-- init,update,draw.

-- 0 = overworld
-- 1 = level
-- 2 = game over

dead_menu,level_done,
game_state,transition_timer
= false,false,0,60

level_text = {"z to jump","x to shoot!","up to grab poles","c to pogo", "a locked door hmm", "up to interact"}

-- ============================

-- loading helpers.

-- ============================

function loader(msg)
 load("picokeen",0,msg)
end

function _init()

 -- missing cart 1 failsafe.
 music(0,10000,12)
 level_num = tonum(stat(6))
 
	if (level_num == nil) loader("warning")


	cartdata("dukki0_picokeen_data")
	
	poke(0x5f2d,1)

	enemy_ai = {enemy_slug,enemy_chaser,enemy_eye,enemy_wiggler,enemy_jumper,enemy_squisher,enemy_doombot,enemy_pusher,enemy_grey}
	enemy_draw = {
	draw_e_with(146),
	draw_e_with(149,176),
	draw_e_with(156,0,155),
	draw_e_with(157),
	draw_e_with(189,190),
	draw_e_with(),
	draw_e_with(183,184,182),
	draw_e_with(167),
	draw_e_with(168,179,169)}
	
	-- conversion table for symbols.
	
 for i = 1,#symbols do 
  b_to_c[i] = sub(symbols,i,i)
 end

	-- load in maps!
	
	init_map()
	
	if level_num != 0 then
		p_lives,p_ammo,score,score_to_life
		= dget(17),dget(18),dget(19),dget(22)
	end
end

function _update()
	
	if not level_done then
	 	
	 update_player()
	 update_particles()
	 update_tiles()
	 update_m_platforms()
		update_p_bullets()
		update_enemies()
		update_turrets()
		update_beamers()
		update_pickups()
			
		-- camera values.
		cx,cy = peek2(0x5f28),peek2(0x5f2a)
		ci,cj = to_ij(cx),to_ij(cy)
			 
 else
		 
		-- return to ow
		  
		transition_timer-= 1
		if (transition_timer <= 0) dset(level_num,1)  loader(level_num == 0 and "menu" or "map")
	 
 end
end

function _draw()
 cls()
 
 --camera(0,0)
	--memcpy(0x6000,bg_image_addr,8192)
 -- border
	 
	set_p_camera()

	draw_tiles()
	draw_pickups()
	draw_p_bullets()
	draw_doors()
	draw_m_platforms()
	draw_enemies()
	draw_particles()

	pal()
	draw_player()
	 
	camera(0,0)
	 
	-- border
	rect(0,0,127,127,1)
	 
	draw_ui() 

	if level_done then
	 print_title("level complete","")
	end
	
	-- death menu
	if dead_menu then
		print_title("press 🅾️ to continue","press ❎ to exit",13)
		
		if btnp(🅾️) then
			px,py,dead_menu,p_dead,p_set_dead = checkpoint_x,checkpoint_y,false,false,true
		elseif btnp(❎) or p_lives < 0 then
			 loader("dead")
		end
		
	end
	
	set_p_camera()

end
__gfx__
0000000002eeee20cccccccc999940002dddddddcccccccc88888888d677776d0000000003313310055544403133133033133133011110000555444013311133
000000002eeeeee0cccc7ccc9aa99400d6666666c7777c7c8788787866666666000000003bb5bb500545454244bb4bb33b3bb3bb133b3110051544403bb313bb
00000000efeefee2cccc77cc4999994026666666cccccc7c888888786282111600000000bbb3bb510555454444bb3bbbbb3bb4bb3bb313b1055542403bb133b3
00000000efeefee6c777777c2499999412222222c7777ccc8788787868f8d116000000003bb3bb351555444403bb3bb3bb3bb33b3bb3b330015544403bb3b33b
00000000eeeeeee211116611d249999900222222ccc7cc7c22626222d888d11d000000000bb335355555454003033bb03b5bb4b333b3bb30015542203b31b3bb
00000000de2dee6611116111d622222400000099cccccccc22626262d282111d00000000000330005545444000033000b33bb4330030330015114222133bbb33
00000000d22dd666111111110ddddddd000000000001d00022222222dddddddd000000000000000005454440000000005b3543300000000015124242001bb000
00000000022dd66100011000000000000000000001dd6610000220001d6666d10000000000000000055544400000000005554440000000001552124200000000
88ff88ff88ff88ff88888820122288ff88ff22211111111101010101666101010101010121212121eeeeffff222222222222222200070000028aa820001ccc10
8fff8fff8fff8fff8888888212128fff8fff212122222222101010106067767066d6d61212121212effef77f2ffffff22e2222e200b00330289aa98201ccc110
fff8fff8fff8fff88888f8881212fff8fff8212121111112010101016661016166d6d62221212121effef77f2ffffff2222222220bb7063389a77a9801cc1100
ff88ff88ff88ff8888888f881212ff88ff88212122222222101010101d10106066d6d61212121212eeeeffff2ffffff2222222220ab10013aa7777aa01ccc110
112211222222222222288888121288ff88ff212188ff88ff010101010d01016101010101212121212222eeee2ffffff2222222220ab361d3aa7777aa011ccc10
12221222211111121122888812128fff8fff21218fff8fff1010101016101ddd206d6d66121212122ee2effe2ffffff2222222220bbb101389a77a980011cc10
2221222122222222221288881212fff8fff82121fff8fff8010101010d666d0d226d6d66212121212ee2effe2ffffff22e2222e213bbb331289aa982011ccc10
2211221111111111121288881222ff88ff882221ff88ff881010101010101ddd206d6d66121212122222eeee222222222222222211333311028aa82001ccc100
00000000003bb3000000dd6d00c77c00011061dd170710000bbbbba06d00001d0c00cc007cc33cc7600d60d60066770000200e00066666600000000000000000
1101111000b82b0000666dd61c7777c10cc1767d71017490b177177bd666676100cc77707c133c17d6266d600d0000600e02e000116661110000000000000000
c111ccc1063283603bb366d61cc77cc1c7cc767d09992229a1161773655555760ccc7c70317331730dd77d2060011007e7eee000171617110000000000000000
cc1ccccc06133160b82b66d601cccc10777c767d9aaa2424b111117b65f5f566c777777c333333336671076160cc770707e7e0e0171617110000000000000000
ccccc1cc0d6666d03283dd1d7666777d777c6161aaaaa4243772211365f5f566c7c7cccc14999f911d6016dd600110068ee7e00e6116111d0000000000000000
1ccc111c01dddd101331dd1d01dddd10c7cc6161a292a242367176336555556d0777ccc0bbb4994b02166110607cc706eeeeeeee6666666d0000000000000000
011110111d1111d100ddd1d1166677710cc161619aaa992933737733d66666d100cccc0cbbbb44bb0d1dd2d1d001100d0eeeeeeed16161dd0000000000000000
0000000011dddd110000111111dddd110110d0110999999003333330001111100c0cc0001b1b0b1bd10d100d1077cc010f0f02020d1d1dd00000000000000000
0028e800a004909a40f77f00013b33100882000000a7a0000000080002eeee2007777700000000000000000008888880011111103b7777b3dcc00ccd28800882
000120000a4949a908e777f013333b312888000009aaa77000008e062eeeeee078eee87000000000000000008882222810000001b777777b777077cca8a0aaa8
00d4460009a99a9002877f703b33333988a824007699aee0c1c88880eefefee27eeeee8700000000000000008288000810000001b77dd77bc700707ca8a0a0a8
065494700a9929200d4ff7f0333b331228a8a8429777eff8c8c88888efeeefe67eed1ee7000000000000000080288008100000010ddd777007007070aaa0aaa0
00d54600022e2ee00d6dff6091331998448a8a88477ef824c1c2888288ee88e27881d887000000000000000080028808100dd001000666d00600606099909900
0d5454600222eee0016df41029aa988344488a88942f824900006288de2dee66788888870000000000000000800028881022220133011133d600606d92909092
001d6d000122ee200001d000128992312444448249422494000d0288d22dd66672d66d270000000000000000288888821dddddd133366333666066dd92909292
000000000011221000dd6600033a3310024444200494900000000000022dd6610777777000000000000000000222222022222222133113311dd00dd112200221
dddddddd7777777777dddddd077777777777777777dddd77077777770777777007777770dddddddddddddddddddd666d77777d77d777777d77d77777d7d7777d
dddddddd7777777777dddddd777777777777777777dddd77777777777777777777777777dddddddddd66ddddddd666667777d777d777777d777dd7777ddd77dd
dddddddddddddddd77dddddd777ddddddddddddd77dddd77777ddddd777dd777777dd777ddddddddd6666dddddd66666d777dddddd7777dddddddddddddddddd
dddddddddddddddd77dddddd77dddddddddddddd77dddd7777dddddd77dddd7777dddd77ddddddddd6666dddddd66666ddddd77dddd777dddddddddddddddddd
dddddddddddddddd77dddddd77dddddddddddddd77dddd7777dddddd77dddd7777dddd77dddddddddd66dddd66dd666dddddddddd7dddddddddddddddddddddd
dddddddddddddddd77dddddd77dddddddddddddd77dddd77777ddddd77dddd77777dd777ddddddddddddd66d666dd66ddddddddddddddddddddddddddddddddd
dddddddddddddddd77dddddd77dddddd7777777777dddd777777777777dddd77777777777dddddddddddd66dd66ddddddddddddddddddddddddddddddddddddd
dddddddddddddddd77dddddd77dddddd7777777777dddd770777777777dddd770777777077dddddddddddddddddddddddddddddddddddddddddddddddddddddd
444444444200002444ff4422004994000049940000099000d666d6dd0111111000000000000b3000000b300007000776b13171b17171b171d66ddd6d11111111
4f4444f44444444424ff44210049940000499400009aa9006f6d6d222222222201111110000b3133b30b300077707777d317d717131713176666dddd18888881
44444444ffffffff04ff44200049940000499400009aa900f6d6d22eeee7eee722202220000b33b33b0b30007773677d1d1d3d3dd13d313d66666ddd18111111
44444444ffffffff04ff44200049940000499400009aa90066d6d2e22272227211011101bb1b3b3301bb330bd77aa3d0dddd3dddddd3ddddd6666d6618888881
222222224444444404ff4420004994000024420000499400dd1d12e22f222f2210111011b3bb33310bb3b3310d3aa670ddddddddddddddddd6ddd66618888881
222222224444444404ff4420004994000024420000499400dd1d122efeeefeee02220222bb3b31000bbb3d1306763777ddddddddddddddddddd6666611111181
242222422222222224ff44210049940000244200004994001dd1d12222222222011111103bbb3000d3bbd6d177771677ddddddddddddddddddd666dd18888881
222222222100001244ff442200499400000220000049940011dd1d110111111000000000003b30003d3d6ddd677b3d70dddddddddddddddddddddddd11111111
2ffffff2088118800881188066667777066d006d67777776066d066d0000000000000000c000000cc000000c7777777700770777c000000c0000000000000000
4ffffff428e22e822888888267667767d666d66677777c77d666d6660000000000000000c000000cc000000c0000000007000000c00000000000000000000000
44ffff448e8228e88610d6d86666777766676d6d77c777c75ddd5ddd0000000000000000c000000cc000000c0000000070000000c00000000000000000000000
444ff444288228822d006d62666d6777d6666d0d777c7777222222220000000000000000c000000cc000000c0000000070000000c00000000000000000000000
44422444088118800d10d6d0ddd1d6660d660166cccc1ccc111111110000000000000000c000000cc000000c0000000000000000c00000000000000000000000
4422224428e22e8228222282dddd666610101d66c1ccc1cc111111110000000000000000c000000cc000000c0000000070000000c00000000000000000000000
422222248e8228e822888822d1dd66d6016106d1cc1ccccc2222222200000000000000001c0000c1c000000c00000000c00000001c0000000000000000000000
122222212882288212222221dddd6666001010001cccccc1dd10dd10000000000000000011cccc11c000000cccccccccc000000c11cccccc0000000000000000
000000071dddddd11dddddd000000001111111110111111000000000110000110011110000000000000000000000000001111110111111110000000000011000
00000077d666777dd666777d00000011111111110011110010000001111001110011110000011100000000000000000001000010100000010000011000111100
000007771dddddd11dddddd100000111111111110011110011111111011011101111101100111100000000000000000010100101101101010000011001111110
0000777d122222210011220000001111111111110011110011111111000111001111111100111100000000000000000001100110100000010000011001111110
000777dd211111120000000000011111111111110011110011111111001110001111111101111100011000000000000001111110100000010111111000101000
00777ddd111111110000000000111111111111110011110011111111011101101101111111111110111101100000000001000010111111110100011000001000
0777dddd111111110000000001111111111111110011110010000001111001110011110011111111111111110111000010100101000110000110011000001000
777ddddd111111110000000011111111111111110111111000000000110000110011110011111111111111111111101001100110011111100111111001111110
d066d0666d066d0666d066d00d66d66600d66d66000d66d6000dd66d004999900000000000eee22000000000000000000000000000000700028aa821128aa820
6d666d6666d666d6666d666d0666566605666566065666560665666504222299000000000e777222000000000ddddddd00000000000bb000289aa98228977982
d5ddd5dddd5ddd5dddd5ddd505dddddd66dddddd66ddddddd66ddddd02449429000000000e7e722200000000d649aaaaddd0000000bab73089aaaa9889777798
22222222222222222222222266d2662266d2662266d266225dd2662224224924000000002e7e722200000000d49aaaa91d67000000abb330aaa77aaaa777777a
11111111111111111111111166261d61d626d1615d261d616626d1612424424400000000eeeee2220000000049aaaa921d76000000bb3630aaa77aaaa777777a
111111111111111111111111d626d161d5261d610d26d16166261d6124422442000000000eeeeee0000000009aaaa920ddd0000001bb333089aaaa9889777798
22222222222222222222222205d2662200d2662206626622d652662212444420000000000220220e000000009999920011000000113b3331289aa98228977982
d10dd10d10dd10ddd10dd10d000dddd00006dd0d006dd0dd00000ddd00122200000000000020020000000000222220000000000011133311128aa820028aa821
0000000000000000017000000bbbbba00bbbbba00bbbbba0000ff00000000000000000000c000cc000c0cc006d00001dd1000d66000d000dccccccccd677776d
000000001707100007100710bb7667bbbb66bbbbbbbbbbbb00f7f000000000000000000000cc777c00cc7770d67777611d6666d000000dd07c7cc7c766666666
1707149079997440c1900170a776177ba766bbb7abb6371b2f7ff00022200000221110000ccc7c7ccccc7c7c6921237666111116d0dddcdc7c7cc7c761113b36
799972299aaa249409aa991cb112211b11117617b73611712ffff0002f7fff002111100007777770c777777c7a8ceb76d1555f5d0cdcddc0c77cc77c611dbab6
9aaa2424aaaaa4290aa2aa903616d16373337331b7111113ffff0000ffffff00ffff0000c7c7ccc0c7c7ccc07a8ceb76d5f555fd0dcddcdc11111111d11dbbbd
aaaaa424a292a2440a2a2aa433b6db333333333331111ed3f1110000ffff1000ff77f000c777ccc00777ccc06921236ddf5555dd0cdcdd0011d11d11d1113b3d
a292a2429aaa99422aaaaa923333333333333333136efe3321111000211110002fffff00cccccc000cccccc0d77776d1ddddddd10d0d0000111dd111dddddddd
9aaa9929099999209999a9aa03333330033333300333ee300211100002200000022000000cc0000c00ccc0c00011111001111110000000d0000110001d6666d1
00000000000000000066770000667700000000000002ee0000000000000000000066666006666660000000000000000000000000000000000000000000000000
00000000000000000d0000600d0000600000000007eee0000020e00000200e001176711011d6d11d000000000000000000000000000000000000000000000000
000000000000000060011007600110070000000007e7e0e00002e0000002e000171d1711711611710000000000000000000e2e0000000000000000000000e000
0000000000000000607cc7076077cc0700000000eee7e00e07eee00007eee000711d11711716171100000000000000000b32e20000000000000b000b000e2e00
0000000000000000600110066001100600000000eeeeeeee07e7e0e07ee7e0e0611611116116111d000000000000000003b12e0000000b00b00030300032e2b0
00000000000000006077cc0660c77c060000000088effeeeeee7e00eeeee700e6666111d666666dd0000000000000000003b30000000beb00300030300033b00
0000000000000000d001100dd001100d00000000880f220288eeeeeeee1eeeeed666dd6dd16161dd00000000000000000103b0030b0003003031013003013003
000000000000000010c77c01107cc70100000000f000020288eeeeee21e1e2ee0d61ddd00d111dd0000000000000000013100130030313101310131101303031
000110000001100000011000000ddd00000ddd00000ddd0000667700000000000d1111d00110000000100000000000007c7337c77cc331220000000000000000
000330000003300000033000000dddd0000dddd0011ddd000d000060000000000222555010011000000110000000000071c33c1712233cc70000000000000000
033333300333333003333330000dd66d011ddddd011ddddd600110070d0010002266d5d50006d1100016d1100000000037133173312337730000000000000000
3bb333300333333303333333001dd660011dd66d000ddd6660bb330a00d0cc0722766dd500611666006106610000000013333331333332130000000000000000
3bb33333333b3b3333333bb3001ddd0000ddd660000ddd66b001100b0001100622dddd151001b3670000011700000000bbb2a2a3323233310b0000b000000000
3bb030b3330b0b033b030bb3000ddd000d000d00000ddd00b03bb30b70c1d00612dd155201103bdd000111dd00000000b3bb92bb13232331030000300b000b00
0bb03033330b0b0333030bb0000dd10000000d0000d00dd03001100dd0010d0d01c77c2000d00ddd00d01ddd000000003b1b3b3bbbb333bb3000000303000030
0330003000030300030003300000d000000000d000d000001033bb0110111001000cc000000d1000000d10000000000001110b13b1bb1b1b0331133012233210
02eeee2002eeee2002eeee2002eeee201222222002eeee2000000000000000000000000000000000000000000000000000000000000000000000000002022020
2efeefe02eeeeee02eeeeee02eeeeee022222f227e7eeee00000000000000000000000000000000000000000000000000000000000000000000000002c2cc2c2
efeefee2eeeeeee2feeeefe2efeeefe22222f222e7eee7e700000000000000000000000000000000000000000000000000000000000000000000000002cc7c20
eeeeeee6efeefee6efeefee6fefefef6222222227e7eee7d0000000000000000000000000000000000000000000000000000000000000000000000001cc77720
ee2deee2eefeefe2eeeeeee2eeeeeee222222222eeeee7e700000000000000000000000000000000000000000000000000000000000000000000000001cc7cc1
d22dde66de2dee66de2dee66de2dee66d2222e262e12eedd000000000000000000000000000000000000000000000000000000000000000000000000017ccc10
122dd666d22dd666d22dd666d22dd6661ddd6e6d21122ddd0000000000000000000000000000000000000000000000000000000000000000000000001c11c1c1
01111111022dd661022dd661022dd66101111f1001122dd100000000000000000000000000000000000000000000000000000000000000000000000001001010
00111122001111220011112200111122dd1111dd0011112200000000dd1111dd0011112202222f20001111226ddddd22000000000000000000000000000b0000
06777dd206777dd206777dd206777dd2d6776d6606777dd200000000d6776d66d7777dd2d2222d2d07777dd26d666dd2000000000000000000000000070b30b0
d2f77d6dd2f77d6dd2f77d6dd2f77d6dd2f77166d2f7d66d00000000d2f77166d2f77d6d6d222d2d62dddddd616666dd000000000000000000000000007b3b00
67777d6667777d6667777d6667777d66d77777118888166100000000d777771116777d666122222d6d666ddd001111110000000000000000000000000bbb3333
6777716667777166677771666777716677777762d12881120000000017777777677771661222222d116666d10067777700000000000000000000000033331110
16617711177777111777771117777711777776661728877600000000066777777776761107222260601111770077777700000000000000000000000000b31300
066177707777166600677770077716607770666607886776000000006660077777606660066d67701777777d607777d00000000000000000000000000b031030
066177607770000000666600000006600000066622d1d6680000000066600000660066600111ddd00d7777d010dddd0000000000000000000000000000001000
011100100000000002eeee200000000000000000006d600000061000000000000000000000000000000000000000000000000000000000000000111111110000
166d116d011111102efeefe0000000000000000d0006010000ddd100000000000000000d0000000000000000000000000000001d000000000011d6dd67761100
d666d6661111d111efeefee2000000000000000d00ddd1000000000000000000000000d600000000d0000000000000000000001d00000000001d111111116100
66666d6d11111111eeeeeee600000000000000010000000000000000000000000000001600000000d000000000000000000000010000000001d11bbbbbb11610
dd66dd0d1010d610ee2deee2000000000000000000000000000000000000000000000001000000000000000000000000000000000000000001d1bbbbbbbb1610
0ddd010001016d01d22dde660000000000000000000000000000000000000000000000000000000000000000000000000000000600000000011bbbbbbbbbb110
10101dd00d000000122dd6660e00000000000000000000000000000000000000000000000000000000000000000000000000000700000000011bbbbbbbbbb110
00000000000000d001111111f000000000000000000000000000000000000000000000000000000000000000000000000000000700000000011bbbbbbbbbb110
2100000000000000001111222100000000000000dd1111dd21000000000000000000000000000000000000000000000006082880000cc700011bbbbbbbbbb110
220000000000000006777dd2220000000000000dd6776d66d200000000040000000000000000000000000000000000000082888000018100011bbbbbbbbbb110
2200000000000000d2f77d6d220000000000000dd2f77166d2000000014242100000000000000000000000000000000028882120000ccc00011bbbbbbbbbb110
220000000000000d67777d66d200000000000001d77777112200000014242441000000000000000000000000000000000222d61006028200011bbbbbbbbbb110
210000000000000d67777166d10000000000000066677772210000006646666600000000000000000000000000000000002220d0016d2880011bbbbbbbbbb110
00000000000000001771761100000000000000066666777710000000d666646d0000000000000000000000000000000000ccc00008188222011bbbbbbbbbb110
000000000000000007706660000000000000000666000777000000000dd2ddd00000000000000000000000000000000000181000028882000d1bbbbbbbbbb160
00000000000000000770666000000000000000000000007700000000000000000000000000000000000000000000000000ccc000022220d001d1bbbbbbbb1610
__label__
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
10000000000000000000c000000c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001
1002eeee200000000000c000000c7777777777777777777777777077707770990090909990999777777777707700000000000000000000000000000000080001
102eeeeee0000bbb0000c00000000000000000000000000000717071707170290090909290929000000000000070000000000000000000bb00bb0000008e0601
10efeefee2000b110000c000000000000000000000000000007070707070700900999090909090000000000000070000000000000000001b001b00c1c8888001
10efeefee6000bbb0000c000000000000000000000000000007070707070700900229090909090000000000000070000000000000000000b000b00c8c8888801
10eeeeeee200011b0000c000000000000000000000000000007770777077709990009099909990000000000000000000000000000000000b000b00c1c2888201
10de2dee66000bbb0000c00000000000000000000000000000111011101110222000202220222000000000000007000000000000000000bbb0bbb00000618801
10d22dd66600011100001c000000000000000000000000000000000000000000000000000000000000000000000c00000000000000000011101110000d028801
10022dd661000000000011ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc000000c000000000000000000000000000000000001
100000000000000000000000000000499400000000001310131100000000000000000303131011111111c000000c777077000000000000000000000000000001
100000000000000000000000000000499400000000003031013000000000000000000b00030001111111c0000000000000700000000000000000000000000001
100000000000000000000000000000499400000000000300030300000000000000000000b3b000111111c0000000000000070000000000000000000000000001
10000000000000000000000000000049940000000000b0003030000000000000000000000b0000011111c0000000000000070000000000000000000000000001
10000000000000000000000000000049940000000000000b000b00000000000000000000000000001111c0000000000000000000000000000000000000000001
100000000000000000000000000000499400000000000000000000000000000000000000000000000111c0000000000000070000000000000000000000000001
1000000000000000000000000000004994000000000000000000000000000000000000000000000000111c0000000000000c0000000000000000000000000001
10000000000000000000000000000049940000000000000000000000000000000000000000000000000111ccccccc000000c0000000000000000000000000001
10000000000000000000000000000049940000000000000000000000000000000000000000000000000011111111c000000c0000000000000000000000000001
10000000000000000000000000000049940000000000000000000000000000000000000000000000000001111111c000000c0000000000000000000000000001
10000000000000000000000000000049940000000000000000000000000000000000000000000000000000111111c000000c0000000000000000000000000001
10000000000000000000000000000049940000000000000000000000000000000000000000000000000000011111c000000c0000000000000000000000000001
10000000000000000000000000000049940000000000000000000000000000000000000000000000000000001111c000000c0000000000000000000000000001
10000000000000000000000000000049940000000000000000000000000000000000000000000000000000000111c000000c0000000000000000000000000001
10000000000000000000000000000049940000000000000000000000000000000000000000000000000000000011c000000c0000000000000000000000000001
10000000000000000000000000000049940000000000000000000000000000000000000000000000000000000001c000000c0000000000000000000000000001
16666000000000000000000000000049940000000000000000000000000000000000000000000000000000000000c000000c0000000000000000000000000001
16611100000000000000000000000049940000000000000000000000000000000000000000000000000000000000c000000c0000000000000000000000000001
16171100000000000000000000000049940000000000000000000000000000000000000000000000000000000000c000000c0000000000000000000000000001
16171100000000000000000000000049940000000000000000000000000000000000000000000000000000000000c000000c0000000000000000000000000001
16111d00000000000000000000000049940000000000000000000000000000000000000000000000000000000000c000000c0000000000000000000000000001
16666d00000000000000000000000049940000000000000000000000000000000000000000000000000000000000c000000c0000000000000000000000000001
1161dd00000000000000000000000049940000000000000000000000000000000000000000000000000000000000c000000c0000000000000000000000000001
1d1dd000000000000000000000000049940000000000000000000000000000000000000000000000000000000000c000000c0000000000000000000000000001
1ddd0000000000000000000000000049940000000000000000000000000007000776000000000000000000000000c000000c0000000000000000000000000001
1dddd000000000000000000000000049940000000000000000000000000077707777000000000000000000000000c000000c0000000000000000000000000001
1dd66d0000000000000000000000004994000000000000000000000000007773677d000000000000000000000000c000000c0000000000000000000000000001
1dd660000000000000000000000000499400000000000000000000000000d77aa3d0000000000000000000000000c000000c0000000000000000000000000001
1ddd000000000000000000000000004994000000000000000000000000000d3aa670000000000000000000000000c000000c0000000000000000000000000001
1ddd0000000000000000000000000049940000000000000000000000000006763777000000000000000000000000c000000c0000000000000000000000000001
1dd10000000000000000000000000049940000000000000000000000000077771677000000000000000000000000c000000c0000000000000000000000000001
13d100000000000000000000000000499400000000000000000000000000677b3d70000000000000000000000000c000000c0000000000000000000000000001
1dbdd7d7777d777777700000000000499400000000000000000000000000000b3000000000000000000000000000c000000c0000000000000000000000000001
16d67ddd77dd777777770000000000499400000000000000000000000000000b3133000000000000000000000000c000000c0000000000000000000000000001
1d3dddddddddddddd7770000000000499400000000000000000000000000000b33b3000000000000000000000000c000000c0000000000000000000000000001
1ddddddddddddddddd770000000000499400000000000000000000000000bb1b3b33000000000000000000000000c000000c0000000000000000000000000001
1ddddddddddddddddd770000000000499400000000000000000000000000b3bb3331000000000000000000000000c000000c0000000000000000000000000001
1ddddddddddddddddd770000000000499400000000000000000000000000bb3b3100000000000000000000000000c000000c0000000000000000000000000001
1ddddddddddddddddd7700000000004994000000000000000000000000003bbb3000000000000000000000000000c000000c0000000000000000000000000001
1ddddddddddddddddd770000000000499400000000000000000000000000003b3000000000000000000000000000c000000c0000000000000000000000000001
1ddddddddddddddddddd0000000000499400000000000000000000000000000b3000000000000000000000000000c000000c0000000000000000000000000001
1ddddddddddddddddddd0000000000499400000000000000000000000000000b3133000000000000000000000000c000000c0000000000000000000000000001
1ddddddddddddddddddd0000000000499400000000000000000000000000002eeee2000000000000000000000000c000000c0000000000000000000000000001
1ddddddddddddddddddd0000000000499400000000000000000000000000b2eeeeee000000000000000000000000c000000c0000000000000000000000000001
1ddddddddddddddddddd0000000000244200000000000000000000000000befeefee200000000000000000000000c000000c0000000000000000000000000001
1ddddddddddddddddddd0000000000244200000000000000000000000000befeefee600000000000000000000000c000000c0000000000000000000000000001
1ddddddddddddddddddd00000000002442000000000000000000000000003eeeeeee200000000000000000000000c000000c0000000000000000000000000001
1ddddddddddddddddddd00000000000220000000000000000000000000000de2dee6600000000000000000000000c000000c0000000000000000000000000001
1ddddddddddddddddd7710000000000000000000000000000000000000000d22dd6660e000000000000000000000c000000c0000000000000000000000000001
1ddddddddddddddddd7711000000000000000000000000000000000000000022dd661f0000000000000000000000c000000c0000000000000000000000000001
1ddddddddddddddddd77111000000000000000000000000000000000000006ddddd2221000000000000000000000c000000c0000000000000000000000000001
1ddddddddddddddddd771111000000000000000000000000000000000000b6d666dd222000000000000000000000c000000c0000000000000000000000000001
1ddddddddddddddddd771111100000000000000000000000000000000000b616666dd22000000000000000000000c000000c0000000000000000000000000001
166ddddddddddddddd771111110000000000000000000000000000000000bb311111122000000000000000000000c000000c0000000000000000000000000001
166ddddddddddddddd7711111110000000000000000000000000000000003bb67777721000000000000000000000c000000c0000000000000000000000000001
1ddddddddddddddddd77111111110000000000000000000000000000000000377777700000000000000000000000c000000c0000000000000000000000000001
1ddddddddddddddddd7711111111000000000000000000000000000000000607777d000000000000000001dd666001dd666001dd666000000000000000000001
1ddddddddddddddddd771111111100000000000000000000000000000000010dddd300000000000000001ddd67661ddd67661ddd676600000000000000000001
1ddddddddddddddddd771111111100000000000000000000000000000000000b33b30000000000000000ddd11676ddd11676ddd1167600000000000000000001
1ddddddddddddddddd771111111100000000000000000000000000000000bb1b3b330000000000000000dd100166dd100166dd10016600000000000000000001
1ddddddddddddddddd771111111100000000000000000000000000000000b3bb33310000000000000000221001dd221001dd221001dd00000000000000000001
1ddddddddddddddddd771111111100000000000000000000000000000000bb3b310000000000000000002d211ddd2d211ddd2d211ddd00000000000000000001
1ddddddddddddddddd7711111111000000000000000000000000000000003bbb3000000000000000000022d2ddd122d2ddd122d2ddd100000000000000000001
1ddddddddddddddddd771111111100000000000000000000000000000000003b300000000000000000000222dd100222dd100222dd1000000000000000000001
1ddddddddddddddddd771111111100000000000000000000000000000000000b3000000000000000000000000000011111100000000000000000000000000001
1ddddddddddddddddd771111111100000000000000000000000000000000000b3133000000000000000000000000001111000000000000000000000000000001
1ddddddddddddddddd771111111100000000000000000000000000000000000b33b3000000000000000000000000001111000000000000000000000000000001
1ddddddddddddddddd771111111100000000000000000000000000000000bb1b3b33000000000000000000000000001111000000000000000000000000000001
1ddddddddddddddddd771111111100000000000000000000000000000000b3bb3331000000000000000000000000001111000000000000000000000000000001
1ddddddddddddddddd771111111100000000000000000000000000000000bb3b3100000000000000000000000000001111000000000000000000000000000001
1ddddddddddddddddd7711111111000000000000000000000000000000003bbb3000000000000000000000000000001111000000000000000000000000000001
1ddddddddddddddddd771111111100000000000000000000000000000000003b3000000000000000000000000000011111100000000000000000000000000001
1ddddddddddddddddd771111111100000000000000000000000000000000000b3000000000000000000000000000011111100000000000000000000000000001
1ddddddddddddddddd771111111100000000000000000000000000000000000b3133000000000000000000000000001111000000000000000000000000000001
1ddddddddddddddddd771111111100000000000000000000000000000000000b33b3000000000000000000000000001111000000000000000000000000000001
1ddddddddddddddddd771111111100000000000000000000000000000000bb1b3b33000000000000000000000000001111000000000000000000000000000001
1ddddddddddddddddd771111111100000000000000000000000000000000b3bb3331000000000000000000000000001111000000000000000000000000000001
1ddddddddddddddddd771111111100000000000000000000000000000000bb3b3100000000000000000000000000001111000000000000000000000000000001
1ddddddddddddddddd7711111111000000000000000000000000000000003bbb3000000000000000000000000000001111000000000000000000000000000001
1ddddddddddddddddd771111111100000000000000000000000000000000003b3000000000000000000000000000011111100000000000000000000000000001
1ddddddddddddddddd77111111111000000000000000cccccccc00000000000b3000000000000000000000000000011111100000000000000000000000000001
1ddddddddddddddddd77111111111100000000000000c7777c7c00000000b30b3000000000000000000000000000001111000000000000000000000000000001
1ddddddddddddddddd77111111111110000000000000cccccc7c000000003b0b3000000000000000000000000000001111000000000000000000000000000001
1ddddddddddddddddd77111111111111000000000000c7777ccc0b30e00001bb330b000000000000000000000000001111000000000000000000000000000001
1ddddddddddddddddd77111111111111100000000000ccc7cc7c03be00000bbbb3300000000000000b0001100000001111000000000000000000000000000001
1ddddddddddddddddd77111111111111110000000000cccccccc003b30000bbbb313000000000000b3b011110110001111000000000000000000000000000071
1ddddddddddddddddd771111111111111110000000000001d0000103b0033bbb3b31000000000b00030011111111001111000000000001110000000000000771
1ddddddddddddddddd7711111111111111110000000001dd66101310013003bbb310000000000303131011111111011111100000000011111010000000007771
1ddddddddddddddddd77dddddd776d6dbd6d7777777777777d776d3d6dbd6d6dbd6ddbd6d3d677777777777777777777777777777777777777777777777777d1
1ddddddddddddddddd77ddddddd7d3d6d3d6777777777777d777d3d636d6d3d6d3d66d636d3d7777777777777777777777777777777777777777777777777dd1
1ddddddddddddddddd77dddddddddd3d3d3dddddddddd777dddddddd3d3ddd3d3d3dd3d3ddddddddddddddddddddddddddddddddddddddddddddddddddddddd1
1ddddddddddddddddd77ddddddddddd3ddddddddddddddddd77ddddd3dddddd3ddddddd3ddddddddddddddddddddddddddddddddddddddddddddddddddddddd1
1ddddddddddddddddd77ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd1
1ddddddddddddddddd77ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd1
1ddddddddddddddddd77ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd1
1ddddddddddddddddd77ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd1
1ddddddddddddddddd77ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd1
1ddddddddddddddddd77ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd1
1ddddddddddddddddd77ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd1
1ddddddddddddddddd77ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd1
1ddddddddddddddddd77ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd1
1ddddddddddddddddd77ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd1
1ddddddddddddddddd77ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd1
1ddddddddddddddddd77ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd1
1ddddddddddddddddd77ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd1
1ddddddddddddddddd77dddddddddddddddddddddddddddddddddddddddddddddddddd66ddddddddddddddddddddddddddddddddddddddddddddddddddddddd1
1ddddddddddddddddd77ddddddddddddddddddddddddddddddddddddddddddddddddd6666dddddddddddddddddddddddddddddddddddddddddddddddddddddd1
1ddddddddddddddddd77ddddddddddddddddddddddddddddddddddddddddddddddddd6666dddddddddddddddddddddddddddddddddddddddddddddddddddddd1
1ddddddddddddddddd77dddddddddddddddddddddddddddddddddddddddddddddddddd66ddddddddddddddddddddddddddddddddddddddddddddddddddddddd1
1ddddddddddddddddd77ddddddddddddddddddddddddddddddddddddddddddddddddddddd66dddddddddddddddddddddddddddddddddddddddddddddddddddd1
1ddddddddddddddddd77ddddddddddddddddddddddddddddddddddddddddddddddddddddd66dddddddddddddddddddddddddddddddddddddddddddddddddddd1
1ddddddddddddddddd77ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd1
1ddddddddddddddddd77ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd1
1ddddddddddddddddd77ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd1
1ddddddddddddddddd77ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd1
1ddddddddddddddddd77ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd1
1ddddddddddddddddd77ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd1
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111

__map__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004340404040404400003f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004340404040404400003c0000353535353500373737000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000434040404040440060606060606060606060606060600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000405440404040440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000003400000000000000000000000000000000000030303000000000000000000000000000000000000000000000000000000000000000000000404040404040440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000320000003000000030000000000000000000000000000000000000000035350000000000000000000000404040405540440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000720000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000043404040404044000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b200000000
0000000072000000303000003600000066666600000000000000000000000000000000000000000000000000000064640000000000000000000000404040404040440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000007200000030000000000000000000790000006565656565000000000000006c6b6b6b6b6b6b6b6d0000000000000000000000000000000000434040404040440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000af0000000000000000
00000000720030000000004559460000007900000075777777760000000000006ce9777777287777776e6d00000000000000000000000000000000475040405440400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b30000000000000000
00000100000000000072724053407a7a7a607a7a7a7a777600000000320000006a777777771f777777776a00000000000000000000000000000000004340404040400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
41584141710000000000004040400000000000000000790000000000000000006a777730301f777777776a00000000000000000000000000000000004740404040484f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
404040555271000000000043404400000000000000007900000000676767000069777730301f313177776a00000000000000000000000000000000000000000000606000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
405350404044000036007051544400000000000000007900000000007900000077777877771f313177776a000000003333330000000000000000000000000000006060000000003d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
405251404052710000705140534800000000000000007900000000007900000077777877771f7b7b7b776a000000000000000000000000000000000000003c00006060000000003c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
405440405240525a5851534248000000000000006565656565657a7a60000072455a4171771f777777776a00000064646464640000000000000045464541414141414141414141414141414141415840460000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
40534242424242424242480000004f0000000000757777777776000000000000404040527128777777776900000000007900000000000000007247484353404040404040534242424250554053424242480000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5348777777777600000000000000000000000000000079790000000000000000404040405241587177777700000000007900000000000000000000364340404040404053480000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7900000079000000000000000000000000000000000079790000000000000000474242425040405271777700000000317900000000000000000000004040404055404044000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
79003800790000000000000000000000260000000000797b0000000031310000000000004750404052414672000031007900000064646400006464644340404040404044000000000000000000000000370000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
790000000000000000000000000070414041710000007b780000000031310000000000000047404242404800000000007900000000790000000079004742424242424248000000323200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000070514040405271000079790000000000000000003300000000000000000000000000007900000000790000000079000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000704151404055404052710079790000000000000000000000000000000000000000455a58415946000000790000000079000000000000003232000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000060000000000000007051404040404040404052415a46000000000000000000000000000000000000004f4340404040572020205720202020570000000000000000000000000000000000002500000000006c00006b6d00000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000060000000514040404040404040404040404400006666666666660000006767676767670000004353505553480000007900000000790000323200000000000064640000006c6b6b6b6d000000006a0000006a00000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000504040544040404040404040404400000000000000000000000000000000000000455152514044760000007900000000790000000000000000000000000000006a0000006a000000006a0000006a00000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000434040404040404040405140405720202020202020202020202020202020202020574040405348000000007900000000790000000000646400000000000000006a0000006e6b6b6b6b6f0000006a00000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000047424053424242504053425040480000000000004b49494949494c000000000000434054404400000000007b7a7a7a7a646400000000000000000000000000006a0000000023232323000000006a00000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000007900757777777776000000790000000000000075777777777776000000000000474242424800000000007900000000790000000000000000000000000000006a00000000003d3e3f000000006a00000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000079000000003f0000000000790000000000000000007577760000000000000000007934790000000000646400000000790000000000000000000000000000006a000000000000000000003d006a00000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000079002600003c0000002600790000000000000000000000000000000000000000007934790000000000007900000000790000000000000000000000000000006a003c00000000000000003c006a00000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000454141414141414141414141414600000000000000000000000000000000000000004541460064640000007900000000790000000000000000000000000000004b4949494949494949494949494c00000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
a102000005050000000000000000000000000000000000000c6551760000000000000065500600116000060000000000000000000000000000000000000000000000000000000000000000000000000000000000
910200000c1500c1501115013150181000010000100001000c2500c25011250132501515017150181501815500100001000010000100001000010000100001000010000100001000010000100001000010000100
4d0200001d4251d4251142011420054200542005020050250c6000e6000c6000e600106000c6000e600127001d670116501164011640116301163011620116200070000700007000070000700007000070000700
91060000185551f555245252b5000050000500005000050021050000001c0001c05000000240501c0000050021755237552475521755237552475523755267550c155001000e155001000c155001001215500000
970400001f6553065500000000000000000000000000000029753000000000000000000000000000000000001305111051100510e0510c0510000000000000000000000000000000000000000000000000000000
910303001375513705007050070500705007050070500705007050070500705007050070500705007050070500705007050070500705007050070500705007050070500705007050070500705007050070500705
a70300002465024640186300c6200c6100c6100c6000c600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010200000c15111151101510e1510c151001510015100151001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
91050000123550030012355003000c355003000c3400c310001000010100101001010010100101001010010100101001010010000100001000000000000000000000000000000000000000000000000000000000
010900000c2500c2550c2500c2550f2500f2550020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200
150500000c13105131001310012500125001150010200102001020010200102001020010200102001020010200102001020010200102001020010200102001020010200102001020010200102001020010200100
010a00001105505055110551c500185002450511505105050e5050c50511505105050e5050c50511505105050e5050c50511505105050e5050c50500505005050050500505005050050500505000000000000000
010d000011055000000c05511055150551e7001105515055170550000018055007000070007705077050070507705007050070500705007050070500705007050070500705007050070500705007050070500705
010a00000c645006240c635006240c625006240061500614000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
170500000c053000000c62500000000003362500000106000c0000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
a1050000123550030012355003000c355003000c3400c3100c3000c3000f3000c3000c300003000c3000030000300003000030000300003000030000300003000030000300003000030000300003000030000300
911820000c00011200130000c200180000c2000c00011200130000c200180000a2000f0000a200130000f2000c00011200130000c200180000c2000c00011200130000c200180000a2000f0000a2001300000000
4b182000006003c600376003c60000600006003760014300006003c600376001d6000060000600376003c600006003c600376003c60000600006003760014300006003c600376001d6000060000600376003c600
491820001d1001c1003c1001a1001c1000c1003c10035100001001810018100181001610016100131000c10016100001001810016100351000c1003c100351000c10016100161001610013100131001110000100
911800001010000100101000010000100041001b10000100001001810018100181001610016100131000c100161001f10018100001000010000100001000000016100181000010000100181002b1001610001100
111800000a4000c400184000a4000c400134000a4000c400184000a4000c400184000a4000c4000a4000a4000a4000c400184000a4000c400134000a4000c400184000a4000c400184000a4000c4000f4000f400
95180000102000020010200112000a2000c200152000c2000e2000a200102001120011200102000e20010200112000f2001120011200052000f200152000f200182000f20005200112000f200032000e20002200
591800000c500180000c50016000105000c50010000075000c5001800000000105000c500110001350018000115001000011500160000f5000c500100000f500115001800000000115000f5000f5000e5000e500
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5f0f00200c400003000f300001001350000300153000030016300003000c30000300135000010009300003000c300003000f300001001350000300153000030016300003000c3000030013500001001830000300
030f00000060000600000000c6003660000000000000000000000006000000000000366000000000600000000060000600000000c600366000000000000000000000000600000000000036600000000060000000
__music__
01 41111012
00 41111013
00 41111012
00 41111013
00 41501410
00 41511415
00 41501410
00 41111415
00 41111614
02 41111614
00 41545253
00 41545253
00 41505554
00 41505554
00 41515554
02 41505552
00 41425859

