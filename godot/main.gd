extends Node3D
const Anatomy = preload("res://anatomy.gd")
const G = preload("res://geometry.gd")
const Room = preload("res://room.gd")
const Balance = preload("res://balance.gd")

const WEAPONS = {
	"wand": {"name": "魔杖", "icon": "✦", "desc": "自动追踪魔法弹；最适合多重、弹射与元素组合。", "rate": 0.78, "damage": 8.0, "range": 5.0},
	"spray": {"name": "除虫喷雾", "icon": "≋", "desc": "持续扇形喷射，近处伤害更高；无击退。", "rate": 0.19, "damage": 3.4, "range": 3.5},
	"slipper": {"name": "拖鞋", "icon": "▰", "desc": "近身横扫并击退；暴击会将蟑螂拍翻。", "rate": 0.85, "damage": 24.0, "range": 2.2},
	"staple": {"name": "订书钉", "icon": "⊓", "desc": "钉住 4 秒；重复命中不续时，挣脱后短暂抗钉。", "rate": 0.95, "damage": 10.0, "range": 5.8},
	"chainsaw": {"name": "电锯", "icon": "▥", "desc": "持续近身切割，优先削足；连续命中更猛烈。", "rate": 0.14, "damage": 4.2, "range": 2.0},
	"zapper": {"name": "电蚊拍", "icon": "ϟ", "desc": "近身放电，电流跳向附近目标。", "rate": 0.9, "damage": 18.0, "range": 2.6},
	"slingshot": {"name": "橡皮筋弹弓", "icon": "⋎", "desc": "高速弹丸，较高暴击与部位破坏伤害。", "rate": 0.76, "damage": 13.0, "range": 6.4},
	"vacuum": {"name": "吸尘器", "icon": "◎", "desc": "将虫群吸向前方，积蓄后释放冲击。", "rate": 0.22, "damage": 3.6, "range": 3.5}
}
const RUNES = {
	"damage":{"name":"重击","icon":"◆","desc":"伤害 +22%；碎裂与连锁伤害一起成长。"},
	"speed":{"name":"疾步","icon":"»","desc":"移动速度 +12%，更容易绕到头眼一侧。"},
	"rate":{"name":"疾射","icon":"≡","desc":"攻击速度 +16%，持续武器也会加快。"},
	"multi":{"name":"双头射击","icon":"⋔","desc":"远程多发 1 枚；近战与喷雾扩大攻击角度。"},
	"ice":{"name":"寒霜","icon":"❄","desc":"命中积累冰霜，减速并短暂冻结。"},
	"fire":{"name":"燃烧","icon":"♨","desc":"命中附加持续灼烧；可与扩散、碎裂联动。"},
	"lightning":{"name":"连锁闪电","icon":"ϟ","desc":"命中有概率向邻近目标放电；每层增加跳跃。"},
	"bounce":{"name":"弹射","icon":"↝","desc":"弹丸额外弹向 1 个目标；近战产生跳跃冲击。"},
	"pierce":{"name":"贯穿","icon":"➶","desc":"弹丸额外穿透 1 个目标；近战扩大有效距离。"},
	"wall":{"name":"穿墙","icon":"⇥","desc":"攻击可穿过障碍；穿墙命中伤害每层 +8%。"},
	"area":{"name":"扩张","icon":"◌","desc":"攻击范围与连锁距离 +15%。"},
	"crit":{"name":"致命节奏","icon":"✧","desc":"暴击率 +8%，暴击带来重击与部位破坏。"},
	"shatter":{"name":"碎裂","icon":"✣","desc":"冻结目标受重击或部位脱落时，迸出伤害碎片。"},
	"collision":{"name":"碰撞","icon":"↔","desc":"被击退的蟑螂撞击同类，传递伤害与冲量。"},
	"spread":{"name":"余烬扩散","icon":"⁙","desc":"燃烧目标倒下时，把火焰传给附近蟑螂。"},
	"invisible":{"name":"隐身","icon":"◈","desc":"每隔一段时间隐身，蟑螂暂时失去你的位置。"},
	"anatomy":{"name":"解剖学","icon":"⌖","desc":"部位耐久伤害 +35%；足、眼、翅更容易打坏。"},
	"conductor":{"name":"金属导体","icon":"⊓","desc":"订书钉专属：被钉住的蟑螂成为导电节点。","weapon":"staple"},
	"sawdance":{"name":"锯齿共振","icon":"▥","desc":"电锯专属：切掉部位时释放一圈震荡波。","weapon":"chainsaw"},
	"seek":{"name":"星群","icon":"✦","desc":"魔杖专属：命中生成小型追踪弹；叠加提高小弹伤害。","weapon":"wand"},
	"thicksole":{"name":"厚底重拍","icon":"▰","desc":"拖鞋专属：每第三次拍击额外造成 50% 伤害，强化击退与拍翻；每层再 +15%。","weapon":"slipper"},
	"rend":{"name":"裂甲连击","icon":"⋈","desc":"连续命中同一目标 4 次（间隔不超过 2 秒），引爆裂甲重击并削甲 4 秒；叠加强化伤害与削甲。"},
	"resonance":{"name":"霜雷共振","icon":"❄ϟ","desc":"电击冰冷目标伤害 +65%，冻结时消耗少量冰霜；每层再 +20%，冻结不会被解除。"}
}

var room: Node3D
var player: Node3D
var player_ring: MeshInstance3D
var camera: Camera3D
var player_pos = Vector3(0, 0, 8)
var move_input = Vector2.ZERO
var phase = "start"
var weapon = "slipper"
var runes: Dictionary = {}
var enemies: Array = []
var shots: Array = []
var particles: Array = []
var fragments: Array = []
var labels: Array = []
var fx_nodes: Array = []
var roach_scene: PackedScene
var base_roach_mat: ShaderMaterial
var mother: Dictionary = {}
var life = 3
var level = 1
var xp = 0.0
var xp_need = 22.0
var room_number = 1
var kills = 0
var total_kills = 0
var broken_parts = 0
var time = 0.0
var attack_clock = 0.0
var weapon_recoil = 0.0
var invulnerable = 0.0
var spawn_clock = 0.0
var ui_clock = 0.0
var shake = 0.0
var hitstop = 0.0
var vacuum_counter = 0
var invis_time = 0.0
var invis_clock = 0.0
var rng = RandomNumberGenerator.new()
var js_callback
var ui_ready = false
var cards: Array = []
var next_enemy_id = 0
var active_combos: Array = []
var fx_materials: Dictionary = {}
var demo_time = 0.0
var debug_flags: Array = []
var encounter: Dictionary = {}
var noise_clock = 0.0
var player_velocity = Vector3.ZERO
var slipper_swings = 0
var weapons_seen: Array = ["slipper"]

func _ready() -> void :
	rng.randomize()
	roach_scene = load("res://assets/production/roach/roach.gltf")
	base_roach_mat = G.roach_material()
	make_lighting()
	build_room()
	if OS.has_feature("web"):
		js_callback = JavaScriptBridge.create_callback(_on_command)
		var window = JavaScriptBridge.get_interface("window")
		window.godotCommand = js_callback
		ui_ready = true
		emit("ready", {})
	else:
		debug_flags = OS.get_cmdline_user_args()
		if "--autoplay" in debug_flags:
			start_run("chainsaw")
	push_state()

func make_lighting() -> void :
	var world = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("262321")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c3c8cf")
	env.ambient_light_energy = 0.48
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-56, -28, 0)
	light.light_color = Color("ffe3bb")
	light.light_energy = 1.65
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 35.0
	light.shadow_bias = 0.025
	light.shadow_normal_bias = 0.55
	add_child(light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 17.6
	camera.near = 0.1
	camera.far = 90.0
	camera.current = true
	add_child(camera)

func build_room() -> void :
	for item in fx_nodes:
		if is_instance_valid(item.node): item.node.queue_free()
	fx_nodes.clear()
	for item in particles:
		if is_instance_valid(item.node): item.node.queue_free()
	particles.clear()
	for item in labels:
		if is_instance_valid(item.node): item.node.queue_free()
	labels.clear()
	for e in enemies:
		if is_instance_valid(e.node): e.node.queue_free()
		if is_instance_valid(e.pin_fx): e.pin_fx.queue_free()
	enemies.clear()
	for s in shots:
		if is_instance_valid(s.node): s.node.queue_free()
	shots.clear()
	for d in fragments:
		if is_instance_valid(d.node): d.node.queue_free()
	fragments.clear()
	if is_instance_valid(room): room.queue_free()
	room = Room.new()
	add_child(room)
	room.build(rng.randi())
	encounter = Balance.room_stats(room_number)
	if not is_instance_valid(player):
		player = G.player_model()
		add_child(player)
		player_ring = G.ring(self, Vector3.ZERO, 0.48, 0.025, fx_mat(Color("9ec9c1")))
		player_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	player_pos = Vector3(0, 0, 8)
	player.position = player_pos
	player_ring.position = player_pos + Vector3(0, 0.03, 0)
	set_weapon(weapon)
	var nest = room.nests[rng.randi_range(0, room.nests.size() - 1)]
	mother = spawn_enemy(nest, true)

	var placed = 0
	for i in range(160):
		if placed >= encounter.near_count: break
		var angle = float(i) * 2.399963 + 0.35
		var p = player_pos + Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(7.2, 10.0)
		if room.clear_at(p, 0.85):
			var nearby = spawn_enemy(p, false)
			nearby.wake_at = 2.0 + placed * 5.0 if room_number == 1 else 0.0
			placed += 1
	placed = 0
	for i in range(400):
		if placed >= encounter.far_count: break
		var p = room.random_floor()
		if p.distance_to(player_pos) > encounter.far_distance and room.clear_at(p, 0.85):
			spawn_enemy(p, false)
			placed += 1
	noise_clock = 0.0
	player_velocity = Vector3.ZERO
	spawn_clock = 0.0
	kills = 0
	time = 0.0
	attack_clock = 0.3
	camera.position = player_pos + Vector3(0, 16.5, 14.0)
	camera.look_at(player_pos + Vector3(0, 0, -1.7))

func spawn_enemy(pos: Vector3, is_mother: bool) -> Dictionary:
	var root: Node3D = roach_scene.instantiate()
	root.position = pos
	root.rotation.y = rng.randf_range(0, TAU)
	add_child(root)
	var material = base_roach_mat.duplicate()
	material.set_shader_parameter("phase", rng.randf_range(0, TAU))
	if is_mother:
		root.scale = Vector3.ONE * 1.85
		material.set_shader_parameter("tint", Color(0.8, 0.7, 0.62))
	var anatomy = Anatomy.collect(root)
	var parts: Dictionary = anatomy.parts
	var durability = {}
	var stats = Balance.room_stats(room_number)
	for key in parts:
		var node: MeshInstance3D = parts[key]
		node.material_override = material
		if key == "eyes" or key.begins_with("leg"):
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var base = 38.0 if key.begins_with("leg") else (52.0 if key.begins_with("wing") else 32.0)
		durability[key] = base * stats.part_scale * (8 if is_mother else 1)
	var e = {"animation": anatomy.animation, "skeleton": anatomy.skeleton, "id": next_enemy_id, "node": root, "mat": material, "parts": parts, "durability": durability, "hp": stats.mother_health if is_mother else stats.health, "mother": is_mother, "pos": pos, "vel": Vector3.ZERO, "target": pos, "state": "idle", "memory": 0.0, "wander": rng.randf_range(0, 3), "flash": 0.0, "freeze": 0.0, "chill": 0.0, "burn": 0.0, "dot": 0.0, "pin": 0.0, "flip": 0.0, "flight": 0.0, "flight_cd": rng.randf_range(5, 12), "blind": false, "lost_legs": 0, "wings": 2, "alerted": false, "dead": false, "hit_chain": 0, "chain_t": 0.0, "pin_fx": null,
		"armor": stats.armor, "control_resist": stats.control_resist, "cc_guard": 0.0, "pin_guard": 0.0, "control_fatigue": 0.0, "alert_cd": 0.0, "hit_noise_cd": 0.0, "attack_state": "ready", "attack_timer": 0.0, "dash_cd": rng.randf_range(3.5, 7.0), "dash_dir": Vector3.ZERO, "dash_flying": false, "path": PackedVector3Array(), "path_cd": 0.0, "gait_phase": rng.randf_range(0, TAU), "wake_at":0.0, "rend_hits":0, "rend_window":0.0, "rend_time":0.0, "resonance_cd":0.0}
	e.motion = anatomy.motion
	next_enemy_id += 1
	enemies.append(e)
	return e

func start_run(_id: String = "slipper") -> void:
	# The engine enforces the starter, including restarts and old web commands.
	weapon = "slipper"
	slipper_swings = 0
	weapons_seen = ["slipper"]
	runes.clear()
	active_combos.clear()
	life = 3
	level = 1
	xp = 0
	xp_need = 22
	room_number = 1
	total_kills = 0
	broken_parts = 0
	invulnerable = 2.0
	invis_time = 0
	invis_clock = 0
	build_room()
	phase = "playing"
	emit("toast",{"text":"拖动摇杆走位 · 拖鞋会自动拍击靠近的蟑螂"})
	push_state()

func set_weapon(id: String) -> void:
	weapon = id
	slipper_swings = 0
	if not is_instance_valid(player): return
	var hand = player.get_node("Weapon")
	for c in hand.get_children(): c.queue_free()
	hand.add_child(G.weapon_model(id))

func _on_command(args: Array) -> void:
	if args.is_empty(): return
	var data = JSON.parse_string(str(args[0]))
	if not data is Dictionary: return
	match data.get("action",""):
		"start":
			if phase in ["start","dead"] or (phase=="win" and room_number>=Balance.CAMPAIGN_ROOMS): start_run()
		"move":
			move_input = Vector2(float(data.get("x",0)),float(data.get("y",0))).limit_length()
			return
		"pause":
			if phase == "playing": phase = "paused"
		"resume":
			if phase == "paused": phase = "playing"
		"choose":
			if phase == "upgrade": choose_reward(int(data.get("index",-1)))
		"next":
			if phase == "win" and room_number<Balance.CAMPAIGN_ROOMS:
				room_number += 1
				life = 3
				invulnerable = 2
				build_room()
				phase = "playing"
				emit("toast",{"text":"成长已继承 · 伤势恢复 · 第 "+str(room_number)+" 间"})
	push_state()

func _process(delta: float) -> void :
	var dt = minf(delta, 0.05)
	if phase in ["playing", "start", "dead"]:
		update_effects(dt)
	ui_clock += dt
	if ui_clock > 0.14:
		ui_clock = 0
		push_state()
	if phase == "start":
		demo_time += dt
		player.rotation.y = -0.35
		Anatomy.animate(player.get_meta("rig"), "idle", dt)
		for e in enemies:
			if not e.mother:
				e.node.rotation.y += sin(demo_time + e.id) * dt * 0.2
				Anatomy.animate(e, "idle", dt)
	if phase != "playing": return
	if hitstop > 0:
		hitstop -= dt
		return
	time += dt
	noise_clock = maxf(0, noise_clock - dt)
	invulnerable = maxf(0, invulnerable - dt)
	shake = maxf(0, shake - dt * 2.5)
	var input = move_input
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): input.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): input.y += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): input.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): input.x += 1
	input = input.limit_length()
	if "--autoplay" in debug_flags:
		input = Vector2(sin(time * 0.3), cos(time * 0.3)) * 0.7
	var speed = 2.8 * (1.0 + 0.12 * r("speed"))
	player_velocity = Vector3(input.x, 0, input.y) * speed
	player_pos = room.move_safe(player_pos, Vector3(input.x, 0, input.y) * speed * dt, 0.28)
	player_ring.position = player_pos + Vector3(0, 0.03, 0)
	player.position = player_pos + Vector3(0, absf(sin(time * 13)) * 0.027 * input.length(), 0)
	Anatomy.animate(player.get_meta("rig"), "walk" if input.length() > 0.1 else "idle", dt * (1.8 * input.length() if input.length() > 0.1 else 1.0))
	player.visible = not (invulnerable > 0 and int(time * 12) % 2 == 0)
	weapon_recoil = maxf(0, weapon_recoil - dt * 5.0)
	var hand = player.get_node("Weapon")
	hand.rotation.z = sin(time * 82) * 0.035 if weapon == "chainsaw" else weapon_recoil * 0.1
	hand.rotation.x = - weapon_recoil * 0.38 if weapon in ["slipper", "zapper"] else weapon_recoil * 0.11
	hand.rotation.y = - weapon_recoil * 0.65 if weapon == "slipper" else 0.0
	hand.position.z = - 0.23 + weapon_recoil * 0.035
	update_invisibility(dt)
	var desired = player_pos + Vector3(0, 16.5, 14.0)
	camera.position = camera.position.lerp(desired, minf(1, dt * 8))
	camera.h_offset = rng.randf_range( - shake, shake) * 0.3
	camera.v_offset = rng.randf_range( - shake, shake) * 0.2
	camera.look_at(player_pos + Vector3(0, 0, -1.7))
	var target = nearest(player_pos, weapon_range())
	if not target.is_empty():
		var dir = target.pos - player_pos
		player.rotation.y = lerp_angle(player.rotation.y, atan2( - dir.x, - dir.z), minf(1, dt * 14))
	elif input.length() > 0.1:
		player.rotation.y = lerp_angle(player.rotation.y, atan2( - input.x, - input.y), minf(1, dt * 9))
	attack_clock -= dt
	if attack_clock <= 0 and not target.is_empty():
		attack(target)
		attack_clock = float(WEAPONS[weapon].rate) / (1.0 + 0.16 * r("rate"))
	update_enemies(dt)
	update_shots(dt)
	spawn_clock += dt
	if not mother.get("dead", true) and spawn_clock >= maxf(2.8, encounter.spawn_interval - time / 400.0):
		spawn_clock = 0
		if living_count() < encounter.population_cap:
			for i in range(encounter.spawn_batch):
				if living_count() >= encounter.population_cap: break
				var p = mother.pos + Vector3(rng.randf_range(-1.0, 1), 0, rng.randf_range(0.8, 1.8))
				if room.clear_at(p, 0.4): spawn_enemy(p, false)
	if phase == "playing" and mother.get("dead", false) and living_count() == 0:
		phase = "win"
		player.visible = true
		emit("sound", {"kind": "win"})
		push_state()
		return
	if phase == "playing" and xp >= xp_need: level_up()

func r(key: String) -> int:
	return int(runes.get(key, 0))

func weapon_range() -> float:
	return float(WEAPONS[weapon].range) * (1.0 + 0.15 * r("area") + (0.1 * r("pierce") if weapon in ["chainsaw", "slipper", "zapper", "vacuum", "spray"] else 0.0))

func nearest(pos: Vector3, reach: float, excluded: Array = []) -> Dictionary:
	var best = {}
	var distance = reach
	for e in enemies:
		if e.dead or e.id in excluded: continue
		var d = pos.distance_to(e.pos)
		if d < distance and (r("wall") > 0 or room.visible_line(pos, e.pos)):
			distance = d
			best = e
	return best

func update_invisibility(dt: float) -> void :
	if r("invisible") == 0: return
	invis_clock += dt
	invis_time = maxf(0, invis_time - dt)
	if invis_clock > maxf(7, 17 - r("invisible")):
		invis_clock = 0
		invis_time = 2.5 + 0.5 * r("invisible")
		emit("toast", {"text": "隐身 · 暂时脱离搜寻"})
	if invis_time > 0:
		player.visible = int(time * 8) % 3 != 0


func combat_noise(location: Vector3,radius: float) -> void:
	radius *= float(encounter.get("noise_scale",1.0))
	for e in enemies:
		if e.dead or e.mother or time<e.wake_at: continue
		var audible_radius = radius*(1.0 if room.visible_line(e.pos,location) else 0.62)
		if e.pos.distance_to(location)>audible_radius: continue
		if e.state!="chase" or e.blind or invis_time>0:
			e.target = location
			e.state = "investigate"
			e.path_cd = 0.0
		e.memory = maxf(e.memory,5.5)

func rally_neighbours(source: Dictionary) -> void:
	# A local, throttled alert; newly alerted units cannot rebroadcast without sight.
	for e in enemies:
		if e.dead or e.mother or e.id==source.id or e.state=="chase" or time<e.wake_at: continue
		if e.pos.distance_to(source.pos)<encounter.rally_radius and room.visible_line(e.pos,source.pos):
			e.target = source.target
			e.state = "investigate"
			e.memory = maxf(e.memory,4.5)

func movement_direction(e: Dictionary, goal: Vector3, dt: float) -> Vector3:
	e.path_cd -= dt
	var desired = goal - e.pos
	if desired.length() < 0.22: return Vector3.ZERO
	if room.walkable_line(e.pos, goal): return desired.normalized()
	if e.path_cd <= 0:
		e.path = room.path_to(e.pos, goal)
		e.path_cd = 0.9 + float(e.id % 7) * 0.08
	while not e.path.is_empty() and e.pos.distance_to(e.path[0]) < 0.4:
		e.path.remove_at(0)
	if e.path.is_empty(): return Vector3.ZERO
	return (e.path[0] - e.pos).normalized()

func request_control(e: Dictionary, kind: String, duration: float) -> bool:
	if e.dead or e.cc_guard > 0 or e.pin > 0 or e.freeze > 0 or e.flip > 0: return false
	var resistance = minf(0.78, e.control_resist + e.control_fatigue * 0.22 + (0.28 if e.mother else 0.0))
	e[kind] = maxf(0.32, duration * (1.0 - resistance))
	e.control_fatigue = minf(2.0, e.control_fatigue + 0.65)
	e.attack_state = "ready"
	e.flight = 0.0
	return true

func update_enemies(dt: float) -> void :
	var rushing = 0
	for unit in enemies:
		if not unit.dead and unit.attack_state in ["windup", "dash"]: rushing += 1
	for e in enemies:
		if e.dead: continue
		if not e.mother and time < e.wake_at:
			Anatomy.animate(e, "idle", dt)
			continue
		var controlled_before = e.freeze > 0 or e.pin > 0 or e.flip > 0
		var pinned_before = e.pin > 0
		for key in ["flash", "freeze", "burn", "pin", "flip", "chain_t", "cc_guard", "pin_guard", "alert_cd", "hit_noise_cd", "dash_cd", "rend_window", "rend_time", "resonance_cd"]:
			e[key] = maxf(0, e[key] - dt * (7.0 if key == "flash" else 1.0))
		if e.rend_window <= 0: e.rend_hits = 0
		e.chill = maxf(0, e.chill - dt * 0.28)
		e.control_fatigue = maxf(0, e.control_fatigue - dt * 0.08)
		var controlled = e.freeze > 0 or e.pin > 0 or e.flip > 0
		if controlled_before and not controlled:
			e.cc_guard = maxf(e.cc_guard, 1.6 + e.control_resist * 2.0)
			if pinned_before: e.pin_guard = 2.5 + e.control_resist * 3.0
		if e.chain_t <= 0: e.hit_chain = 0
		e.mat.set_shader_parameter("hit", e.flash)
		e.mat.set_shader_parameter("frost", minf(1, e.chill * 0.25 + minf(e.freeze, 1)))
		e.mat.set_shader_parameter("burn", minf(e.burn, 1))
		e.mat.set_shader_parameter("gait", 0.0)
		if e.pin <= 0 and is_instance_valid(e.pin_fx):
			e.pin_fx.queue_free()
			e.pin_fx = null
		if e.burn > 0:
			e.dot += dt
			if e.dot >= 0.45:
				e.dot = 0
				hit_enemy(e, (2.0 + 1.7 * r("fire")) * (1 + 0.22 * r("damage")), "dot", e.pos + Vector3(0, 1, 0), 0, false)
				burst(e.pos + Vector3(0, 0.4, 0), Color("ff8739"), 3, 0.8)
				if e.dead: continue
		var distance = player_pos.distance_to(e.pos)
		if e.mother:
			Anatomy.animate(e, "idle", dt)
			if distance < 8 and room.visible_line(e.pos, player_pos) and not e.alerted:
				e.alerted = true
				emit("toast", {"text": "发现虫母！切断增援源头"})
				emit("sound", {"kind": "mother"})
			if distance < 1.0 and invulnerable <= 0 and not controlled: damage_player(e)
			continue
		if e.vel.length() > 0.12:
			var before = e.pos
			e.pos = room.move_safe(e.pos, e.vel * dt, 0.25)
			if r("collision") > 0 and e.vel.length() > 2:
				for other in enemies:
					if other.dead or other.id == e.id: continue
					if e.pos.distance_to(other.pos) < 0.75:
						other.vel += e.vel * 0.5
						hit_enemy(other, 7.0 * r("collision"), "collision", before, 1, false)
						e.vel *= 0.5
						break
			e.vel = e.vel.move_toward(Vector3.ZERO, dt * 13)
		if controlled:
			if e.freeze <= 0: Anatomy.animate(e, "stagger", dt * 0.5, dt)
			e.node.rotation.z = lerp_angle(e.node.rotation.z, PI if e.flip > 0 else 0.0, minf(1, dt * 12))
			e.node.position = e.pos + Vector3(0, 0.33 if e.flip > 0 else 0, 0)
			continue
		e.node.rotation.z = lerp_angle(e.node.rotation.z, 0.0, minf(1, dt * 9))
		var can_see = not e.blind and invis_time <= 0 and distance < encounter.sight and room.visible_line(e.pos, player_pos)
		if can_see:
			e.memory = 7.5
			e.target = player_pos
			e.state = "chase"
			if e.alert_cd <= 0:
				rally_neighbours(e)
				e.alert_cd = 1.8
		else:
			e.memory = maxf(0, e.memory - dt)
			if e.state == "chase": e.state = "search"
			if e.memory <= 0:
				e.state = "wander"
				e.wander -= dt
				if e.wander <= 0 or e.pos.distance_to(e.target) < 0.4:
					e.wander = rng.randf_range(1.5, 4)
					e.target = e.pos + Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4))
		var goal: Vector3 = e.target

		if can_see and distance > 2.3 and e.id % 3 != 0:
			var radial = (e.pos - player_pos).normalized()
			var flank = Vector3( - radial.z, 0, radial.x) * (1.3 if e.id % 2 == 0 else -1.3)
			var candidate = player_pos + flank + player_velocity * 0.22
			if room.clear_at(candidate, 0.4): goal = candidate
		var dir = movement_direction(e, goal, dt)
		var speed = float(encounter.chase_speed) if e.state in ["chase", "search", "investigate"] else 0.65
		speed *= Balance.leg_mobility(e.lost_legs)
		speed *= maxf(0.55, 1.0 - e.chill * 0.12)
		if e.blind: speed *= 0.85
		if e.attack_state == "ready" and can_see and time > encounter.dash_grace and e.dash_cd <= 0 and distance > 2.0 and distance < 6.3 and e.lost_legs < 4 and rushing < encounter.dash_slots:
			e.attack_state = "windup"
			e.attack_timer = encounter.dash_windup
			e.dash_dir = (player_pos + player_velocity * 0.18 - e.pos).normalized()
			e.dash_flying = e.wings == 2 and e.id % 4 == 0
			rushing += 1
			shockwave(e.pos, 0.85, Color("eea44c"))
			emit("sound", {"kind": "rush", "pan": clampf((e.pos.x - player_pos.x) / 7.0, - 0.85, 0.85)})
		if e.attack_state == "windup":
			speed = 0.0
			dir = e.dash_dir
			e.attack_timer -= dt
			if e.attack_timer <= 0:
				e.attack_state = "dash"
				e.attack_timer = 0.46
		elif e.attack_state == "dash":
			dir = e.dash_dir
			speed = float(encounter.dash_speed) * Balance.leg_mobility(e.lost_legs)
			e.attack_timer -= dt
			e.flight = maxf(0, e.attack_timer) if e.dash_flying and e.wings == 2 else 0.0
			if e.attack_timer <= 0:
				e.attack_state = "recover"
				e.attack_timer = 0.65
				e.flight = 0.0
				e.dash_cd = rng.randf_range(5.5, 8.5)
		elif e.attack_state == "recover":
			speed *= 0.35
			e.attack_timer -= dt
			if e.attack_timer <= 0: e.attack_state = "ready"
		var separation = Vector3.ZERO
		if e.attack_state not in ["windup", "dash"]:
			for other in enemies:
				if other.dead or other.id == e.id: continue
				var offset: Vector3 = e.pos - other.pos
				var gap = offset.length()
				if gap > 0.01 and gap < 0.85: separation += offset / gap * (0.85 - gap) * 1.7
		var old_pos: Vector3 = e.pos
		e.pos = room.move_safe(e.pos, (dir * speed + separation.limit_length(1.2)) * dt, 0.26)
		if e.attack_state == "dash" and e.pos.distance_to(old_pos) < speed * dt * 0.35:
			e.attack_state = "recover"
			e.attack_timer = 0.65
			e.dash_cd = rng.randf_range(5.5, 8.5)
			e.flight = 0.0
		var flying_height = sin(clampf(e.flight / 0.46, 0, 1) * PI) * 0.58
		e.node.position = e.pos + Vector3(0, flying_height, 0)
		if dir.length() > 0.1: e.node.rotation.y = lerp_angle(e.node.rotation.y, atan2( - dir.x, - dir.z), minf(1, dt * 12))
		var actual_speed = e.pos.distance_to(old_pos) / maxf(dt, 0.001)
		var clip = "flight" if e.flight > 0 else ("run" if actual_speed > 1.25 else ("walk" if actual_speed > 0.1 else "idle"))
		var anim_step = dt if clip in ["flight", "idle"] else dt * actual_speed / (0.76 if clip == "run" else 0.52)
		Anatomy.animate(e, clip, anim_step, dt)

		var contact = Geometry2D.get_closest_point_to_segment(Vector2(player_pos.x, player_pos.z), Vector2(old_pos.x, old_pos.z), Vector2(e.pos.x, e.pos.z))
		if contact.distance_to(Vector2(player_pos.x, player_pos.z)) < 0.65 and invulnerable <= 0:
			damage_player(e)
			if phase == "dead": return

func damage_player(e: Dictionary) -> void :
	life -= 1
	invulnerable = 2.0
	shake = 0.7
	e.vel = (e.pos - player_pos).normalized() * 6
	emit("hurt", {"life": life})
	emit("sound", {"kind": "hurt"})
	if life <= 0:
		phase = "dead"
		player.visible = false
		move_input = Vector2.ZERO
		emit("sound", {"kind": "death"})
		push_state()

func attack(target: Dictionary) -> void:
	weapon_recoil = 1.0
	if noise_clock<=0:
		combat_noise(player_pos,Balance.noise_radius(weapon))
		noise_clock = 0.65
	var range_value = weapon_range()
	var damage = float(WEAPONS[weapon].damage)*(1.0+0.22*r("damage"))
	var empowered = false
	if weapon=="slipper" and r("thicksole")>0:
		slipper_swings += 1
		empowered = slipper_swings%3==0
		if empowered:
			damage *= 1.35+0.15*r("thicksole")
			weapon_recoil = 1.6
			shake = maxf(shake,0.36)
			hitstop = maxf(hitstop,0.045)
			emit("crit",{})
			emit("sound",{"kind":"crit"})
	var dir = (target.pos-player_pos).normalized()
	var origin = player_pos+Vector3(0,0.6,0)
	match weapon:
		"wand","staple","slingshot":
			var count = 1+r("multi")
			for i in range(count):
				var angle = (i-(count-1)*0.5)*0.19
				var shot_dir = dir.rotated(Vector3.UP,angle)
				spawn_shot(origin,shot_dir,target,damage*(1 if i==0 else 0.73),weapon,0)
			emit("sound",{"kind":"shot" if weapon=="wand" else weapon})
		_:
			var spread = 0.74+minf(r("multi")*0.25,1.6)
			var crit_any = false
			for e in enemies.duplicate():
				if e.dead: continue
				var distance = e.pos.distance_to(player_pos)
				var edir = (e.pos-player_pos).normalized()
				if distance>range_value or edir.dot(dir)<cos(spread): continue
				if r("wall")==0 and not room.visible_line(player_pos,e.pos): continue
				var dmg = damage
				if weapon=="spray": dmg *= lerpf(1.45,0.25,clampf(distance/range_value,0,1))
				if weapon=="chainsaw":
					e.hit_chain += 1
					e.chain_t = 0.6
					dmg *= 1.0+minf(e.hit_chain*0.035,0.55)
				hit_enemy(e,dmg,weapon,player_pos,0,true)
				if weapon=="slipper" and not e.dead:
					e.vel += edir*(4.5+0.8*r("collision"))*(1.35 if empowered else 1.0)*(1.0-e.control_resist)*(0.4 if e.cc_guard>0 else 1.0)
					if empowered: request_control(e,"flip",0.75)
				if weapon=="vacuum" and not e.dead: e.vel -= edir*0.70
				if weapon=="zapper": chain_lightning(e,damage*0.48,2+r("lightning"),1)
			if weapon=="spray":
				for i in range(4+mini(r("multi"),5)):
					var d = dir.rotated(Vector3.UP,rng.randf_range(-spread,spread))
					moving_particle(origin,d*rng.randf_range(3,6),Color("b9cf8f"),0.09,0.30)
			elif weapon=="chainsaw":
				burst(origin+dir*1.1,Color("ffd17b"),5,1.5)
				shake = maxf(shake,0.07)
			elif weapon=="vacuum":
				vacuum_counter += 1
				moving_particle(origin+dir*2,-dir*5,Color("b6c7ad"),0.10,0.35)
				if vacuum_counter%9==0:
					shockwave(player_pos,range_value,Color("c4dda5"))
					for e in enemies.duplicate():
						if not e.dead and e.pos.distance_to(player_pos)<range_value:
							e.vel += (e.pos-player_pos).normalized()*5
							hit_enemy(e,damage*3,"vacuum",player_pos,1,false)
			else:
				arc_effect(origin,dir,range_value,Color("edcb8b") if weapon=="slipper" else Color("83d8fa"))
			emit("sound",{"kind":weapon})

func spawn_shot(origin: Vector3,dir: Vector3,target: Dictionary,damage: float,kind: String,depth: int,prior: Array = []) -> void:
	if shots.size()>90: return
	var node = Node3D.new()
	add_child(node)
	node.position = origin
	var color = Color("97e5ec") if kind=="wand" else Color("eee0af")
	if r("fire")>0: color = Color("ffa85a")
	if r("ice")>0: color = Color("97dfff")
	var m = fx_mat(color)
	if kind=="staple":
		G.rod(node,Vector3(-0.13,0,0),Vector3(0.13,0,0),0.02,m)
		G.rod(node,Vector3(-0.13,0,0),Vector3(-0.13,0,-0.20),0.02,m)
		G.rod(node,Vector3(0.13,0,0),Vector3(0.13,0,-0.20),0.02,m)
	else:
		G.sphere(node,Vector3.ZERO,Vector3.ONE*(0.12 if kind=="wand" else 0.09),m,8)
	var speed = 8.0 if kind=="wand" else 12.0
	if kind!="wand" and not target.is_empty():
		dir.y = (target.node.position.y+0.28-origin.y)/maxf(0.4,Vector2(target.pos.x-origin.x,target.pos.z-origin.z).length())
		dir = dir.normalized()
	shots.append({"node":node,"pos":origin,"dir":dir,"target":target,"speed":speed,"damage":damage,"kind":kind,"time":0.0,"life":1.5+0.2*r("area"),"pierce":r("pierce"),"bounce":r("bounce"),"hit":prior.duplicate(),"depth":depth,"color":color,"trail":0.0,"travel":0.0,"max_distance":weapon_range(),"crossed_wall":false})

func update_shots(dt: float) -> void:
	for s in shots.duplicate():
		if not is_instance_valid(s.node): shots.erase(s);continue
		s.time += dt
		if s.kind=="wand" and not s.target.is_empty() and not s.target.dead:
			var desired = (s.target.node.position+Vector3(0,0.31,0)-s.pos).normalized()
			s.dir = s.dir.lerp(desired,minf(1,dt*8)).normalized()
		var old = s.pos
		var step_length = minf(s.speed*dt,maxf(0,s.max_distance-s.travel))
		s.pos += s.dir*step_length
		s.travel += step_length
		s.node.position = s.pos
		s.node.rotation.y = atan2(-s.dir.x,-s.dir.z)
		s.trail += dt
		if s.trail>0.06:
			s.trail = 0
			moving_particle(s.pos,Vector3.ZERO,s.color,0.045,0.16)
		if not room.clear_at(s.pos,0.01) or not room.visible_line(old,s.pos): s.crossed_wall = true
		var erase = s.time>s.life or s.travel>=s.max_distance or (r("wall")==0 and (not room.clear_at(s.pos,0.01) or not room.visible_line(old,s.pos)))
		if erase:
			s.node.queue_free()
			shots.erase(s)
			continue
		for e in enemies.duplicate():
			if e.dead or e.id in s.hit: continue
			var p = Vector2(e.pos.x,e.pos.z)
			var a = Vector2(old.x,old.z)
			var b = Vector2(s.pos.x,s.pos.z)
			var closest = Geometry2D.get_closest_point_to_segment(p,a,b)
			if closest.distance_to(p)<(1.65 if e.mother else 0.95):
				var contact = ray_part(e,old,s.pos)
				if contact.is_empty(): continue
				s.hit.append(e.id)
				hit_enemy(e,s.damage,s.kind,old,s.depth,true,contact.part,s.crossed_wall)
				if s.kind=="staple" and not e.dead:
					pin_enemy(e)
				if s.kind=="wand" and r("seek")>0 and s.depth==0:
					var t = nearest(e.pos,4.0,s.hit)
					if not t.is_empty(): spawn_shot(e.pos+Vector3(0,0.4,0),(t.pos-e.pos).normalized(),t,s.damage*(0.40+0.12*(r("seek")-1)),"wand",1,s.hit)
				if s.bounce>0:
					var t = nearest(e.pos,4.0+0.5*r("area"),s.hit)
					if not t.is_empty():
						s.target = t
						s.dir = (t.pos+Vector3(0,0.3,0)-s.pos).normalized()
						s.bounce -= 1
						s.life += 0.5
						s.max_distance += 3.0
						break
				if s.pierce>0:
					s.pierce -= 1
				else: erase = true
				break
		if erase:
			s.node.queue_free()
			shots.erase(s)

func select_part(e: Dictionary, kind: String, origin: Vector3) -> String:
	if kind in ["dot", "lightning", "shatter", "collision"]: return "body"
	var local: Vector3 = e.node.to_local(origin)
	var available: Array = []
	if kind == "chainsaw":
		var offset = 0 if local.x < 0 else 3
		for i in range(3):
			var k = "leg_" + str(i + offset)
			if e.durability[k] > 0: available.append(k)
		if available.size() > 0 and rng.randf() < 0.88: return available[rng.randi() % available.size()]
	if local.z < -0.16 and absf(local.x) < 1.0 and e.durability.eyes > 0:
		if rng.randf() < 0.62 + 0.08 * r("anatomy"): return "eyes"
	if kind in ["slipper", "spray", "vacuum"] or local.z > 0.1:
		var wing = "wing_l" if local.x < 0 else "wing_r"
		if e.durability[wing] > 0 and rng.randf() < 0.62: return wing
	if absf(local.x) > 0.23:
		var offset = 0 if local.x < 0 else 3
		for i in range(3):
			var k = "leg_" + str(i + offset)
			if e.durability[k] > 0: available.append(k)
		if not available.is_empty() and rng.randf() < 0.55: return available[rng.randi() % available.size()]
	return "body"

func hit_enemy(e: Dictionary,raw: float,kind: String,origin: Vector3,depth: int,allow_crit: bool,forced_part: String = "",crossed_wall: bool = false) -> void:
	if e.dead or raw<=0: return
	e.wake_at = 0.0
	var direct_hit = depth==0 and WEAPONS.has(kind)
	var base_raw = raw
	if direct_hit and r("wall")>0 and (crossed_wall or not room.visible_line(origin,e.pos)): raw *= 1.0+0.08*r("wall")
	if r("resonance")>0 and kind in ["lightning","zapper"] and (e.chill>0.05 or e.freeze>0) and e.resonance_cd<=0:
		e.resonance_cd = 0.4
		if e.freeze>0: e.chill = maxf(0,e.chill-0.6)
		raw *= 1.45+0.20*r("resonance")
		burst(e.pos+Vector3(0,0.4,0),Color("c4f4ff"),9,2.0)
		emit("sound",{"kind":"freeze"})
	var part = forced_part if not forced_part.is_empty() else select_part(e,kind,origin)
	var crit = allow_crit and rng.randf()<minf(0.70,0.035+0.08*r("crit")+(0.10 if kind=="slingshot" else 0.0))
	var multiplier = 1.65 if part=="eyes" else (0.72 if part.begins_with("wing") else (0.88 if part.begins_with("leg") else 1.0))
	var effective_armor = maxf(0,e.armor-(minf(0.24,0.07+0.03*r("rend")) if e.rend_time>0 else 0.0))
	var dmg = raw*multiplier*(2.0 if crit else 1.0)*(1.0-effective_armor)
	var frozen = e.freeze>0
	e.hp -= dmg
	e.flash = 1.0
	if kind!="dot" and e.hit_noise_cd<=0:
		combat_noise(e.pos,8.0 if crit else 6.5)
		e.hit_noise_cd = 0.7
	if e.mother: e.alerted = true
	if kind!="dot":
		emit("sound",{"kind":"hit","weapon":weapon,"element":kind,"pan":clampf((e.pos.x-player_pos.x)/7.0,-.85,.85)})
	xp += (0.22 if depth>0 or kind=="dot" else 0.85+minf(dmg,12)*0.10)
	if part!="body":
		var part_power = 1.0 if kind in ["chainsaw","slingshot"] else (0.40 if kind=="spray" else 0.72)
		e.durability[part] -= raw*part_power*(1.0+0.35*r("anatomy"))*(1.8 if crit else 1.0)
		if e.durability[part]<=0: break_part(e,part,origin,depth)
	var color = Color("ffd47e") if crit else Color("ddd4b5")
	burst(e.pos+Vector3(0,0.32,0),color,5 if crit else 2,1.7 if crit else 1.0)
	if kind!="dot" and (crit or rng.randf()<0.34): damage_label(e.pos+Vector3(0,0.8,0),str(int(dmg)),crit)
	if crit:
		shake = maxf(shake,0.48)
		hitstop = maxf(hitstop,0.035)
		emit("crit",{})
		emit("sound",{"kind":"crit"})
		if weapon=="slipper": request_control(e,"flip",1.4)
	if r("ice")>0 and direct_hit:
		e.chill = minf(3.5,e.chill+(0.32+0.12*r("ice"))*(1.0-e.control_resist))
		if e.chill>=2.6 and request_control(e,"freeze",1.1+0.25*r("ice")):
			emit("sound",{"kind":"freeze"})
			e.chill = 0.7
			burst(e.pos,Color("a1e4ff"),7,1.4)
	if r("fire")>0 and kind!="dot": e.burn = maxf(e.burn,2.5+0.8*r("fire"))
	if direct_hit and r("lightning")>0 and rng.randf()<0.25+minf(0.2,r("lightning")*0.04):
		chain_lightning(e,base_raw*0.5,1+r("lightning"),1)
	if depth==0 and frozen and r("shatter")>0 and (crit or kind in ["slipper","chainsaw","slingshot"]):
		e.freeze = 0
		e.cc_guard = maxf(e.cc_guard,1.6)
		area_damage(e.pos,2.2+0.3*r("area"),base_raw*0.65*r("shatter"),"shatter",e.id,1)
		shockwave(e.pos,2.0,Color("90d9ff"))
	if depth==0 and r("bounce")>0 and kind in ["slipper","chainsaw","spray","zapper","vacuum"] and rng.randf()<0.25:
		var other = nearest(e.pos,2.5+0.25*r("area"),[e.id])
		if not other.is_empty():
			lightning_line(e.pos+Vector3(0,0.3,0),other.pos+Vector3(0,0.3,0),Color("e6c592"))
			hit_enemy(other,base_raw*0.4*r("bounce"),"collision",e.pos,1,false)
	if direct_hit and r("rend")>0 and not e.dead and e.hp>0:
		e.rend_hits += 1
		e.rend_window = 2.0
		if e.rend_hits>=4:
			e.rend_hits = 0
			e.rend_time = 4.0
			shockwave(e.pos,0.9,Color("ffd392"))
			shake = maxf(shake,0.14)
			emit("sound",{"kind":"break"})
			# Secondary strike cannot increment its own counter or roll a critical.
			hit_enemy(e,base_raw*(0.45+0.18*r("rend")),"rupture",origin,1,false,"body")
	if e.hp<=0: kill_enemy(e,origin,kind)

func break_part(e: Dictionary, key: String, origin: Vector3, depth: int) -> void :
	var node: MeshInstance3D = e.parts[key]
	if not node.visible: return
	node.visible = false
	broken_parts += 1
	var piece = Node3D.new()
	var visual = MeshInstance3D.new()
	visual.mesh = Anatomy.posed_mesh(node, e.skeleton)
	var m = e.mat.duplicate()
	m.set_shader_parameter("gait", 0.0)
	m.set_shader_parameter("hit", 0.0)
	visual.material_override = m
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	piece.add_child(visual)
	var center = visual.mesh.get_aabb().get_center()
	visual.position = - center
	add_child(piece)
	piece.global_transform = node.global_transform * Transform3D(Basis.IDENTITY, center)
	var dir = (e.pos - origin).normalized()
	fragments.append({"node": piece, "mat": m, "vel": dir * rng.randf_range(1.0, 2.4) + Vector3(rng.randf_range(-1, 1), rng.randf_range(1.7, 3.0), rng.randf_range(-1, 1)), "spin": Vector3(rng.randf_range(-6, 6), rng.randf_range(-5, 5), rng.randf_range(-6, 6)), "life": 12.0, "settled": false})
	var caption = ""
	if key.begins_with("leg"):
		e.lost_legs += 1
		caption = "断足 · 减速"
	elif key.begins_with("wing"):
		e.wings -= 1
		if e.flight > 0: shockwave(e.pos, 0.9, Color("c6bd98"))
		e.flight = 0
		caption = "断翅 · 禁飞"
	elif key == "eyes":
		e.blind = true
		e.memory = 0
		e.target = e.pos
		caption = "失明 · 失去搜寻"
	burst(e.pos + Vector3(0, 0.3, 0), Color("d9b678"), 7, 2.0)
	if e.pos.distance_to(player_pos) < 9: emit("part", {"text": caption})
	emit("sound", {"kind": "break"})
	shake = maxf(shake, 0.15)
	if depth == 0 and r("shatter") > 0:
		area_damage(e.pos, 1.7 + 0.25 * r("area"), 8.0 * r("shatter"), "shatter", e.id, 1)
		shockwave(e.pos, 1.8, Color("acdaed"))
	if depth == 0 and weapon == "chainsaw" and r("sawdance") > 0:
		area_damage(e.pos, 2.2 + 0.3 * r("area"), 12.0 * r("sawdance"), "shatter", e.id, 1)
		shockwave(e.pos, 2.3, Color("eec584"))

func pin_enemy(e: Dictionary) -> void :
	if e.dead or e.pin > 0 or e.pin_guard > 0 or e.cc_guard > 0 or e.freeze > 0 or e.flip > 0: return
	e.pin = 4.0
	e.flight = 0
	e.attack_state = "ready"
	if not is_instance_valid(e.pin_fx):
		var pin = Node3D.new()
		add_child(pin)
		pin.position = e.pos
		var steel = G.mat(Color("b9c6cc"), 0.2, 0.8)
		G.rod(pin, Vector3(-0.4, 0, 0), Vector3(-0.4, 0.65, 0), 0.035, steel)
		G.rod(pin, Vector3(-0.4, 0.65, 0), Vector3(0.4, 0.65, 0), 0.035, steel)
		G.rod(pin, Vector3(0.4, 0.65, 0), Vector3(0.4, 0, 0), 0.035, steel)
		e.pin_fx = pin
	if r("conductor") > 0: chain_lightning(e, 10.0 * r("conductor"), 2 + r("lightning"), 1)

func chain_lightning(source: Dictionary, damage: float, jumps: int, depth: int) -> void :
	var current = source
	var visited = [source.id]
	for i in range(mini(jumps, 14)):
		var target = nearest(current.pos, 3.0 + 0.45 * r("area"), visited)
		if target.is_empty(): break
		lightning_line(current.pos + Vector3(0, 0.4, 0), target.pos + Vector3(0, 0.4, 0), Color("8cdeff"))
		visited.append(target.id)
		hit_enemy(target, damage, "lightning", current.pos, depth, false)
		current = target

func area_damage(pos: Vector3, radius: float, damage: float, kind: String, exclude: int, depth: int) -> void :
	for e in enemies.duplicate():
		if not e.dead and e.id != exclude and e.pos.distance_to(pos) < radius:
			hit_enemy(e, damage, kind, pos, depth, false)

func kill_enemy(e: Dictionary, origin: Vector3, kind: String = "impact") -> void :
	if e.dead: return
	e.dead = true
	Anatomy.animate(e, "death", 0.0)
	e.attack_state = "dead"
	e.vel = Vector3.ZERO
	kills += 1
	total_kills += 1
	if is_instance_valid(e.pin_fx): e.pin_fx.queue_free()
	e.mat.set_shader_parameter("gait", 0.0)
	e.mat.set_shader_parameter("hit", 0.0)
	e.mat.set_shader_parameter("frost", 0.0)
	e.mat.set_shader_parameter("death", 1.0)
	var roll = (PI if kind in ["spray", "dot", "lightning", "zapper"] else rng.randf_range(1.2, 2.6)) * (1 if e.id % 2 == 0 else -1)
	var direction = e.pos - origin
	direction.y = 0
	fx_nodes.append({"node": e.node, "mat": e.mat, "enemy": e, "start_rotation": e.node.rotation, "roll": roll, "origin": e.pos, "drift": direction.normalized() * 0.38, "time": 8.0, "max": 8.0, "type": "corpse"})
	death_splatter(e.pos, direction.normalized(), 1.6 if e.mother else (1.2 if kind in ["chainsaw", "slipper", "shatter"] else 0.75))
	emit("sound", {"kind": "splat", "pan": clampf((e.pos.x - player_pos.x) / 7.0, - 0.85, 0.85)})
	if e.mother:
		shake = 0.8
		xp += 35
		emit("toast", {"text": "虫母已消灭 · 清理剩余蟑螂"})
		emit("sound", {"kind": "mother"})
		shockwave(e.pos, 4, Color("d9b477"))
	if r("spread") > 0 and e.burn > 0:
		for other in enemies:
			if not other.dead and other.pos.distance_to(e.pos) < 3.0 + 0.4 * r("spread"):
				other.burn = maxf(other.burn, 3.0 + 0.7 * r("fire"))
				lightning_line(e.pos + Vector3(0, 0.3, 0), other.pos + Vector3(0, 0.3, 0), Color("ff8c46"))

func level_up() -> void:
	xp -= xp_need
	level += 1
	xp_need = 22.0+pow(level-1,1.12)*7.5
	phase = "upgrade"
	move_input = Vector2.ZERO
	cards = []
	var keys = RUNES.keys()
	keys.shuffle()
	for key in keys:
		if not rune_available(key): continue
		var card = RUNES[key].duplicate()
		card.id = key
		card.type = "rune"
		card.stack = r(key)+1
		cards.append(card)
		if cards.size()==3: break
	# Every other level offers a new weapon, while always keeping two rune choices.
	if level%2==0:
		var weapons = reward_weapons()
		var id = weapons[rng.randi()%weapons.size()]
		if not id in weapons_seen: weapons_seen.append(id)
		var card = WEAPONS[id].duplicate()
		card.id = id
		card.type = "weapon"
		card.stack = 0
		cards[2] = card
	emit("sound",{"kind":"level"})
	push_state()

func choose_reward(index: int) -> void :
	if index < 0 or index >= cards.size(): return
	var card = cards[index]
	if card.type == "weapon": set_weapon(card.id)
	else: runes[card.id] = r(card.id) + 1
	phase = "playing"
	invulnerable = maxf(invulnerable, 0.65)
	attack_clock = 0.05
	var combos = get_combos()
	for name in combos:
		if not name in active_combos: emit("combo", {"text": name})
	active_combos = combos
	cards = []
	emit("toast", {"text": card.name + (" · 第 " + str(card.stack) + " 层" if card.type == "rune" else " · 已替换旧武器")})
	push_state()

func get_combos() -> Array:
	var out = []
	if r("ice")>0 and r("shatter")>0: out.append("碎冰连爆")
	if r("fire")>0 and r("spread")>0: out.append("燎原")
	if r("multi")>0 and r("bounce")>0: out.append("交叉弹幕")
	if r("pierce")>0 and r("wall")>0: out.append("无阻穿透")
	if weapon=="staple" and (r("conductor")>0 or r("lightning")>0): out.append("钉阵电网")
	if weapon=="chainsaw" and r("sawdance")>0: out.append("断肢震荡")
	if weapon=="chainsaw" and r("ice")>0: out.append("寒霜锯刃")
	if weapon=="slipper" and r("collision")>0: out.append("虫群保龄球")
	if weapon=="wand" and r("seek")>0: out.append("追踪星群")
	if r("anatomy")>0 and r("shatter")>0: out.append("拆解连锁")
	if weapon=="slipper" and r("thicksole")>0 and r("collision")>0: out.append("全垒打")
	if r("rend")>0 and ((r("multi")>0 and weapon in ["wand","staple","slingshot"]) or (r("rate")>0 and weapon in ["spray","chainsaw","vacuum"])): out.append("集火破壳")
	if r("resonance")>0 and rune_available("resonance"): out.append("冰牢雷刑")
	return out

func living_count() -> int:
	var count = 0
	for e in enemies:
		if not e.dead: count += 1
	return count

func emit(kind: String, data: Dictionary) -> void :
	if not ui_ready: return
	JavaScriptBridge.eval("window.gameEvent(" + JSON.stringify({"kind": kind, "data": data}) + ");")

func push_state() -> void:
	if not ui_ready: return
	var list = []
	for key in runes:
		list.append({"id":key,"name":RUNES[key].name,"n":r(key),"active":rune_available(key)})
	var mother_dead = mother.get("dead",true)
	var objective = "寻找藏匿的虫母"
	if mother_dead: objective = "虫母已死 · 清理剩余蟑螂"
	elif mother.get("alerted",false): objective = "虫母就在附近 · 消灭增援源头"
	var compass_angle = 0.0
	var compass_on = false
	var compass_text = "异响"
	var cue = {}
	if mother_dead:
		var closest_remaining = INF
		for enemy in enemies:
			if not enemy.dead and player_pos.distance_to(enemy.pos)<closest_remaining:
				closest_remaining = player_pos.distance_to(enemy.pos)
				cue = enemy
	elif time>50: cue = mother
	if not cue.is_empty():
		var d = cue.pos-player_pos
		compass_angle = rad_to_deg(atan2(d.x,-d.z))
		compass_on = d.length()>7
		compass_text = "残余" if mother_dead else "窸窣声"
	var state = {"phase":phase,"room":room_number,"campaign_rooms":Balance.CAMPAIGN_ROOMS,"campaign_complete":phase=="win" and room_number>=Balance.CAMPAIGN_ROOMS,"life":life,"level":level,"xp":xp,"need":xp_need,"time":time,"kills":kills,"total":total_kills,"parts":broken_parts,"alive":living_count(),"mother_dead":mother_dead,"objective":objective,"weapon":weapon,"weapon_name":WEAPONS[weapon].name,"weapon_icon":WEAPONS[weapon].icon,"runes":list,"combos":get_combos(),"cards":cards,"compass":compass_on,"angle":compass_angle,"cue":compass_text,"invisible":invis_time>0}
	JavaScriptBridge.eval("window.receiveGameState("+JSON.stringify(state)+");")

func fx_mat(color: Color) -> StandardMaterial3D:
	var key = color.to_html()
	if fx_materials.has(key): return fx_materials[key]
	var m = G.mat(color, 0.4)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = color
	m.no_depth_test = false
	fx_materials[key] = m
	return m

func moving_particle(pos: Vector3, vel: Vector3, color: Color, size: float, life_time: float) -> void :
	if particles.size() > 150: return
	var node = G.sphere(self, pos, Vector3.ONE * size, fx_mat(color), 6)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.append({"node": node, "vel": vel, "life": life_time, "max": life_time, "size": size})

func burst(pos: Vector3, color: Color, count: int, speed: float) -> void :
	for i in range(count):
		var vel = Vector3(rng.randf_range(-1, 1), rng.randf_range(0.1, 1.0), rng.randf_range(-1, 1)).normalized() * speed
		moving_particle(pos, vel, color, rng.randf_range(0.035, 0.065), rng.randf_range(0.15, 0.36))

func shockwave(pos: Vector3, radius: float, color: Color) -> void :
	var node = G.ring(self, pos + Vector3(0, 0.07, 0), radius, 0.055, fx_mat(color))
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.scale = Vector3.ONE * 0.15
	fx_nodes.append({"node": node, "time": 0.34, "max": 0.34, "type": "ring"})

func arc_effect(pos: Vector3, dir: Vector3, radius: float, color: Color) -> void :
	var root = Node3D.new()
	add_child(root)
	for i in range(10):
		var a = dir.rotated(Vector3.UP, -0.72 + i * 0.144) * radius
		var b = dir.rotated(Vector3.UP, -0.72 + (i + 1) * 0.144) * radius
		var line = G.rod(root, pos + a, pos + b, 0.035, fx_mat(color))
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx_nodes.append({"node": root, "time": 0.15, "max": 0.15, "type": "line"})

func lightning_line(a: Vector3, b: Vector3, color: Color) -> void :
	var root = Node3D.new()
	add_child(root)
	var last = a
	for i in range(1, 7):
		var next = a.lerp(b, i / 6.0)
		if i < 6: next += Vector3(rng.randf_range(-0.16, 0.16), rng.randf_range(-0.1, 0.2), rng.randf_range(-0.16, 0.16))
		var line = G.rod(root, last, next, 0.018, fx_mat(color))
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		last = next
	fx_nodes.append({"node": root, "time": 0.19, "max": 0.19, "type": "line"})

func damage_label(pos: Vector3, text_value: String, crit: bool) -> void :
	if labels.size() > 15: return
	var node = Label3D.new()
	node.text = text_value + "!" if crit else text_value
	node.position = pos
	node.font_size = 40 if crit else 30
	node.pixel_size = 0.009
	node.modulate = Color("ffce74") if crit else Color("ede0c3")
	node.outline_modulate = Color(0.08, 0.09, 0.04, 0.9)
	node.outline_size = 7
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node.no_depth_test = true
	add_child(node)
	labels.append({"node": node, "life": 0.65, "crit": crit})

func death_splatter(pos: Vector3, direction: Vector3, force: float) -> void :


	var wet_count = 0
	for effect in fx_nodes:
		if effect.type in ["splat", "droplet"]: wet_count += 1
	var budget = maxi(0, 140 - wet_count)
	var pool = Node3D.new()
	add_child(pool)
	pool.position = pos + Vector3(0, 0.022, 0)
	pool.rotation.y = rng.randf_range(0, TAU)
	var wet = G.mat(Color(0.43, 0.34, 0.12, 0.78), 0.2)
	wet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in range(mini(5, budget)):
		var offset = Vector3(rng.randf_range(-0.35, 0.35), 0, rng.randf_range(-0.35, 0.35)) * force
		var lobe = G.sphere(pool, offset, Vector3(rng.randf_range(0.35, 0.7), 0.018, rng.randf_range(0.25, 0.6)) * force, wet, 10)
		lobe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx_nodes.append({"node": pool, "mat": wet, "time": 11.0, "max": 11.0, "type": "splat"})
	for i in range(mini(int(8 * force), maxi(0, budget - 5))):
		var material = G.mat(Color(0.68, 0.6, 0.33, 0.85) if i % 3 else Color(0.79, 0.72, 0.47, 0.85), 0.16)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var drop = G.sphere(self, pos + Vector3(0, 0.28, 0), Vector3.ONE * rng.randf_range(0.045, 0.09) * force, material, 8)
		drop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var velocity = direction * rng.randf_range(0.5, 2.0) + Vector3(rng.randf_range(-1.8, 1.8), rng.randf_range(1.0, 2.7), rng.randf_range(-1.8, 1.8))
		fx_nodes.append({"node": drop, "mat": material, "vel": velocity * force, "time": 1.4, "max": 1.4, "type": "droplet"})

func update_effects(dt: float) -> void :
	for p in particles.duplicate():
		p.life -= dt
		p.vel.y -= dt * 1.8
		p.node.position += p.vel * dt
		p.node.scale = Vector3.ONE * maxf(0.05, p.life / p.max)
		if p.life <= 0:
			p.node.queue_free()
			particles.erase(p)
	for f in fx_nodes.duplicate():
		f.time -= dt
		if f.type == "ring":
			f.node.scale = Vector3.ONE * (1 - f.time / f.max)
		elif f.type == "corpse":
			var age: float = f.max - f.time
			var fall = smoothstep(0.0, 0.48, age)
			f.node.rotation.z = lerp_angle(f.start_rotation.z, f.roll, fall)
			f.node.position = f.origin + f.drift * fall + Vector3(0, 0.35 * fall + sin(fall * PI) * 0.18, 0)
			Anatomy.animate(f.enemy, "death", dt)
			f.mat.set_shader_parameter("dissolve", smoothstep(0.0, 1.0, clampf((age - 4.0) / 4.0, 0, 1)))
		elif f.type == "splat":
			f.node.scale = Vector3.ONE * lerpf(0.3, 1.0, minf(1, (f.max - f.time) * 4.0))
			f.mat.albedo_color.a = 0.78 * minf(1, f.time / 4.0)
		elif f.type == "droplet":
			f.vel.y -= dt * 9.8
			f.node.position += f.vel * dt
			if f.node.position.y < 0.035:
				f.node.position.y = 0.035
				f.vel = Vector3.ZERO
				f.node.scale.y = 0.15
			f.mat.albedo_color.a = minf(0.85, f.time * 1.8)
		if f.time <= 0:
			if is_instance_valid(f.node): f.node.queue_free()
			fx_nodes.erase(f)
	for i in range(maxi(0, fragments.size() - 80)):
		fragments[i].life = minf(fragments[i].life, 1.5)
	for d in fragments.duplicate():
		d.life -= dt
		if not d.settled:
			d.vel.y -= 7.8 * dt
			d.node.position += d.vel * dt
			d.node.rotation += d.spin * dt
			if d.node.position.y < 0.05:
				d.node.position.y = 0.05
				if absf(d.vel.y) > 0.8:
					d.vel.y = absf(d.vel.y) * 0.27
					d.vel.x *= 0.55
					d.vel.z *= 0.55
					d.spin *= 0.4
				else:
					d.settled = true
		if d.life < 3.0: d.mat.set_shader_parameter("dissolve", 1.0 - maxf(0, d.life) / 3.0)
		if d.life <= 0:
			d.node.queue_free()
			fragments.erase(d)
	for label in labels.duplicate():
		label.life -= dt
		label.node.position.y += dt * 1.1
		label.node.modulate.a = minf(1, label.life * 3)
		if label.life <= 0:
			label.node.queue_free()
			labels.erase(label)


func ray_part(e: Dictionary, a_world: Vector3, b_world: Vector3) -> Dictionary:
	var a: Vector3 = e.node.to_local(a_world)
	var b: Vector3 = e.node.to_local(b_world)
	var shapes = [{"part": "body", "center": Vector3(0, 0.18, 0.18), "radius": Vector3(0.26, 0.095, 0.62)}, {"part": "body", "center": Vector3(0, 0.29, - 0.42), "radius": Vector3(0.28, 0.075, 0.175)}]
	if e.parts.eyes.visible:
		for side in [-1, 1]: shapes.append({"part": "eyes", "center": Vector3(side * 0.089, 0.182, - 0.606), "radius": Vector3(0.036, 0.044, 0.06)})
	for side in [-1, 1]:
		var key = "wing_l" if side == -1 else "wing_r"
		shapes.append_array(Anatomy.wing_hit_shapes(e, side))
		for j in range(3):
			key = "leg_" + str(j + (0 if side == -1 else 3))
			if not e.parts[key].visible: continue
			var skeleton: Skeleton3D = e.skeleton
			for joint in ["femur", "tibia", "tarsus"]:
				var bone = skeleton.find_bone(key + "_" + joint)
				var pose = skeleton.get_bone_global_pose(bone)
				var length = 0.14
				if joint != "tarsus":
					var next = skeleton.find_bone(key + ("_tibia" if joint == "femur" else "_tarsus"))
					length = pose.origin.distance_to(skeleton.get_bone_global_pose(next).origin)
				var transform = e.node.global_transform.affine_inverse() * skeleton.global_transform * pose
				var radius = 0.045 if joint == "femur" else 0.022
				shapes.append({"part": key, "center": transform * Vector3(0, length * 0.5, 0), "radius": Vector3(radius, length * 0.5 + 0.015, radius), "basis": transform.basis})
	var best = {}
	var best_t = 2.0
	for shape in shapes:
		var radius: Vector3 = shape.radius + Vector3.ONE * 0.035
		var inverse: Basis = shape.get("basis", Basis.IDENTITY).inverse()
		var start: Vector3 = (inverse * (a - shape.center)) / radius
		var direction: Vector3 = (inverse * (b - a)) / radius
		var aa = direction.dot(direction)
		if aa < 1e-05: continue
		var bb = 2.0 * start.dot(direction)
		var cc = start.dot(start) - 1.0
		var disc = bb * bb - 4.0 * aa * cc
		if disc < 0: continue
		var exit_t = ( - bb + sqrt(disc)) / (2.0 * aa)
		if exit_t < 0.0: continue
		var hit_t = maxf(0, ( - bb - sqrt(disc)) / (2.0 * aa))
		if hit_t <= 1.0 and hit_t < best_t:
			best_t = hit_t
			best = {"part": shape.part, "t": hit_t}
	return best

func rune_available(key: String) -> bool:
	if RUNES[key].has("weapon") and RUNES[key].weapon!=weapon: return false
	if key=="resonance":
		return r("ice")>0 and (r("lightning")>0 or weapon=="zapper" or (weapon=="staple" and r("conductor")>0))
	if key=="spread": return r("fire")>0
	return true


func reward_weapons() -> Array:
	var pool: Array = ["slipper","wand","spray","staple"]
	if level>=4: pool.append_array(["chainsaw","zapper"])
	if level>=6: pool.append_array(["slingshot","vacuum"])
	pool.erase(weapon)
	var unseen: Array = []
	for key in pool:
		if not key in weapons_seen: unseen.append(key)
	return unseen if not unseen.is_empty() else pool
