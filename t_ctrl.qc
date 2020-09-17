/*
================================================================

CONTROL FLOW

All the relays, counters, and other gates that manipulate the firing
of other entities' .use() functions

including entities that aren't real triggers but are named trigger_*

================================================================
*/

void() trigger_relay_msg =
{
	activator = self.enemy;
	SUB_PrintMessage();
	
	if (self.noise)
		sound (self, CHAN_VOICE, self.noise, 1, ATTN_NORM);

	if (self.spawnflags & 1)
		self.message = string_null;
}

void() trigger_relay_use =
{
	if (self.customflags & CFL_LOCKED)
	{
		dprint("  trigger_relay is locked: not relaying\n");
		return;
	}
	
	self.enemy = activator;
	
	if (self.spawnflags & 2)
	{
		SUB_CountTargets();
		SUB_UseRandomTarget();
	}
	else SUB_UseTargets();

	if (self.spawnflags & 1)
		self.message = string_null;
	
	if (self.noise != string_null)
	{
		if (self.delay > 0)
			sound_delayed(self, self.noise, 1, ATTN_NORM, self.delay);
		else
			sound (self, CHAN_VOICE, self.noise, 1, ATTN_NORM);
	}	
	
	playercount_convert(count);
	if (self.count > 0)
	{
		self.count -= 1;
		if (self.count == 0)
			remove(self);
	}
}


/*QUAKED trigger_relay (.5 .0 .5) (-8 -8 -8) (8 8 8) MSG_ONCE RANDOM
This fixed size trigger cannot be touched, it can only be fired by other events.  Target this with a target_lock to selectively disable/reenable it for logic fun.

Keys:
"delay" delay before firing (after trigger)
"killtarget" removes target
"message" displayed when fired
"target/2/3/4" fires target when triggered
"targetname"  entity name (required)
"sounds" same as other triggers, plays after 'delay'
"noise" or, pick any wav
"count" only fire this many times, then auto self-destruct

Spawnflags:
"MSG_ONCE"	only print its message on the first firing, otherwise it prints every time
"RANDOM"	randomly fire one of its targets (and/or kill one of its killtargets) instead of them all
*/
/*FGD
@PointClass base(Appearflags, TriggerSounds, Target, Targetname) = trigger_relay : "Trigger: Relay"
[
	spawnflags(flags) =	[
		1 : "Only print message once" : 0
		2 : "Choose one target at random" : 0
	]
	message(string) : "Print when triggered"
	count(integer) : "Limit uses" : 0
]
*/
void() trigger_relay =
{
	if (!SUB_ShouldSpawn()) return;
	if (self.targetname == string_null)
	{
		// IW fix - no longer objerror, which is a game-ender in old engines
		dprint3("WARNING: trigger_relay at ", vtos(self.origin), "not targeted by anything");
		remove(self);
		return;
	}
		
	self.use = trigger_relay_use;
	InitTriggerSounds();
}


//=============================================================================

float(entity inc) target_state_compare =
{
	float out = FALSE;
	if (self.style & 1)
		out |= (inc.state == self.state);
	if (self.style & 2)
		out |= (inc.state > self.state);
	else if (self.style & 4)
		out |= (inc.state < self.state);
	
	if (self.spawnflags & 2) return !out;
	return out;
}

void() target_state_use =
{
	if (self.customflags & CFL_LOCKED)
		return;

	if (self.spawnflags & 1)
	{
		entity inc;
		inc = find(world, targetname, self.include);
		if (inc)
		{
			if (target_state_compare(inc))
				SUB_UseTargets();
		}			
		return;
	}
	
	playercount_convert(count);
	
	float mx = max(1, self.count);
	if (self.spawnflags & 2)
	{
		self.state = self.state - 1;
		if (self.state < 0) self.state = mx;
	}
	else
	{
		self.state = self.state + 1;
		if (self.state > mx) self.state = 0;
	}
	//bprint3("state is now ",ftos(self.state),"\n");
}

/*QUAKED target_state (.5 .0 .5) (-8 -8 -8) (8 8 8) RELAY INVERSE 
Numeric variable. set 'state' to initial value. triggering this will cycle the value (swapping 0 and 1).

If "RELAY" is checked, it acts as a relay instead of holding state. It fires its targets based on the value of the 'state' member of another entity, specified by setting 'state' to the value it has to match and 'include' to that entity's targetname. This can be another target_state, or any other entity which has a 'state', such as doors or plats.
	0: off (lights/etc)/top (plats)/open (doors)/pushed (buttons)
	1: on (lights/etc)/bottom (plats)/closed (doors)/unpushed (buttons)
	2: going up (plats)/opening (doors)/pushing (buttons)
	3: going down (plats)/closing (doors)/unpushing (buttons)
A trigger_counter's 'state' is its current trigger count.

Keys:
"style" comparison to make if RELAY
	1: self = include (default)
	2: self < include
	3: self <= include
	4: self > include
	5: self >= include
"count" if > 1, state will be incremented on each trigger to a maximum of 'count' before cycling to 0
"delay" delay before firing (after trigger)
"target2/3/4/kill" targets to fire if RELAY

Spawnflags:
"INVERSE"	if RELAY, will fire if state is anything other than a match. otherwise, will decrement when triggered instead of increment
*/
/*FGD
@PointClass base(Appearflags, Target, Targetname) = target_state : "Target : State. Holds a numeric variable, or tests other entities for theirs before firing targets."
[
	spawnflags(flags) =	[
		1 : "Relay" : 0
		2 : "Inverse" : 0
	]
	include(target_destination) : "Entity to monitor"
	count(integer) : "Max state to cycle to"
	state(integer) : "State to monitor"
]
*/
void() target_state =
{
	if (!SUB_ShouldSpawn()) return;
	if (self.targetname == string_null)
		objerror("target_state not targeted by anything");
	if (self.spawnflags & 1 && self.include == string_null)
		objerror("target_state relay has no include");

	if (self.style < 1 || self.style > 5)
		self.style = 1;
		
	self.use = target_state_use;
}

//=============================================================================

void(string tname) target_lock_do =
{
	if (tname == string_null) return;

	local entity t, c;
	t = world;
	
	do	{
		t = find (t, targetname, tname);
		if (!t) break;
		
		// outer loop finds doors targeted directly
		if (t.classname == "func_door")
		{
			if (self.state) door_unlock(t);
			else door_lock(t);
			// inner loop checks for doors that are linked by touch and not targetname
			c = t.enemy;
			do {
				if (c.targetname != t.targetname)	// outer loop will find this one
					if (self.state) door_unlock(t);
					else door_lock(t);
				c = c.enemy;
			} while (c != t);
		}
		else if (t.classname == "func_plat")
		{
			if (self.state) plat_unlock(t);
			else plat_lock(t);
		}
		// dumb way to make coop starts visible/invisible to the cyclical spawnpoint search 
		// code without making that code overly complex
		else if (t.classname == "info_player_coop")
		{
			t.classname = "info_player_coop_notyet";
		}
		else if (t.classname == "info_player_coop_notyet")
		{
			t.classname = "info_player_coop";
		}
		else //if (t.classname == "trigger_relay" || t.classname == "func_button")
		{
			if (self.state)
			{
				t.customflags = not(t.customflags, CFL_LOCKED);
				dprint4(t.classname, " with targetname ", t.targetname, " is unlocked\n");
			}
			else
			{
				t.customflags |= CFL_LOCKED;
				dprint4(t.classname, " with targetname ", t.targetname, " is locked\n");
			}
		}
	} while ( t );
}

void() target_lock_use =
{
	//bprint("in target lock use\n");
	target_lock_do(self.target);
	target_lock_do(self.target2);
	target_lock_do(self.target3);
	target_lock_do(self.target4);
	
	if (self.spawnflags & 4) self.state = 1;
	else if (self.spawnflags & 2) self.state = 0;
	else self.state = 1 - self.state;
}

/*QUAKED target_lock (0 .5 .8) (-8 -8 -8) (8 8 8) START_LOCKED LOCK_ONLY UNLOCK_ONLY
Locks and unlocks targeted entities independent of their toggle/start_open/etc states.  Works on various entities:
- A locked func_door won't respond to touches or triggers. Use this for doors behind temporary bars.
- A locked func_plat behaves as an unreleased LOW_TRIGGER plat
- A locked trigger_relay will not fire or evaluate at all
- Locked path_corners are not considered valid patrol/train destinations
- Locked trigger volumes (once/multi/teleport/secret/changelevel/push/monsterjump) will not activate when touched or triggered

Spawnflags:
"start_locked"	Targeted entities start out locked. 
"lock_only"		Will only lock its targets rather than toggling
"unlock_only"	Will only unlock its targets rather than toggling
*/
/*FGD
@Pointclass base(Target, Targetname, Appearflags) color(192 64 0) size(16 16 16) = target_lock : 
"Locks and unlocks targeted entities independent of their toggle/start_open/etc states.  Works on various entities:
- A locked func_door won't respond to touches or triggers. Use this for doors behind temporary bars.
- A locked func_plat behaves as an unreleased LOW_TRIGGER plat
- A locked trigger_relay will not fire or evaluate at all
- Locked path_corners are not considered valid patrol/train destinations
- Locked trigger volumes (once/multi/teleport/secret/changelevel/push/monsterjump) will not activate when touched or triggered"
[
	spawnflags(flags) = [
		1: "Targeted entities start locked" : 0
		2: "Lock only" : 0
		4: "Unlock only" : 0
	]
]
*/
void() target_lock =
{
	if (!SUB_ShouldSpawn()) return;
	self.use = target_lock_use;
	if (self.spawnflags & 4) self.state = 1;
	else self.state = 0;
	
	if (self.spawnflags & 1)
	{
		self.state = 0;
		self.think = target_lock_use;
		self.nextthink = time + 0.25;
	}
}

//============================================================================


void() counter_use =
{
	playercount_convert(count);
	
	if (time < self.attack_finished) return;
	
	self.state = self.state + 1;
	if (self.state > self.count)
		return;
	
	if (self.state != self.count)
	{
		float rem = self.count - self.state;
		if (activator.classname == "player" && !(self.spawnflags & SPAWNFLAG_NOMESSAGE))
		{
			if (rem >= 6)
				centerprint (activator, "There are more to go ...");
			else if (rem == 5)
				centerprint (activator, "There are 5 more to go ...");
			else if (rem == 4)
				centerprint (activator, "There are 4 more to go ...");
			else if (rem == 3)
				centerprint (activator, "There are 3 more to go ...");
			else if (rem == 2)
				centerprint (activator, "Only 2 more to go ...");
			else
				centerprint (activator, "Only 1 more to go ...");
		}
		return;
	}
	
	if (activator.classname == "player" && (self.spawnflags & SPAWNFLAG_NOMESSAGE) == 0)
		SUB_PrintMessage();
//		centerprint(activator, self.message);
	
	self.enemy = activator;
	if (self.wait >= 0) 
		self.state = 0;	// repeatable
	//multi_trigger ();
	SUB_UseTargetsSilent();
	if (self.wait > 0)
		self.attack_finished = time + self.wait;
}

/*QUAKED trigger_counter (.5 .0 .5) (-8 -8 -8) (8 8 8) NOMESSAGE REPEAT
Acts as an intermediary for an action that takes multiple inputs. 
If nomessage is not set, it will print "1 more.. " etc when triggered and "sequence complete" when finished. After the counter has been triggered "count" times, it will fire all of it's targets and remove itself, unless 'repeat' has been set.

Flags:
"nomessage" disables count display

Keys:
"count" number of triggers needed to fire own target, default is 2
"target"  entity to trigger (required)
"targetname"  entity name (required)
"message"	override text to print on completion
*/
/*FGD
@PointClass base(Appearflags, Target, Targetname) = trigger_counter : "Trigger: Counter" 
[
	spawnflags(flags) = [ 
		1: "No Message" : 0
		2: "Repeat" : 0
	]
	count(integer) : "Count before trigger" : 2
	message(string) : "Message"
]
*/
void() trigger_counter =
{
	if (!SUB_ShouldSpawn()) return;
	
	if (!self.wait)
	{
		if (self.spawnflags & 2)
			self.wait = 1;
		else
			self.wait = -1;
	}
	
	if (!self.count)
		self.count = 2;
		
	if (self.spawnflags & SPAWNFLAG_NOMESSAGE)
		self.message = string_null;
	else if (self.message == string_null)
		self.message = "Sequence completed!";
		
	//self.cnt = self.count;

	self.use = counter_use;
}


//============================================================================


void() timer_think =
{
	playercount_convert(count);
	
	if (self.state == self.count) {
		//SUB_Remove();
		return;
	}

	if (self.nextthink > time)	// turn off again
	{
		self.nextthink = 0;
		return;
	}		

	self.nextthink = time + self.wait + random() * self.rand;
	self.state += 1;
	activator = self.owner;
	SUB_UseTargets();
}

void() timer_use =
{
	dprint("in timer_use\n");
	
	self.owner = activator;
	self.state = 0;
	timer_think();
}

/*QUAKED trigger_timer (.5 .5 .5) (-8 -8 -8) (8 8 8) START_ON
Fires its targets once every "wait" seconds. If "count" is set, it will only fire that many times and then stop. Set "rand" to add a random extra delay to the wait interval.

SPAWNFLAGS
START_ON: do not wait until triggered to begin firing
*/
/*FGD
@PointClass base(Appearflags, Target, Targetname) = trigger_timer : "Trigger: Timer" 
[
	spawnflags(flags) = [ 
		1: "Start On" : 0
	]
	count(integer) : "Limit" : 0
	wait(string) : "Interval"
	rand(string) : "Random Extra Interval"
]
*/
void() trigger_timer =
{
	if (!SUB_ShouldSpawn()) return;
	if (!self.wait)
		self.wait = 1;
	if (self.rand < 0)
		self.rand = 0;
		
	self.think = timer_think;
	self.use = timer_use;

	if (self.spawnflags & 1)
	{
		self.nextthink = time + self.wait;
	}
	
	if (!self.count)
		self.count = -1;
}

//============================================================================

float SPAWN_TPC_LT_EQUAL = 1;
float SPAWN_TPC_BY_TWOS = 2;

void() target_playercount_go =
{
	float f;
	if (self.spawnflags & SPAWN_TPC_BY_TWOS)
		f = 2;
	else
		f = 1;
		
	if (self.spawnflags & SPAWN_TPC_LT_EQUAL)
	{
		SUB_UseTargetsByField(target);
		if (clients > 1 * f) SUB_UseTargetsByField(target2);
		if (clients > 2 * f) SUB_UseTargetsByField(target3);
		if (clients > 3 * f) SUB_UseTargetsByField(target4);
	}
	else
	{
			 if (clients <= 1 * f) SUB_UseTargetsByField(target);
		else if (clients <= 2 * f) SUB_UseTargetsByField(target2);
		else if (clients <= 3 * f) SUB_UseTargetsByField(target3);
		else if (clients <= 4 * f) SUB_UseTargetsByField(target4);
	}

	SUB_KillTargets(self.killtarget);
}

void() target_playercount_go_delay =
{
	target_playercount_go();
	remove(self);
}

void() target_playercount_use =
{
	entity tpc;
	if (self.delay > 0)
	{
		tpc = spawn();
		tpc.spawnflags = self.spawnflags;
		SUB_CopyTargets(tpc);
		tpc.nextthink = time + self.delay;
		tpc.think = target_playercount_go_delay;
		return;
	}
	target_playercount_go();
}

/*QUAKED target_playercount (.5 .5 .5) (-8 -8 -8) (8 8 8) LT_EQUAL BY_TWOS
Checks the number of players currently connected when triggered, and fires exclusively one of target/2/3/4 depending on the count. If one player is connected, it only fires 'target', if two are connected it fires 'target2', and so on. 

SPAWNFLAGS
LT_EQUAL: Fires all targetnames UP TO the current player count (so with four players connected, all four targets would fire instead of just target4)
BY_TWOS: require double the number of players for each threshhold (for scaling up to 8 players)
*/
/*FGD
@PointClass base(Appearflags, Target, Targetname) = target_playercount : "Target: Playercount" 
[
	spawnflags(flags) = [ 
		1: "Less Or Equal" : 0
		1: "Two Players Per" : 0
	]
]
*/
void() target_playercount =
{
	if (!SUB_ShouldSpawn())
		return;
		
	self.use = target_playercount_use;
}
