extends SceneTree
var failures: Array = []
var checks = 0
var main

func _initialize() -> void:
	call_deferred("verify")

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func arena() -> void:
	for e in main.enemies:
		if is_instance_valid(e.node): e.node.queue_free()
		if is_instance_valid(e.pin_fx): e.pin_fx.queue_free()
	main.enemies.clear()
	for item in main.fx_nodes:
		if is_instance_valid(item.node): item.node.queue_free()
	main.fx_nodes.clear()
	for s in main.shots:
		if is_instance_valid(s.node): s.node.queue_free()
	main.shots.clear()
	main.room.blocks.clear()
	main.room.rebuild_navigation()
	main.player_pos = Vector3.ZERO
	main.player_velocity = Vector3.ZERO
	main.runes = {}
	main.invis_time = 0
	main.invulnerable = 100
	main.time = 30
	main.phase = "playing"
	main.encounter = main.Balance.room_stats(2)
	main.encounter.noise_scale = 1.0
	main.room_number = 2

func tick(seconds: float) -> void:
	for i in range(roundi(seconds/0.05)):
		main.time += 0.05
		main.update_enemies(0.05)

func verify() -> void:
	main = load("res://main.gd").new()
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.rng.seed = 738
	main.start_run("wand")
	var near_count = 0
	var unsafe = false
	for e in main.enemies:
		if e.mother: continue
		if e.pos.distance_to(main.player_pos)<10.1: near_count += 1
		if e.pos.distance_to(main.player_pos)<7.0 or not main.room.clear_at(e.pos,0.26): unsafe = true
	check(near_count==3 and not unsafe,"Opening has three scattered enemies with a clear safety annulus")
	check(main.living_count()==22,"First room contains the mother plus 21 ordinary roaches")
	arena()
	var e = main.spawn_enemy(Vector3(0,0,-4),false)
	main.hit_enemy(e,main.WEAPONS.wand.damage,"wand",Vector3.ZERO,0,false,"eyes")
	check(not e.dead and not e.blind and e.hp>70 and e.durability.eyes>0,"One starting wand hit cannot kill or blind a healthy roach")
	check(main.WEAPONS.wand.range<main.encounter.sight,"A healthy roach sees the player before entering starter wand range")
	var one = main.Balance.room_stats(1)
	var two = main.Balance.room_stats(2)
	var five = main.Balance.room_stats(5)
	check(one.health<two.health and two.health<five.health and one.part_scale<five.part_scale and five.armor>two.armor,"Health, anatomical durability and armor increase across rooms")
	check(one.near_count<two.near_count and two.near_count<five.near_count and five.control_resist>two.control_resist,"Starting encirclement and control resistance increase across rooms")
	arena()
	e = main.spawn_enemy(Vector3(10,0,0),false)
	main.combat_noise(Vector3(2,0,0),12)
	check(e.state=="investigate" and e.target==Vector3(2,0,0),"Out-of-sight enemy investigates a combat event's position")
	main.invis_time = 20
	main.player_pos = Vector3(-9,0,-9)
	tick(0.5)
	check(e.target==Vector3(2,0,0) and e.pos.x<10,"Hearing does not reveal invisible player's new location")
	arena()
	e = main.spawn_enemy(Vector3(0,0,-4),false)
	main.break_part(e,"eyes",Vector3.ZERO,1)
	main.combat_noise(Vector3(1,0,-2),10)
	tick(0.1)
	check(e.blind and e.state=="investigate" and e.target==Vector3(1,0,-2),"Blind roach can investigate sound but cannot visually reacquire player")
	arena()
	main.room.blocks.append(Rect2(Vector2(-0.8,-3),Vector2(1.6,6)))
	main.room.rebuild_navigation()
	e = main.spawn_enemy(Vector3(-4,0,0),false)
	main.player_pos = Vector3(4,0,0)
	main.invis_time = 30
	main.combat_noise(main.player_pos,16)
	var around = false
	var clipped = false
	for i in range(180):
		if i%60==0: main.combat_noise(main.player_pos,16)
		main.update_enemies(0.05)
		around = around or absf(e.pos.z)>3.1
		clipped = clipped or not main.room.clear_at(e.pos,0.25)
	check(around and not clipped and e.pos.distance_to(main.player_pos)<2,"Attracted enemy routes around a large obstacle without clipping through it")
	arena()
	e = main.spawn_enemy(Vector3(0,0,-3),false)
	e.dash_cd = 0
	var start: Vector3 = e.pos
	main.update_enemies(0.05)
	check(e.attack_state=="windup" and e.pos.distance_to(start)<0.01,"Rush starts with a readable stationary windup")
	var direction: Vector3 = e.dash_dir
	main.player_pos = Vector3(2,0,0)
	tick(main.encounter.dash_windup+0.01)
	check(e.attack_state=="dash" and e.dash_dir==direction,"Rush commits to a direction instead of homing during the dash")
	start = e.pos
	main.update_enemies(0.05)
	check(e.pos.distance_to(start)>2.8*0.05,"Rush speed exceeds the player's starting running speed")
	tick(0.45)
	check(e.attack_state=="recover" and e.dash_cd>0,"Rush ends in recovery and cooldown")
	arena()
	e = main.spawn_enemy(Vector3(0,0,-4),false)
	e.dash_cd = 100
	main.pin_enemy(e)
	start = e.pos
	tick(2)
	main.pin_enemy(e)
	check(e.pin<2.01 and e.pin>1.9,"Repeated staple hits do not reset the four-second timer")
	tick(1.9)
	check(e.pin>0 and e.pos.distance_to(start)<0.01,"Staple still immobilizes until four seconds")
	tick(0.2)
	main.pin_enemy(e)
	check(e.pin==0 and e.pin_guard>0 and e.pos.distance_to(start)>0.01,"Escaped roach moves and resists immediate re-pinning")
	e.pin_guard = 0
	e.cc_guard = 0
	check(main.request_control(e,"freeze",2),"First eligible freeze takes effect")
	var freeze_duration = e.freeze
	check(not main.request_control(e,"flip",2),"Different control types cannot chain over an existing immobilization")
	tick(freeze_duration+0.2)
	check(not main.request_control(e,"freeze",2),"Recovery grants protection from immediate refreeze")
	e.cc_guard = 0
	main.request_control(e,"freeze",2)
	check(e.freeze<freeze_duration,"Repeated freezes have diminishing duration")
	arena()
	main.set_weapon("wand")
	e = main.spawn_enemy(Vector3(0,0,-4),false)
	e.hp = 300
	main.spawn_shot(Vector3(0,0.6,0),Vector3.FORWARD,e,8,"wand",0)
	e.pos = Vector3(0,0,-8)
	e.node.position = e.pos
	for i in range(70): main.update_shots(0.025)
	check(e.hp==300 and main.shots.is_empty(),"Starter projectile cannot pursue an escaping target beyond its range")
	arena()
	e = main.spawn_enemy(Vector3(0,0,-4),false)
	main.break_part(e,"leg_0",Vector3.ZERO,1)
	check(main.fragments[-1].mat.get_shader_parameter("cuticle")==e.mat.get_shader_parameter("cuticle"),"Detached anatomy preserves the original textured material")
	main.kill_enemy(e,Vector3.ZERO,"chainsaw")
	var scale: Vector3 = e.node.scale
	main.update_effects(0.24)
	check(absf(e.node.rotation.z)>0.1 and absf(e.node.rotation.z)<3.0,"Corpse falls progressively rather than snapping upside down")
	for i in range(115): main.update_effects(0.05)
	check(e.mat.get_shader_parameter("dissolve")>0.3 and e.mat.get_shader_parameter("dissolve")<0.95 and e.node.scale==scale,"Corpse gradually dissolves without shrinking its body")
	for i in range(45): main.update_effects(0.05)
	check(e.node.is_queued_for_deletion(),"Corpse is cleaned up only after completing the fade")
	print(JSON.stringify({"checks":checks,"failures":failures,"result":"PASS" if failures.is_empty() else "FAIL"}))
	quit(0 if failures.is_empty() else 1)
