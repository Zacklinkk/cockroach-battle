extends SceneTree
var main
var failures: Array = []
var checks = 0

func _initialize() -> void:
	call_deferred("verify")

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label);push_error(label)

func arena() -> Dictionary:
	for e in main.enemies:
		if is_instance_valid(e.node): e.node.queue_free()
	main.enemies.clear()
	main.room.blocks.clear()
	main.room.rebuild_navigation()
	main.player_pos = Vector3.ZERO
	main.runes = {}
	main.phase = "playing"
	main.invulnerable = 100
	main.encounter = main.Balance.room_stats(1)
	var e = main.spawn_enemy(Vector3(0,0,-1.5),false)
	e.hp = 10000
	for key in e.durability: e.durability[key] = 10000
	return e

func verify() -> void:
	main = load("res://main.gd").new()
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.rng.seed = 812
	main.start_run("wand")
	check(main.weapon=="slipper","Every new run starts with the slipper regardless of requested weapon")
	var near = 0
	var far_safe = true
	for e in main.enemies:
		if e.mother: continue
		var distance = e.pos.distance_to(main.player_pos)
		if distance<11: near += 1
		else: far_safe = far_safe and distance>=17
	check(near==3 and far_safe,"Only three ordinary roaches start nearby; distant crowd is outside 17 units")
	for i in range(60): main._process(0.05)
	check(main.life==3 and main.phase=="playing","First three seconds allow a stationary new player to orient safely")
	for room_number in range(1,5):
		var a = main.Balance.room_stats(room_number)
		var b = main.Balance.room_stats(room_number+1)
		check(b.health>a.health and b.chase_speed>a.chase_speed and b.armor>a.armor and b.control_resist>a.control_resist and b.near_count>a.near_count,"Difficulty increases from room "+str(room_number)+" to "+str(room_number+1))
	var e = arena()
	e.pos = Vector3(10,0,0)
	main.combat_noise(Vector3.ZERO,13)
	check(e.state!="investigate","First-room slipper sound does not pull enemies from ten units away")
	main.encounter = main.Balance.room_stats(4)
	main.combat_noise(Vector3.ZERO,13)
	check(e.state=="investigate","Later-room combat attracts more distant enemies")
	e = arena()
	main.runes = {"thicksole":1}
	var damage: Array = []
	for i in range(3):
		main.rng.seed = 4
		var before = e.hp
		main.attack(e)
		damage.append(before-e.hp)
	check(main.slipper_swings==3 and damage[2]>damage[0]*1.45,"Third slipper swing is stronger and counts once per swing")
	e = arena()
	main.runes = {"rend":1}
	e.armor = 0.2
	for i in range(3): main.hit_enemy(e,10,"slipper",Vector3.ZERO,0,false,"body")
	check(e.rend_time==0 and e.rend_hits==3,"Rend waits for four direct hits")
	main.hit_enemy(e,10,"dot",Vector3.ZERO,0,false,"body")
	check(e.rend_hits==3,"Damage over time cannot charge rend")
	var hp = e.hp
	main.hit_enemy(e,10,"slipper",Vector3.ZERO,0,false,"body")
	check(e.rend_time==4 and e.rend_hits==0 and hp-e.hp>13,"Fourth hit adds one rupture and applies armor reduction without recursion")
	main.update_enemies(2.1)
	main.hit_enemy(e,10,"slipper",Vector3.ZERO,0,false,"body")
	main.update_enemies(2.1)
	check(e.rend_time==0 and e.rend_hits==0,"Rend window and armor reduction expire")
	e = arena()
	main.runes = {"ice":1,"resonance":1}
	e.chill = 0.8
	e.freeze = 1
	hp = e.hp
	main.hit_enemy(e,10,"lightning",Vector3.ZERO,1,false,"body")
	check(is_equal_approx(hp-e.hp,16.5) and e.freeze==1,"Frost resonance amplifies lightning without unfreezing")
	hp = e.hp
	main.hit_enemy(e,10,"lightning",Vector3.ZERO,1,false,"body")
	check(is_equal_approx(hp-e.hp,10),"Resonance cooldown prevents repeated chain amplification in one instant")
	e.freeze = 0
	e.resonance_cd = 0
	e.chill = 1
	main.hit_enemy(e,10,"zapper",Vector3.ZERO,0,false,"body")
	check(e.chill>1,"Resonance preserves frost buildup on unfrozen targets")
	main.runes = {}
	main.set_weapon("slipper")
	check(not main.rune_available("resonance") and not main.rune_available("spread"),"Dependent runes do not appear without their prerequisite effects")
	main.level = 1
	main.xp = main.xp_need
	main.level_up()
	check(main.cards.size()==3 and main.cards[2].type=="weapon" and main.cards[2].id in ["wand","spray","staple"],"First upgrade has two runes and a basic replacement weapon")
	main.choose_reward(2)
	check(main.weapon!="slipper" and main.phase=="playing","Choosing a weapon reward replaces the starter")
	main.level = 4
	check(main.reward_weapons().has("chainsaw") and main.reward_weapons().has("zapper"),"Level four unlocks chainsaw and zapper offers")
	main.level = 6
	check(main.reward_weapons().has("vacuum") and main.reward_weapons().has("slingshot"),"Level six unlocks the remaining weapons")
	main.room_number = 5
	main.phase = "win"
	main._on_command([JSON.stringify({"action":"next"})])
	check(main.room_number==5 and main.phase=="win","Final victory cannot advance into a sixth room")
	main._on_command([JSON.stringify({"action":"start","weapon":"chainsaw"})])
	check(main.room_number==1 and main.weapon=="slipper" and main.runes.is_empty(),"Replaying after the ending starts a fresh slipper run")
	for enemy in main.enemies.duplicate(): main.kill_enemy(enemy,Vector3.ZERO)
	main.xp = main.xp_need+100
	main.hitstop = 0
	main._process(0.05)
	check(main.phase=="win","Clearing the final enemy takes priority over an earned upgrade")
	print(JSON.stringify({"checks":checks,"failures":failures,"result":"PASS" if failures.is_empty() else "FAIL"}))
	quit(0 if failures.is_empty() else 1)
