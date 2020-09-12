# copper

A guide to compiling Copper into progs.dat, and some notes on making the best use of new methods in the code.

---

## Compiling

Full **QuakeC** source is [included with the mod](/copper/download). You may, and are encouraged to, use it as a base for additional mods, adopting or adapting features, or merely to learn from. Compiling it requires [FTEQCC](http://fte.triptohell.info/) (any version from at least 2018), by Spike. Other compilers may work, provided they support a few syntax upgrades (such as field masking and not requiring the '**local**' keyword) as well as **#pragma autoproto**. If you're unsure if your compiler will work, try it and it should tell you. :)

## A Note On Extensions

When extending Copper for your own mod, I strongly encourage you to use the complete corpus of Copper [gameplay tweaks](/copper/changes) if you use any, rather than sampling what may be your favorites. This will avoid fracturing for players the 'gameplay base' that Copper strives to provide. Copper touches many aspects of the game in small but significant ways. If every mod were to include a different subset of these, the play experience for each player would be muddled by a trepidatious series of accidental discoveries of which way the player should expect them all to function <i>this</i> time, rather than being able to take the entire package as a given <i>every</i> time.

Consider the conventional Z-aware Ogres, the ones with perfect aim. When you play a Quake add-on that includes them, how do you learn they're there? Is it in the readme? Does the game warn you? Or do you find out the hard way, the first time one shoots you in the face from an angle you thought safe? Now consider this problem of relearning part of the game as you play, but multiplied across every alteration in Copper. Players could no longer take the presence of any one Copper feature as an indicator of the presence of any other, and while your mod may be that little bit more like the Quake you want others to play, such subtle but constant confusion would, I feel, make Quake a little worse for everyone.

Kell released Quoth closed-source, and cited as a reason a desire to avoid such fracturing caused by "everyone compiling their own interpretations of Quoth." While I feel that's a little too protective, I understand the sentiment. However, a great deal of the mapper features in Copper originate from Quoth, and had to be re-engineered from scratch on my part without any source code to work from, and I won't let any of my personal (and possibly selfish) reservations lead me to do the same to you. The source is provided happily, because this is still better for Quake overall no matter what people may do with it. Everything will work out okay in the end.


## Entity Definitions

id's original means of generating editor entity definitions was to overload block comments. Every comment block that opened with **/\*QUAKED** was considered an entity class definition, whose first line was treated as a formatted metadata definition of name, size, color, and spawnflag names (point/brush status was inferred from presence or absence of a defined size). Everything else in the comment was treated as a descriptive docstring. QuakeEd itself simply scanned the QuakeC game source for these comments directly and built its definition library from there. **/\*QUAKED\*/** definitions could thus be kept alongside the code for the very entities they described, making it easy to keep them updated and accurate. 

Future Radiant map editors that built on QuakeEd moved toward loading them all from one file, with a .def extension, but not changing or extending the syntax at all. The far more common format in use now for entity definitions is Worldcraft's FGD format, now used most prominently by Kristian 'sleepwalkr' Duske's [Trenchbroom](https://kristianduske.com/trenchbroom/) editor, because it supports quite a bit more metadata regarding keyvalues and their required types, while the QuakeEd/def system only supports this insofar as there's a large block of text in which developers can describe them in plain English.

I have chosen to support entity definition maintenance for FGD in the same way that the QuakeC source originally supported it for QuakeEd: by using comments within the source itself. The Copper source code still includes **/\*QUAKED\*/** comments, adding and updating them wherever relevant to keep them up to date, because while Radiant and QuakeEd users are rare today, they do still exist. :) You will commonly find these paired with comment blocks beginning with **"/\*FGD"** now as well. While editors like Trenchbroom do not scan multiple files looking for such comments, the notation made it easy for me to automate extracting the two types of comment blocks and compiling their contents into respective .def and .fgd files. 

The Python scripts I used for these two tasks are included with the QuakeC source. They should Just Work(tm) provided Python 3+ is installed correctly, which is left as an exercise for the reader. 


	
## Code Reference

Here are some handy notes on important functions:

### enemy\_vispos(), ai.qc
Any time a monster would use the vector stored as **self.enemy.origin**, be it for a line of sight test, launching a projectile or some other attack, or any other purpose, **enemy\_vispos()** is called instead. Normally it simply returns self.enemy.origin anyway, but if self.enemy has a Ring of Shadows, it instead returns an origin offset in a standardized noisy way, so that the Ring confuses all monsters identically for gameplay purposes. Be aware that any time you bypass this function and use self.enemy.origin directly, the code in question will not be affected by invisibility unless you check the **IT\_INVISIBILITY** flag or **enemy.invisible\_finished** manually (the most obvious example being **ShalHome()** in m\_shalrath.qc).

### traceline2(), projectiles.qc
**traceline()** can only ignore one entity at a time. To support the **'notrace 1'** keyvalue for creatureclip, secondary traces have to be made to continue the trace through any hit notrace brushmodels which should be skipped by the trace. **traceline2()** is a wrapper for this functionality, and will perform any necessary extra traces automatically for you, modifying all the output trace\_\* global variables to contain accurate unified results as if a single trace had been performed. Thus you can use it exactly the same way you would traceline(), and in fact, you probably should pretty much everywhere.

Note that this is not the same code that enables shotgun penetration, although it is similar. That code is in **FireBullets()** in w\_shotguns.qc (because it needs to apply the special case of adding damage to each TAKEDAMAGE target it passes through). You will notice that even this function still uses traceline2(), because players should be able to fire shotguns through both dying monsters and notrace brushmodels at the same time.

### CheckProjectilePassthru() & etc, projectiles.qc
traceline2() may work for hitscan and line of sight traces passing through a 'notrace' bmodel, but does not help in the case of point entities we would also expect to pass through them, such as nails, grenades, or gibs. These required a little more work. To enable such entities to pass through creatureclip, their touch functions should call **CheckProjectilePassthru()** and return without doing anything if it returns true. Note that this code IS used for allowing point entities and projectiles to pass through monsters in death animations, unlike traceline2() and FireBullets().

Much more information on understanding and working with point entity passthrough can be had in the comment blocks of projectiles.qc.

### launch_projectile(), projectiles.qc
Code duplication in projectile and shooting functions across the codebase was cut down for convenience, and all such functions were gathered together into this file. All nails, rockets, lavaballs, grenades, etc, are spawned by one function or another that either calls **launch\_projectile()** or something else which calls it and modifies the projectile it returns.

### CheckValidTouch(), items.qc
Checks at the top of touch functions whether 'other' is a player, is alive, and isn't in NOCLIP were becoming ubiquitous across all triggers and items. Any touch function activated only by players can call this for all-in-one confirmation. 

### mon_spawner(), monsters.qc
Copper unifies a monster, a triggerable monster spawn, and a repeatedly-triggerable monster spawner into the monster itself. A monster's spawn function is split into two, with initial game frame necessities (such as precaches) separated from actual spawn completion code (such as **walkmonster\_start()**). Initial setup remains in the monster's classname function, and spawn completion is moved to a second function, universally named **[monster\_classname]\_spawn()**.

The unification is accomplished by way of function objects. First, the classname function calls **monster\_spawnsetup()** and passes it the name of a function which will spawn the monster in question when called. This should be a single-line function (universally named **[monster\_classname]\_spawner()**) declared uniquely for each monster, which injects some universal monster spawning code into our monster's spawn completion function by calling **mon\_spawner\_use()** and passing the spawn completion function as a parameter. This is a little convoluted, but is necessary so that each monster spawner's Use function is both customized to one monster and callable with no parameters (required by the **.th\_use** field prototype). monster\_spawnsetup() checks all the possible spawner configuration states and spawnflags by itself, which are universal across all non-boss monsters. It returns True if the classname function should stop before continuing on to spawn the monster directly (ie, call the spawn completion function). 

Examine any monster's source file (m\_\*.qc) and scroll to the bottom for an example. To support triggerable monster spawning on a new monster, you need only ensure spawning code is split in the same way, and uses monster\_spawnsetup() and mon\_spawner\_use() the same way. Note that spawnflags 1-5 and 8 are already reserved for spawner configuration, so new monsters will have to make do with flags 6 and 7. There are plenty of spare keyvalues should you feel you need more flavors than that. (at which point the game designer in me asks, "shouldn't that just be more than one kind of monster?")

