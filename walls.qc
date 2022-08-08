/*
==============================================================================

SIMPLE BMODELS

func_s that don't do more than appear and disappear

==============================================================================
*/

/*
metlslime on making walls disappear:

"i finally got it to work, and here's how.

1) to enable being solid after turning inivisible and then visible again, i only ever set the model using setmodel once, and from then on alternate between setting modelindex to 0 or the actual index.

Since setmodel is never called, the entity stays linked into the world with the original physics bounds. self.solid can be changed without issue.

2) for entities that are set to START_OFF, there was still a problem where they'd never appear at all, and never become visible. My hack solution is to wait 1 second, then make them invisible/nonsolid in a special think function, rather than in the spawn function."
*/

void() bmodel_appear =
{
	// ***
	// IN THIS ORDER
	// ***
	if (!(self.spawnflags & 1))
	{
		self.solid = SOLID_BSP;
		self.movetype = MOVETYPE_PUSH;
	}
	setorigin (self, self.origin);	
	setmodel (self, self.model);
	//self.alpha = 1;
	// ***
	// NOT ANY OTHER ORDERS
	// ***
	
	bmodel_lightstyle(self,"a");
	self.state = STATE_BOTTOM;
	//force_retouch = 2;
}

void() bmodel_vanish =
{
	self.state = STATE_TOP;
	self.modelindex = 0;
	bmodel_lightstyle(self,"m");
	//self.alpha = -1;
	
	if (self.solid != SOLID_NOT)
		wall_spawn_tdrop();
	self.solid = SOLID_NOT;
}

/*
quake doesn't catch when a bmodel turns nonsolid while it is the groundentity for 
other entities, so those entities stay floating in the air if they're at rest or
the 'wrong' movetype. it does catch when an entity's groundentity is removed, but
since a toggleable wall would be gone once killtargeted and thus not able to be
toggled actually, it's time for 

A STUPID HACK:

spawn an invisible duplicate of the bmodel with a tiny bit of velocity to give 
everybody resting on it a wee nudge so they forget their old groundentity, then 
kill the duplicate. :(

the older, worse solution was to just nextent() through the entire level and check
whose bounds overlapped the wall's bounds, in a loop that was guaranteed to limit 
the size of the level to however many entities could be checked before tripping 
the runaway progs loop protection crash.

other things that didn't work, for future reference:
- spawn a teledeath-style trigger around the wall that ~s FL_ONGROUND in .touch:
	not everything touches triggers (namely dead monsters), even after
	a force_retouch 2
- maintain a linked list of entities that have ever touched the func_wall in its
	.touch so there's a much shorter list of things to have to check: if a backpack
	falls on the wall, gets put in the chain, and is then picked up, the rest of 
	the chain is orphaned
- do that but it's a doubly-linked list: now every entity that could possibly
	be removed for any reason (and thx to killtarget that's everything) has to 
	have extra code handle its own position in the list when it is removed on 
	behalf of func_walls
*/
void() wall_spawn_tdrop =
{
	entity t = spawn();
	t.owner = self;
	t.solid = SOLID_BSP;
	t.movetype = MOVETYPE_PUSH;
	setorigin (t, self.origin);	
	setmodel (t, self.model);
	t.alpha = -1;
	
	// this could be less aggressive but somehow doesn't work if the wall is made of skip
	t.velocity = '0 0 2';
	
	t.think = SUB_Remove;
	t.nextthink = self.ltime + 0.1;
}

// ==========================================

float SPAWN_WALL_NONSOLID = 1;
float SPAWN_WALL_TOGGLEVIS = 2;
float SPAWN_WALL_STARTINVIS = 4;

void() func_wall_use =
{
	if (self.wait == -1)
	{
		func_wall_flip();
		self.use = SUB_Null;
		return;
	}
	
	if (self.wait > 0)
	{
		if (self.nextthink <= self.ltime)
			func_wall_flip();
		self.think = func_wall_flip;
		self.nextthink = self.ltime + self.wait;
		return;
	}
	
	func_wall_flip();
}

void() func_wall_flip =
{	// change to alternate textures
	if (self.noise) sound(self, CHAN_BODY, self.noise, 1.0, ATTN_NORM);
	
	if (self.spawnflags & SPAWN_WALL_TOGGLEVIS)
	{
		if (self.state == STATE_TOP)
		{
			bmodel_appear();
		}
		else
		{
			bmodel_vanish();
		}
		return;
	}
	
	self.frame = 1 - self.frame;
}

/*FGD
@baseclass base(Appearflags, Targetname) = Wall [
	spawnflags(flags) = [
		1 : "Illusionary" : 0
		2 : "Toggle Visible+Solid" : 0
		4 : "Start Invisible" : 0
	]
	noise(string) : "Sound to play when triggered"
	wait(string) : "Flip back after this long" : "0"
	alpha(string) : "Opacity (GLQuake+ only) (-1 = 0)" : "1"
]
*/

/*QUAKED func_wall (0 .5 .8) ? NONSOLID TOGGLE_VIS START_INVIS
This is just a solid wall if not inhibited.  Changes its texture(s) to alternate ones (e.g. basebtn), if targeted.
NOT STATIC.  Use a func_static for inconsequential bmodels.

Flags:
NONSOLID	act as a func_illusionary, but still respond to trigger events
TOGGLE_VIS	change visibility and solidity instead of texture when triggered. starts solid and visible unless START_INVIS is checked.
 
Keys:
"targetname" entity name
"mangle" orientation of the model, values are 'pitch yaw roll', positive pitch is down. not recommended on bmodels.
"noise" sound to play when triggered.
"wait" will always flip its state back again if set - absorbs repeat triggerings like doors while waiting
*/
/*FGD
@SolidClass base(Wall) = func_wall : "Wall. Changes its texture(s) to alternate ones (e.g. basebtn), if triggered.
Not static: Use a func_static for inconsequential bmodels.

If 'Illusionary' is set, wall will always be nonsolid.
If 'Toggle Visibility' is set, will disappear and reappear when triggered instead of flipping texture."
[]
*/
void() func_wall =
{
	if (!SUB_ShouldSpawn()) return;
	
	if (self.noise) precache_sound_safe(self.noise);
	precache_model_safe(self.model);
	
	self.angles = self.mangle;
	self.use = func_wall_use;
	//self.angles = '0 0 0';

	self.movetype = MOVETYPE_PUSH;	// so it doesn't get pushed by anything
	if (self.spawnflags & SPAWN_WALL_NONSOLID)
		self.solid = SOLID_NOT;
	else
		self.solid = SOLID_BSP;

	setmodel (self, self.model);
	
	if (self.spawnflags & SPAWN_WALL_STARTINVIS)
	{
		self.spawnflags |= SPAWN_WALL_TOGGLEVIS;	// starting invis implies toggle
		bmodel_vanish();
	}
	else
	{
		bmodel_lightstyle(self,"a");
		self.state = STATE_BOTTOM;
	}
}

/*QUAKED func_wall_point (0 .5 .8) (-8 -8 -8) (8 8 8) NONSOLID TOGGLE_VIS START_INVIS 
This is just a solid wall if not inhibited.  Changes its texture(s) to alternate ones (e.g. basebtn), if triggered.

Keys:
"model" filename of model to stand in for this entity. can be a bsp or an mdl. mdls will not be solid.
"mangle" orientation of the model, values are 'pitch yaw roll', positive pitch is down
"noise" sound to play when triggered.
"targetname"	entity name
*/
/*FGD
@PointClass base(Wall) = func_wall_point : "Wall. Changes its texture(s) to alternate ones (e.g. basebtn), if triggered.
Not static: Use a func_static for inconsequential bmodels.

Select a .bsp or .mdl to show with 'model'. 

If 'Illusionary' is set, wall will always be nonsolid. If you use a .mdl you MUST set this flag (or consider a misc_model instead?)
If 'Toggle Visibility' is set, will disappear and reappear when triggered instead of flipping texture." [
	model(string) : "External model"
	mangle(string) : "Orientation of external model"
]
*/
void() func_wall_point = { func_wall(); }

/*QUAKED func_static (0 .5 .8) ?
Like a func_wall but calls makestatic.  Static entities are always nonsolid.
*/
/*
@SolidClass base(Appearflags) = func_static : "Nonsolid, untriggerable static wall" [
	alpha(string) : "Opacity (GLQuake only) (-1 = 0)" : "1"
]
*/
void() func_static =
{
	if (!SUB_ShouldSpawn()) return;
	func_wall();
	makestatic(self);
}

/*QUAKED func_static_point (0 .5 .8) (-8 -8 -8) (8 8 8)
Like a func_wall but calls makestatic.  Static entities are always nonsolid.

"model"		filename of model to stand in for this entity. can be bsp or mdl.
*/
/*
@PointClass base(Appearflags) = func_static_point : "Static (untriggerable) nonsolid model (point)" [
	model(string) : "External model"
	mangle(string) : "Orientation of external model"
]
*/
void() func_static_point = { func_static(); }


/*QUAKED func_illusionary (0 .5 .8) ?
A simple entity that looks solid but lets you walk through it. Functionally identical to a func_static.
*/
/*FGD
@SolidClass base(Appearflags) = func_illusionary : "Nonsolid, untriggerable static wall"  [
	alpha(string) : "Opacity (GLQuake only) (-1 = 0)" : "1"
]
*/
void() func_illusionary =
{
	func_static();
}


// ==========================================

void() gate_use =
{
	activator = self;
	SUB_UseTargets();
}

/*QUAKED func_episodegate (0 .5 .8) ? E1 E2 E3 E4
This bmodel will appear if the episode has already been completed, so players can't reenter it.
If it does spawn, it fires its targets immediately.
*/
/*FGD
@SolidClass base(Appearflags, Target) = func_episodegate : 
"Episode Gate. 
If players have completed the episode, it fires its targets.
If players have NOT completed the episode, it self-removes."
[
	spawnflags(Flags) =
	[
		1 : "Episode 1" : 1
		2 : "Episode 2" : 0
		4 : "Episode 3" : 0
		8 : "Episode 4" : 0
	]
]
*/
void() func_episodegate =
{
	if (!SUB_ShouldSpawn()) return;
	if (!(serverflags & self.spawnflags))
	{
		bmodel_lightstyle(self,"m");
		return;			// can still enter episode
	}
	bmodel_lightstyle(self,"a");
	self.style = 0;
	self.switchshadstyle = 0;
	self.spawnflags = 0;
	func_wall();

	self.think = gate_use;
	self.nextthink = time + 0.2;
}

/*QUAKED func_bossgate (0 .5 .8) ?
This bmodel does not spawn unless players have all of the episode sigils.
If it does spawn, it fires its targets immediately.
*/
/*FGD
@SolidClass base(Appearflags, Target) = func_bossgate : 
"Boss Gate. 
If players have NOT completed all episodes, it fires its targets.
If players have completed all episodes, it self-removes." 
[]
*/
void() func_bossgate =
{
	if (!SUB_ShouldSpawn()) return;
	if ( (serverflags & SVFL_ALLEPISODES) == SVFL_ALLEPISODES)
	{
		bmodel_lightstyle(self,"m");
		return;		// all episodes completed
	}
	bmodel_lightstyle(self,"a");
	self.style = 0;
	self.switchshadstyle = 0;
	self.spawnflags = 0;
	func_wall();
	
	self.think = gate_use;
	self.nextthink = time + 0.2;
}


// ==========================================


/*QUAKED func_group (0.6 0.7 0.8) ?
groups brushes into a group that may or may not be easier to work with
*/
/*QUAKED func_detail (0.2 .5 .6) ?
Apparently this behaves like a detail brush. Doesn't seal against leaks.
*/
/*QUAKED func_detail_wall (0.2 .5 .6) ?
Apparently this behaves like a detail brush. Doesn't seal against leaks. Doesn't cut geometry it touches.
*/
/*QUAKED func_detail_illusionary (0.2 .5 .6) ?
Apparently this behaves like a detail brush. Doesn't seal against leaks. Doesn't cut geometry it touches. Non-solid.
*/
/*FGD
@SolidClass base(Phong) = func_group : "Group of brushes for in-editor use" []
@SolidClass base(Phong) = func_detail : "Group of brushes which aren't abusive to bsp" []
@SolidClass base(Phong) = func_detail_wall : "Group of brushes which aren't abusive to bsp or geometry" []
@SolidClass base(Phong) = func_detail_illusionary : "Group of brushes which aren't solid, or abusive to bsp or geometry" []
@SolidClass base(Phong) = func_detail_fence : "Group of brushes which aren't solid, or abusive to bsp or geometry, and are two-sided" []
*/
