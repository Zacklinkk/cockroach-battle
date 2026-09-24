extends SceneTree
var failures: Array = []
var checks = 0
func _initialize() -> void:
	call_deferred("verify")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)
func verify() -> void:
	var main = load("res://main.gd").new()
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.start_run("chainsaw")
	check(main.weapon=="slipper","The starting weapon cannot be bypassed by a caller")
	main.set_weapon("chainsaw")
	main.rng.seed = 42
	var e = main.spawn_enemy(Vector3(0,0,6),false)
	e.node.rotation.y = 0
	var front_hit = main.ray_part(e,Vector3(-0.14,0.28,4.5),Vector3(-0.14,0.28,6.7))
	check(front_hit.get("part","")=="eyes","Front projectile ray hits the eyes before shell")
	var rear_hit = main.ray_part(e,Vector3(-0.14,0.35,7.4),Vector3(-0.14,0.35,5.5))
	check(str(rear_hit.get("part","")).begins_with("wing"),"Rear projectile ray hits a wing")
	var miss_hit = main.ray_part(e,Vector3(3,0.3,4),Vector3(3,0.3,8))
	check(miss_hit.is_empty(),"A projectile outside the insect misses every part")
	main.break_part(e,"leg_0",Vector3(1,0,6),1)
	check(e.lost_legs==1 and not e.parts.leg_0.visible,"A severed leg disappears and applies movement penalty")
	check(main.fragments.size()==1 and main.fragments[0].node.get_child(0).mesh==e.parts.leg_0.mesh,"Detached model is the exact hit part")
	e.flight = 0.8
	main.break_part(e,"wing_l",Vector3(1,0,6),1)
	check(e.wings==1 and e.flight==0 and not e.parts.wing_l.visible,"Wing loss cancels flight")
	main.break_part(e,"eyes",Vector3(0,0,4),1)
	main.player_pos = Vector3(0,0,5)
	main.update_enemies(0.1)
	check(e.blind and e.state!="chase" and e.memory==0,"Blind enemy does not re-acquire visible player")
	main.pin_enemy(e)
	var pos = e.pos
	for i in range(39): main.update_enemies(0.1)
	check(e.pin>0 and e.pos.distance_to(pos)<0.01,"Staple holds enemy before four seconds")
	main.update_enemies(0.11)
	check(e.pin==0 and not is_instance_valid(e.pin_fx),"Staple releases after four seconds")
	var hp_before = e.hp
	main.hit_enemy(e,5,"dot",e.pos,1,false)
	check(e.hp<hp_before and main.xp>0,"Effective hits grant experience before a kill")
	main.xp = main.xp_need+1
	main.level_up()
	check(main.phase=="upgrade" and main.cards.size()==3,"Experience opens exactly three paused choices")
	var time_before = main.time
	main._process(0.05)
	check(main.time==time_before,"Upgrade selection pauses combat clock")
	main.choose_reward(0)
	check(main.phase=="playing" and main.runes.size()==1,"Choosing a rune resumes combat")
	main.runes = {"ice":2,"shatter":1,"multi":2,"bounce":1,"anatomy":1,"sawdance":1}
	check(main.get_combos().has("碎冰连爆") and main.get_combos().has("交叉弹幕") and main.get_combos().has("断肢震荡"),"Universal and exclusive combos coexist and stack")
	main.phase = "win"
	var old_level = main.level
	main._on_command([JSON.stringify({"action":"next"})])
	check(main.room_number==2 and main.level==old_level and main.r("ice")==2 and main.weapon=="chainsaw","Next room inherits level, weapon and stacked runes")
	main.life = 3
	var attacker = main.enemies[1]
	main.damage_player(attacker)
	main.invulnerable = 0
	main.damage_player(attacker)
	main.invulnerable = 0
	main.damage_player(attacker)
	check(main.phase=="dead" and main.life==0,"Third contact ends the run")
	main.start_run("staple")
	check(main.runes.is_empty() and main.level==1 and main.room_number==1 and main.life==3,"Failure restart resets all run growth")
	# Each weapon gets a clear arena: prior targets must not intercept a test shot.
	for id in main.WEAPONS:
		for old in main.enemies:
			if is_instance_valid(old.node): old.node.queue_free()
		main.enemies.clear()
		for shot in main.shots:
			if is_instance_valid(shot.node): shot.node.queue_free()
		main.shots.clear()
		main.set_weapon(id)
		var target = main.spawn_enemy(main.player_pos+Vector3(0,0,-1.5),false)
		target.hp = 500
		main.runes = {"ice":1,"fire":1,"lightning":1,"multi":1,"bounce":1,"pierce":1,"anatomy":1,"shatter":1,"wall":1}
		target.node.rotation.y = 0
		main.attack(target)
		for i in range(20): main.update_shots(0.025)
		check(target.hp<500,"Weapon produces damage: "+id)
	# Restore a real room, including its mother, after the isolated weapon arena.
	main.start_run("wand")
	for enemy in main.enemies.duplicate():
		if not enemy.dead: main.kill_enemy(enemy,Vector3.ZERO)
	main.xp = 0
	main.hitstop = 0
	main.phase = "playing"
	main._process(0.02)
	check(main.phase=="win","Victory requires mother and all surviving roaches to be gone")
	print(JSON.stringify({"checks":checks,"failures":failures,"result":"PASS" if failures.is_empty() else "FAIL"}))
	quit(0 if failures.is_empty() else 1)
