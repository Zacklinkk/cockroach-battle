extends RefCounted


static func collect(model: Node) -> Dictionary:
	var out = {"parts": {}, "skeleton": null, "animation": null}
	for node in model.find_children("*", "", true, false):
		if node is MeshInstance3D and (node.name in ["body", "eyes", "wing_l", "wing_r"] or str(node.name).begins_with("leg_")):
			out.parts[str(node.name)] = node
		elif node is Skeleton3D: out.skeleton = node
		elif node is AnimationPlayer: out.animation = node
	if out.animation:
		out.animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for key in out.animation.get_animation_list():
			out.animation.get_animation(key).loop_mode = Animation.LOOP_NONE if key == "death" else Animation.LOOP_LINEAR
		out.animation.play("idle")
		out.animation.advance(0)
	out.motion = {"bones": {}, "rest": {}, "wing_bind": {}, "time": 0.0, "open": 0.0}
	if out.skeleton and out.skeleton.find_bone("antenna_l0") >= 0:
		for side in ["l", "r"]:
			for name in ["antenna_" + side + "0", "antenna_" + side + "1", "antenna_" + side + "2", "forewing_" + side, "hindwing_" + side]:
				var index = out.skeleton.find_bone(name)
				if index >= 0:
					out.motion.bones[name] = index
					out.motion.rest[name] = out.skeleton.get_bone_pose_rotation(index)
					if name.contains("wing_"):
						out.motion.wing_bind[name] = out.skeleton.get_bone_global_pose(index)
	return out

static func animate(e: Dictionary, clip: String, seconds: float, elapsed: float = -1.0) -> void :
	var player: AnimationPlayer = e.get("animation")
	if not is_instance_valid(player): return
	if float(e.get("freeze", 0.0)) > 0.0 and clip != "death": return
	var position = player.current_animation_position if player.current_animation == clip else 0.0
	if player.current_animation != clip: player.play(clip)
	var animation = player.get_animation(clip)
	position += seconds
	position = fposmod(position, animation.length) if animation.loop_mode == Animation.LOOP_LINEAR else minf(position, animation.length)


	player.seek(position, true)
	var skeleton: Skeleton3D = e.get("skeleton")
	if skeleton:
		if clip != "death": secondary_motion(e, skeleton, seconds if elapsed < 0.0 else elapsed)
		skeleton.force_update_all_bone_transforms()


static func secondary_motion(e: Dictionary, skeleton: Skeleton3D, dt: float) -> void:
	var motion: Dictionary = e.get("motion", {})
	if motion.is_empty() or motion.bones.is_empty(): return
	motion.time += maxf(dt, 0.0)
	var clock: float = motion.time
	var phase: float = float(e.get("gait_phase", 0.0))
	var attack: String = str(e.get("attack_state", "ready"))
	var restrained = float(e.get("pin", 0.0)) > 0.0 or float(e.get("flip", 0.0)) > 0.0
	var rushing = attack == "dash" and not restrained
	var alert = str(e.get("state", "idle")) in ["chase", "search", "investigate"]
	# A real-time clock keeps the feelers fluid when a fast leg cycle changes clips.
	# Each joint follows with a delay; local Z bends sideways, local X bends vertically.
	for side in ["l", "r"]:
		var sign_value = -1.0 if side == "l" else 1.0
		var scan = clock * (3.8 if alert else 2.5) + phase + (1.35 if side == "r" else 0.0)
		for joint in range(3):
			var name = "antenna_" + side + str(joint)
			if not motion.bones.has(name): continue
			var lag = float(joint) * 0.65
			var amplitude = (0.29 - float(joint) * 0.055) * (0.55 if rushing else 1.0)
			var sweep = amplitude * sin(scan - lag) + 0.045 * sin(clock * 7.1 + phase - lag * 2.0)
			var lift = 0.085 * sin(scan * 0.73 + sign_value - lag) - (0.10 if rushing else 0.0)
			var rotation: Quaternion = motion.rest[name] * Quaternion(Vector3.BACK, sweep) * Quaternion(Vector3.RIGHT, lift)
			skeleton.set_bone_pose_rotation(motion.bones[name], rotation)
	# Spread around the thorax's vertical axis, flap at its fore/aft hinge,
	# then feather the blade slightly. Long-axis twist alone cannot raise the wingtip.
	# All intact rushes use this visual cue; only the existing flying rushes gain height.
	var target_open = 0.0
	if not restrained and int(e.get("wings", 2)) == 2:
		if attack == "windup": target_open = 0.82
		elif rushing: target_open = 1.0
	motion.open = move_toward(float(motion.open), target_open, dt * (5.5 if target_open > motion.open else 3.5))
	for side in ["l", "r"]:
		var part: MeshInstance3D = e.get("parts", {}).get("wing_" + side)
		if not is_instance_valid(part) or not part.visible: continue
		var sign_value = -1.0 if side == "l" else 1.0
		var beat = sin(clock * TAU * 11.5 + phase + (0.16 if side == "r" else 0.0))
		var intensity = 1.0 if rushing else (0.16 if attack == "windup" else 0.0)
		for layer in ["forewing_", "hindwing_"]:
			var name = layer + side
			if not motion.bones.has(name): continue
			var fore = layer == "forewing_"
			var spread: float = (0.82 if fore else 1.27) * motion.open
			var flap: float = ((0.23 if fore else 0.30) + beat * intensity * (0.14 if fore else 0.64)) * motion.open
			var feather: float = beat * intensity * 0.12 * motion.open
			var rotation: Quaternion = Quaternion(Vector3.UP, -sign_value * flap) * Quaternion(Vector3.BACK, sign_value * spread) * motion.rest[name] * Quaternion(Vector3.UP, sign_value * feather)
			skeleton.set_bone_pose_rotation(motion.bones[name], rotation)


static func wing_hit_shapes(e: Dictionary, side: int) -> Array:
	var key = "wing_l" if side == -1 else "wing_r"
	if not e.parts[key].visible: return []
	var center = Vector3(side * 0.14, 0.3, 0.32)
	var radius = Vector3(0.15, 0.07, 0.57)
	var motion: Dictionary = e.get("motion", {})
	if motion.is_empty(): return [{"part": key, "center": center, "radius": radius}]
	var shapes: Array = []
	var skeleton: Skeleton3D = e.skeleton
	var local: Transform3D = e.node.global_transform.affine_inverse() * skeleton.global_transform
	for layer in ["forewing_", "hindwing_"]:
		var name = layer + ("l" if side == -1 else "r")
		if not motion.wing_bind.has(name): continue
		var current = skeleton.get_bone_global_pose(motion.bones[name])
		var delta: Transform3D = local * current * motion.wing_bind[name].affine_inverse() * local.affine_inverse()
		shapes.append({"part": key, "center": delta * center, "radius": radius, "basis": delta.basis})
	return shapes



static func posed_mesh(node: MeshInstance3D, skeleton: Skeleton3D) -> ArrayMesh:
	var result = ArrayMesh.new()
	if node.skin == null or skeleton == null:
		return node.mesh
	var skin: Skin = node.skin
	var matrices: Array[Transform3D] = []
	var local: Transform3D = node.global_transform.affine_inverse() * skeleton.global_transform
	for i in range(skin.get_bind_count()):
		var bind_name = skin.get_bind_name(i)
		var index = skeleton.find_bone(bind_name) if not bind_name.is_empty() else skin.get_bind_bone(i)
		matrices.append(local * skeleton.get_bone_global_pose(index) * skin.get_bind_pose(i) if index >= 0 else Transform3D.IDENTITY)
	for surface in range(node.mesh.get_surface_count()):
		var arrays: Array = node.mesh.surface_get_arrays(surface).duplicate(true)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var ids: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		var count: int = ids.size() / vertices.size()
		for v in range(vertices.size()):
			var p = Vector3.ZERO
			var n = Vector3.ZERO
			var t = Vector3.ZERO
			for j in range(count):
				var at = v * count + j
				if weights[at] <= 0: continue
				var transform: Transform3D = matrices[ids[at]]
				p += (transform * vertices[v]) * weights[at]
				n += (transform.basis * normals[v]) * weights[at]
				if tangents.size(): t += transform.basis * Vector3(tangents[v * 4], tangents[v * 4 + 1], tangents[v * 4 + 2]) * weights[at]
			vertices[v] = p
			normals[v] = n.normalized()
			if tangents.size():
				t = t.normalized()
				tangents[v * 4] = t.x
				tangents[v * 4 + 1] = t.y
				tangents[v * 4 + 2] = t.z
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TANGENT] = tangents
		arrays[Mesh.ARRAY_BONES] = null
		arrays[Mesh.ARRAY_WEIGHTS] = null
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		result.surface_set_material(surface, node.mesh.surface_get_material(surface))
	return result
