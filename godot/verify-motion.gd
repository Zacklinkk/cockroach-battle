extends SceneTree

var checks = 0
var failures: Array = []
var main
var anatomy
var output = ""

func _initialize() -> void:
	if not OS.get_cmdline_user_args().is_empty(): output = OS.get_cmdline_user_args()[0]
	call_deferred("verify")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)

func tick(e: Dictionary, state: String, frames: int, clip: String = "idle") -> void:
	e.attack_state = state
	for frame in range(frames): anatomy.animate(e, clip, 1.0 / 60.0, 1.0 / 60.0)

func bone(e: Dictionary, name: String) -> Transform3D:
	return e.skeleton.get_bone_global_pose(e.skeleton.find_bone(name))

func width(e: Dictionary) -> float:
	var minimum = INF
	var maximum = -INF
	for side in ["l", "r"]:
		var mesh = anatomy.posed_mesh(e.parts["wing_" + side], e.skeleton)
		for surface in range(mesh.get_surface_count()):
			for v in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				minimum = minf(minimum, v.x)
				maximum = maxf(maximum, v.x)
	return maximum - minimum

func snapshot(e: Dictionary, label: String) -> void:
	if output.is_empty(): return
	DirAccess.make_dir_recursive_absolute(output)
	var texture_path = output.path_join("cuticle.png")
	if not FileAccess.file_exists(texture_path):
		var texture: Texture2D = e.mat.get_shader_parameter("cuticle")
		var image = texture.get_image()
		if image.is_compressed(): image.decompress()
		image.save_png(texture_path)
	var data = {"meshes": [], "label": label}
	for part in e.parts.values():
		if not part.visible: continue
		var mesh = anatomy.posed_mesh(part, e.skeleton)
		for surface in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(surface)
			var entry = {"vertices": [], "normals": [], "uv": [], "indices": Array(arrays[Mesh.ARRAY_INDEX]), "texture": texture_path}
			var local: Transform3D = e.node.global_transform.affine_inverse() * part.global_transform
			for v in arrays[Mesh.ARRAY_VERTEX]:
				var p: Vector3 = local * v
				entry.vertices.append([p.x, p.y, p.z])
			for n in arrays[Mesh.ARRAY_NORMAL]:
				var normal: Vector3 = local.basis * n
				entry.normals.append([normal.x, normal.y, normal.z])
			for uv in arrays[Mesh.ARRAY_TEX_UV]: entry.uv.append([uv.x, uv.y])
			data.meshes.append(entry)
	var file = FileAccess.open(output.path_join(label + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(data))

func verify() -> void:
	anatomy = load("res://anatomy.gd")
	main = load("res://main.gd").new()
	root.add_child(main)
	await process_frame
	main.set_process(false)
	var e: Dictionary = main.spawn_enemy(Vector3.ZERO, false)
	e.node.rotation = Vector3.ZERO
	e.gait_phase = 0.7
	check(e.motion.bones.size() == 10, "Both three-joint feelers and both fore/hindwing pairs are bound")
	tick(e, "ready", 1)
	var first: Transform3D = bone(e, "antenna_l2")
	var first_body = anatomy.posed_mesh(e.parts.body, e.skeleton).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	snapshot(e, "01-idle-a")
	tick(e, "ready", 30)
	var second: Transform3D = bone(e, "antenna_l2")
	check(first.origin.distance_to(second.origin) > 0.07, "Idle feeler tip visibly sweeps through space")
	var second_body = anatomy.posed_mesh(e.parts.body, e.skeleton).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var displacement = 0.0
	for i in range(first_body.size()): displacement = maxf(displacement, first_body[i].distance_to(second_body[i]))
	check(displacement > 0.10, "The real skinned body geometry follows the antenna motion")
	snapshot(e, "02-idle-b")
	var elapsed: float = e.motion.time
	anatomy.animate(e, "run", 0.25, 1.0 / 60.0)
	check(is_equal_approx(e.motion.time - elapsed, 1.0 / 60.0), "Secondary motion uses real time instead of accelerated leg animation time")
	tick(e, "ready", 20)
	var closed_width = width(e)
	tick(e, "windup", 20)
	check(e.motion.open > 0.8, "Windup opens wings before the actual rush")
	snapshot(e, "03-windup")
	e.dash_flying = false
	tick(e, "dash", 8, "run")
	check(e.flight == 0 and width(e) > closed_width * 1.8, "Ground rushes visibly spread wings without adding flight or speed")
	var down: Transform3D = bone(e, "hindwing_l")
	var tip_down: Vector3 = down * Vector3(0, 0.9, 0)
	var spread_shape: Dictionary = anatomy.wing_hit_shapes(e, -1)[1]
	var hit_center: Vector3 = e.node.global_transform * spread_shape.center
	var hit = main.ray_part(e, hit_center + Vector3(0, 1.5, 0), hit_center - Vector3(0, 1.5, 0))
	check(hit.get("part", "") == "wing_l", "Projectiles can hit the spread wing in its animated position")
	snapshot(e, "04-dash-a")
	tick(e, "dash", 2, "run")
	var up: Transform3D = bone(e, "hindwing_l")
	check(down.basis.get_rotation_quaternion().angle_to(up.basis.get_rotation_quaternion()) > 0.15, "Hindwings flap during a rush")
	check(absf(tip_down.y - (up * Vector3(0, 0.9, 0)).y) > 0.08, "The wingtip rises and falls, rather than merely twisting in place")
	snapshot(e, "05-dash-b")
	e.freeze = 1.0
	var frozen: Transform3D = bone(e, "antenna_l2")
	tick(e, "dash", 20, "run")
	check(frozen.is_equal_approx(bone(e, "antenna_l2")), "Freeze preserves the complete secondary pose")
	e.freeze = 0.0
	e.pin = 4.0
	tick(e, "dash", 25, "stagger")
	check(e.motion.open == 0.0, "Pinned enemies stop wing propulsion and fold their wings")
	e.pin = 0.0
	tick(e, "dash", 20)
	e.flight = 0.3
	main.break_part(e, "wing_l", Vector3(-1, 0, 0), 1)
	check(e.wings == 1 and not e.parts.wing_l.visible and e.flight == 0.0, "Wing destruction still removes the exact side and cancels flight")
	var fragment: MeshInstance3D = main.fragments[-1].node.get_child(0)
	check(fragment.mesh is ArrayMesh and fragment.skin == null, "Dropped wings retain their baked posed mesh independently of the live skeleton")
	tick(e, "dash", 25)
	check(e.motion.open == 0.0, "One-wing enemies cannot restart wing propulsion")
	snapshot(e, "06-broken-wing")
	var corpse: Dictionary = main.spawn_enemy(Vector3(3, 0, 0), false)
	tick(corpse, "dash", 20)
	anatomy.animate(corpse, "death", 0.6)
	var dead_pose: Transform3D = bone(corpse, "antenna_l2")
	anatomy.animate(corpse, "death", 0.0)
	check(dead_pose.is_equal_approx(bone(corpse, "antenna_l2")), "Death remains driven by the death clip without living feeler motion")
	var resting: Dictionary = main.spawn_enemy(Vector3(15, 0, 0), false)
	resting.wake_at = 20.0
	var resting_position: Vector3 = resting.pos
	main.time = 0.0
	main.update_enemies(0.1)
	check(resting.motion.time > 0.0 and resting.pos == resting_position, "First-room inactive roaches animate without waking or rushing early")
	print(JSON.stringify({"checks": checks, "failures": failures, "closed_wing_width": closed_width, "body_vertex_motion": displacement, "result": "PASS" if failures.is_empty() else "FAIL"}))
	quit(0 if failures.is_empty() else 1)
