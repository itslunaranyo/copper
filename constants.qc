//================================================
// constants
//================================================

const string version_s = "Copper Quake 1.20 - 20 November 2022";
const float version_f = 1.20;

const float	FALSE					= 0;
const float TRUE					= 1;

// edict.flags
const float	FL_FLY					= 1;
const float	FL_SWIM					= 2;
const float	FL_CLIENT				= 8;	// set for all client edicts
const float	FL_INWATER				= 16;	// for enter / leave water splash
const float	FL_MONSTER				= 32;
const float	FL_GODMODE				= 64;	// player cheat
const float	FL_NOTARGET				= 128;	// player cheat
const float	FL_ITEM					= 256;	// extra wide size for bonus items
const float	FL_ONGROUND				= 512;	// standing on something
const float	FL_PARTIALGROUND		= 1024;	// not all corners are valid
const float	FL_WATERJUMP			= 2048;	// player jumping out of water
const float	FL_JUMPRELEASED			= 4096;	// for jump debouncing
const float	FL_UNDERWATER			= 8192;	// for dive/surface water sounds

// edict.customflags
const float	CFL_LEFTY			= 1;	// used by slidemovers (scrags) to alternate strafe direction
const float	CFL_RETURNED		= 1;	// zombie has already respawned in nightmare
const float	CFL_ZAPPED			= 2;
const float	CFL_AXEHITME		= 4;
const float	CFL_LOCKED			= 16;	// special state-independent deactivation
const float	CFL_INPAIN			= 16;	// zombie should knockdown soon
const float	CFL_KNOCKEDDOWN		= 32;	// zombie is down
const float	CFL_PLUNGE			= 64;	// has fallen in a death pit
const float	CFL_SPAWNER			= 128;	// is a generator of monsters
const float	CFL_UNDYING			= 256;	// god mode minus one point (player)
const float	CFL_LIQUID_IMMUNE	= 512;	// monster spawned touching slime or lava, so assume designer wants it immune to damage
const float	CFL_MELEEONLY		= 1024;	// has no ranged attack (monster)
const float	CFL_LIMBO			= 2048;	// waiting in teleport limbo (coop, player)
const float	CFL_OMNIVISION		= 4096;	// eyes in back of head
// serverflags
const float	SVFL_EPISODE1		= 1;
const float	SVFL_EPISODE2		= 2;
const float	SVFL_EPISODE3		= 4;
const float	SVFL_EPISODE4		= 8;
const float	SVFL_ALLEPISODES	= 15;
const float	SVFL_RESPAWNING		= 2097152;	// to notify target_autosave that we just restarted after dying



// edict.movetype values
const float	MOVETYPE_NONE			= 0;	// never moves
//const float	MOVETYPE_ANGLENOCLIP	= 1;
//const float	MOVETYPE_ANGLECLIP		= 2;
const float	MOVETYPE_WALK			= 3;	// players only
const float	MOVETYPE_STEP			= 4;	// discrete, not real time unless fall
const float	MOVETYPE_FLY			= 5;
const float	MOVETYPE_TOSS			= 6;	// gravity
const float	MOVETYPE_PUSH			= 7;	// no clip to world, push and crush
const float	MOVETYPE_NOCLIP			= 8;
const float	MOVETYPE_FLYMISSILE		= 9;	// fly with extra size against monsters
const float	MOVETYPE_BOUNCE			= 10;
const float	MOVETYPE_BOUNCEMISSILE	= 11;	// bounce with extra size

// edict.solid values
const float	SOLID_NOT				= 0;	// no interaction with other objects
const float	SOLID_TRIGGER			= 1;	// touch on edge, but not blocking
const float	SOLID_BBOX				= 2;	// touch on edge, block
const float	SOLID_SLIDEBOX			= 3;	// touch on edge, but not an onground
const float	SOLID_BSP				= 4;	// bsp clip, touch on edge, block

// range values
const float	RANGE_MELEE				= 0;	// 0-120
const float	RANGE_NEAR				= 1;	// 120-500
const float	RANGE_MID				= 2;	// 500-900, max ranged attack dist
const float	RANGE_FAR				= 3;	// 900-1250, max awake dist
const float	RANGE_TOOFAR			= 4;	// 1250+

// deadflag values
const float	DEAD_NO					= 0;
const float	DEAD_DYING				= 1;
const float	DEAD_DEAD				= 2;
const float	DEAD_SPECTATING			= 3;

// takedamage values
const float	DAMAGE_NO				= 0;
const float	DAMAGE_YES				= 1;
const float	DAMAGE_AIM				= 2;

// type parameters for damage functions
const float DMGTYPE_EXPLOSION		= 1;	// half to shamblers
const float DMGTYPE_ZKILL			= 2;	// death to zombies (direct EXPLOSION always kills zombies but splash doesn't)
const float DMGTYPE_NOARMOR			= 4;	// bypass armor
const float DMGTYPE_MELEE			= 8;	// inflictor == attacker
const float DMGTYPE_TELEFRAG		= 16;
const float DMGTYPE_LIGHTNING		= 32;
const float DMGTYPE_DROWNING		= 64;
const float DMGTYPE_FALLING			= 128;	// everyone's favorite
const float DMGTYPE_LAVA			= 256;
const float DMGTYPE_SLIME			= 512;
const float DMGTYPE_CRUSH			= 1024;
const float DMGTYPE_SCRIPT			= 2048;	// target_items, invoke, etc

const float	TRACE_NOMONSTERS		= 1;
const float	TRACE_WATER				= 2;

// monsters
const float	SPAWN_AMBUSH		= 1;
const float	SPAWN_CRUCIFIEDX	= 1;
const float	SPAWN_TRIGGERED		= 16;
const float	SPAWN_NO_TFOG		= 32;
const float	SPAWN_NO_TFRAG		= 64;
const float	SPAWN_INSTAWAKE		= 128;
const float	SPAWN_LYING			= 2;	// zombies
const float	SPAWN_CRUCIFIED		= 32768;	// was 128, but random zombies in stock quake have spawnflags&128 left over from something :P

// mode flags
const float	SPAWN_NOTEASY		= 256;
const float	SPAWN_NOTNORMAL		= 512;
const float	SPAWN_NOTHARD		= 1024;
const float	SPAWN_NOTDM			= 2048;
const float	SPAWN_COOPONLY		= 4096;
const float	SPAWN_NOTCOOP		= 8192;

const float	SPAWN_ALT_TARG		= 16384;	// fire the four target keys at different times

// items
const float	IT_AXE					= 4096;
const float	IT_SHOTGUN				= 1;
const float	IT_SUPER_SHOTGUN		= 2;
const float	IT_NAILGUN				= 4;
const float	IT_SUPER_NAILGUN		= 8;
const float	IT_GRENADE_LAUNCHER		= 16;
const float	IT_ROCKET_LAUNCHER		= 32;
const float	IT_LIGHTNING			= 64;
const float	IT_WEAPONS				= 127 + 4096;

const float	IT_SHELLS				= 256;
const float	IT_NAILS				= 512;
const float	IT_ROCKETS				= 1024;
const float	IT_CELLS				= 2048;

const float	IT_ARMOR1				= 8192;
const float	IT_ARMOR2				= 16384;
const float	IT_ARMOR3				= 32768;
//float	IT_SUPERHEALTH			= 65536;	// never gets used now, but the .exe expects the following flags

const float	IT_KEY1					= 131072;
const float	IT_KEY2					= 262144;

const float	IT_INVISIBILITY			= 524288;
const float	IT_INVULNERABILITY		= 1048576;
const float	IT_SUIT					= 2097152;
const float	IT_QUAD					= 4194304;
const float	IT_POWERUPS				= IT_INVISIBILITY + IT_INVULNERABILITY + IT_SUIT + IT_QUAD;
// more IT flags after this exceeds 1^23, causing FPU bugs and unpredictable behavior

// point content values
const float	CONTENT_EMPTY		= -1;
const float	CONTENT_SOLID		= -2;
const float	CONTENT_WATER		= -3;
const float	CONTENT_SLIME		= -4;
const float	CONTENT_LAVA		= -5;
const float	CONTENT_SKY			= -6;

const float	WL_NONE				= 0;
const float	WL_FEET				= 1;
const float	WL_WAIST			= 2;
const float	WL_EYES				= 3;


// movers
const float	STATE_TOP			= 0;
const float	STATE_BOTTOM		= 1;
const float	STATE_UP			= 2;
const float	STATE_DOWN			= 3;

const float	STATE_OFF			= 0;
const float	STATE_ON			= 1;



const float	START_OFF			= 1;


// geometry
const vector	VEC_ORIGIN		= '0 0 0';
const vector	VEC_HULL_MIN	= '-16 -16 -24';
const vector	VEC_HULL_MAX	= '16 16 32';

const vector	VEC_HULL2_MIN	= '-32 -32 -24';
const vector	VEC_HULL2_MAX	= '32 32 64';

const vector	VEC_ONE			= '1 1 1';
const vector	VEC_UP			= '0 0 1';
const vector	VEC_DOWN 		= '0 0 -1';

// sound channels
// channel 0 never willingly overrides
// other channels (1-7) always override a playing sound on that channel
const float	CHAN_AUTO		= 0;
const float	CHAN_WEAPON		= 1;
const float	CHAN_VOICE		= 2;
const float	CHAN_ITEM		= 3;
const float	CHAN_BODY		= 4;
const float	CHAN_POWERUP	= 5;
const float	CHAN_OTHER		= 6;

const float	ATTN_NONE		= 0;
const float	ATTN_NORM		= 1;
const float	ATTN_IDLE		= 2;
const float	ATTN_STATIC		= 3;

// entity effects
const float	EF_BRIGHTFIELD	= 1;
const float	EF_MUZZLEFLASH 	= 2;
const float	EF_BRIGHTLIGHT 	= 4;
const float	EF_DIMLIGHT 	= 8;

// attack states
const float	AS_STRAIGHT		= 1;
const float	AS_SLIDING		= 2;
const float	AS_MELEE		= 3;
const float	AS_MISSILE		= 4;
const float	AS_LEAP			= 5;


// protocol bytes
const float	SVC_UPDATESTAT		= 3;
const float	SVC_SETVIEW			= 5;
const float	SVC_TEMPENTITY		= 23;
const float	SVC_CENTERPRINT		= 26;
const float	SVC_KILLEDMONSTER	= 27;
const float	SVC_FOUNDSECRET		= 28;
const float	SVC_INTERMISSION	= 30;
const float	SVC_FINALE			= 31;
const float	SVC_CDTRACK			= 32;
const float	SVC_SELLSCREEN		= 33;
const float	SVC_CUTSCENE		= 34;
const float	SVC_FOG				= 41;	// in fitzquake, byte byte byte byte short for density r g b lerptime

// svc updatestat byte types
const float	STAT_HEALTH			= 0;
const float	STAT_FRAGS			= 1;
const float	STAT_WEAPON			= 2;
const float	STAT_AMMO			= 3;
const float	STAT_ARMOR			= 4;
const float	STAT_WEAPONFRAME	= 5;
const float	STAT_SHELLS			= 6;
const float	STAT_NAILS			= 7;
const float	STAT_ROCKETS		= 8;
const float	STAT_CELLS			= 9;
const float	STAT_ACTIVEWEAPON	= 10;
const float	STAT_TOTALSECRETS	= 11;	// hmmm ...
const float	STAT_TOTALMONSTERS	= 12;	// must send this if new monsters are spawned after the map starts
const float	STAT_SECRETS		= 13;	// bumped on client side by svc_foundsecret
const float	STAT_MONSTERS		= 14;	// bumped by svc_killedmonster
const float STAT_ITEMS 			= 15;	// self.items | (self.items2<<23)
										// In order to decode this stat properly, you need to use 
										// getstatbits(STAT_ITEMS,0,23) to read self.items, and 
										// getstatbits(STAT_ITEMS,23,11) to read self.items2 or 
										// getstatbits(STAT_ITEMS,28,4) to read the visible part 
										// of serverflags, whichever is applicable
const float STAT_VIEWHEIGHT		= 16;	// player.view_ofs_z
const float STAT_VIEW2			= 20;	// This stat contains the number of the entity in the server's .view2 field
const float STAT_VIEWZOOM		= 21;	// Scales fov and sensitivity. Part of DP_VIEWZOOM
const float STAT_IDEALPITCH		= 25;
const float STAT_PUNCHANGLE_X	= 26;
const float STAT_PUNCHANGLE_Y	= 27;
const float STAT_PUNCHANGLE_Z	= 28;

const float STAT_USER			= 32; // Custom user stats start here (lower values are reserved for engine use)
const float STAT_MAXHEALTH		= 32;
const float STAT_KEYCOUNTS		= 33;


// temporary entities
const float	TE_SPIKE		= 0;
const float	TE_SUPERSPIKE	= 1;
const float	TE_GUNSHOT		= 2;
const float	TE_EXPLOSION	= 3;
const float	TE_TAREXPLOSION	= 4;
const float	TE_LIGHTNING1	= 5;
const float	TE_LIGHTNING2	= 6;
const float	TE_WIZSPIKE		= 7;
const float	TE_KNIGHTSPIKE	= 8;
const float	TE_LIGHTNING3	= 9;
const float	TE_LAVASPLASH	= 10;
const float	TE_TELEPORT		= 11;
const float	TE_EXPLOSION2	= 12;
const float	TE_BEAM			= 13;

// update types
const float	UPDATE_GENERAL	= 0;
const float	UPDATE_STATIC	= 1;
const float	UPDATE_BINARY	= 2;
const float	UPDATE_TEMP		= 3;

// messages
const float	MSG_BROADCAST	= 0;		// unreliable to all
const float	MSG_ONE			= 1;		// reliable to one (msg_entity)
const float	MSG_ALL			= 2;		// reliable to all
const float	MSG_INIT		= 3;		// write to the init string

// misc
const float	A_SHITLOAD		= 9999999;
const float	AUTOAIM_DIST	= 2048;

const float	DEBUG_DMG_PER_ROCKET	= 180;
const float	DEBUG_DMG_PER_NAIL		= 9;
const float	DEBUG_DMG_PER_SHELL		= 24;
const float	DEBUG_DMG_PER_CELL		= 30;

const float	MAX_AMMO_SHELLS			= 100;
const float	MAX_AMMO_NAILS			= 200;
const float	MAX_AMMO_ROCKETS		= 100;
const float	MAX_AMMO_CELLS			= 100;

//================================================

