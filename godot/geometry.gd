extends RefCounted

static func mat(c: Color, rough: float = 0.75, metal: float = 0.0) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m

static func box(parent: Node3D, pos: Vector3, size: Vector3, m: Material) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.material_override = m
	n.position = pos
	parent.add_child(n)
	return n

static func sphere(parent: Node3D, pos: Vector3, size: Vector3, m: Material, segments: int = 12) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = segments
	mesh.rings = maxi(8, segments / 2)
	n.mesh = mesh
	n.material_override = m
	n.position = pos
	n.scale = size
	parent.add_child(n)
	return n

static func rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, m: Material) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius * 0.8
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 4 if radius < 0.008 else 8
	mesh.rings = 1
	n.mesh = mesh
	n.material_override = m
	n.position = (a + b) * 0.5
	var dir = (b - a).normalized()
	if absf(dir.dot(Vector3.UP)) < 0.999:
		n.quaternion = Quaternion(Vector3.UP, dir)
	parent.add_child(n)
	return n

static func ring(parent: Node3D, pos: Vector3, radius: float, thickness: float, m: Material) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	var mesh = TorusMesh.new()
	mesh.inner_radius = maxf(0.01, radius - thickness)
	mesh.outer_radius = radius
	mesh.rings = 24
	mesh.ring_segments = 6
	n.mesh = mesh
	n.material_override = m
	n.position = pos
	parent.add_child(n)
	return n


static func merge(root: Node3D) -> ArrayMesh:
	var out = SurfaceTool.new()
	out.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part in root.get_children():
		if not part is MeshInstance3D:
			continue
		var src: Array = part.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = src[Mesh.ARRAY_NORMAL]
		var inds: PackedInt32Array = src[Mesh.ARRAY_INDEX] if src[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var color: Color = part.material_override.albedo_color
		var uvs: PackedVector2Array = src[Mesh.ARRAY_TEX_UV] if src[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		for i in range(inds.size() if inds.size() else verts.size()):
			var j: int = inds[i] if inds.size() else i
			out.set_color(color)
			var uv = uvs[j] if uvs.size() else Vector2(verts[j].x, verts[j].z)
			if part.material_override.has_meta("atlas"):
				var tile: int = part.material_override.get_meta("atlas")
				uv = uv.clamp(Vector2.ZERO, Vector2.ONE) * 0.484 + Vector2(0.008 + 0.5 * (tile % 2), 0.008 + 0.5 * (tile / 2))
			out.set_uv(uv)
			out.set_normal((part.transform.basis.inverse().transposed() * norms[j]).normalized())
			out.add_vertex(part.transform * verts[j])
	out.generate_tangents()
	return out.commit()


static func grid_mesh(parent: Node3D, rows: Array, m: Material, reverse: bool = false) -> MeshInstance3D:
	var out = SurfaceTool.new()
	out.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nr: int = rows.size()
	var nc: int = rows[0].size()
	for r in range(nr - 1):
		for c in range(nc - 1):
			var indices = [Vector2i(r, c), Vector2i(r + 1, c), Vector2i(r, c + 1), Vector2i(r, c + 1), Vector2i(r + 1, c), Vector2i(r + 1, c + 1)]
			if reverse: indices.reverse()
			for ij in indices:
				var j: int = ij.x
				var k: int = ij.y
				var du: Vector3 = rows[j][mini(k + 1, nc - 1)] - rows[j][maxi(k - 1, 0)]
				var dv: Vector3 = rows[mini(j + 1, nr - 1)][k] - rows[maxi(j - 1, 0)][k]
				var normal = du.cross(dv).normalized() * (-1.0 if reverse else 1.0)
				out.set_normal(normal)
				out.set_uv(Vector2(float(k) / (nc - 1), float(j) / (nr - 1)))
				out.add_vertex(rows[j][k])
	var node = MeshInstance3D.new()
	node.mesh = out.commit()
	node.material_override = m
	parent.add_child(node)
	return node


static func loft(parent: Node3D, sections: Array, m: Material, sides: int = 20, steps: int = 3) -> MeshInstance3D:
	var rows: Array = []
	for j in range((sections.size() - 1) * steps + 1):
		var i = mini(j / steps, sections.size() - 2)
		var t = float(j - i * steps) / steps
		var s: Vector4 = sections[i].lerp(sections[i + 1], t)
		var row: Array = []
		for k in range(sides + 1):
			var angle = TAU * k / sides
			row.append(Vector3(cos(angle) * s.y, s.z + sin(angle) * s.w, s.x))
		rows.append(row)
	var node = grid_mesh(parent, rows, m)
	var capped = SurfaceTool.new()
	capped.begin(Mesh.PRIMITIVE_TRIANGLES)
	capped.append_from(node.mesh, 0, Transform3D.IDENTITY)
	for end in [0, 1]:
		var section: Vector4 = sections[0] if end == 0 else sections[-1]
		var row: Array = rows[0] if end == 0 else rows[-1]
		var center = Vector3(0, section.z, section.x)
		for k in range(sides):
			var triangle = [center, row[k], row[k + 1]] if end == 0 else [center, row[k + 1], row[k]]
			for vertex in triangle:
				capped.set_normal(Vector3.FORWARD if end == 0 else Vector3.BACK)
				capped.set_uv(Vector2(vertex.x / maxf(0.001, section.y) * 0.5 + 0.5, (vertex.y - section.z) / maxf(0.001, section.w) * 0.5 + 0.5))
				capped.add_vertex(vertex)
	node.mesh = capped.commit()
	return node

static func curve(parent: Node3D, points: Array, radius: float, m: Material, taper: float = 0.2) -> void :
	for i in range(points.size() - 1):
		rod(parent, points[i], points[i + 1], lerpf(radius, radius * taper, float(i) / (points.size() - 1)), m)

static func cloth_material(color: Color, repeat: float = 3.0) -> StandardMaterial3D:
	var m = mat(color, 0.94)
	m.albedo_texture = load("res://assets/production/denim/denim_fabric_06_diff_1k.jpg")
	m.normal_enabled = true
	m.normal_texture = load("res://assets/production/denim/denim_fabric_06_nor_gl_1k.jpg")
	m.normal_scale = 0.65
	m.roughness_texture = load("res://assets/production/denim/denim_fabric_06_rough_1k.jpg")
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.uv1_scale = Vector3(repeat * 0.45, repeat * 0.45, 1)
	return m

static func roach_material() -> ShaderMaterial:
	var shader = Shader.new()
	shader.code = "shader_type spatial;\nrender_mode cull_disabled;\nuniform sampler2D cuticle : source_color, filter_linear_mipmap_anisotropic;\nuniform sampler2D baked_normal : hint_normal, filter_linear_mipmap_anisotropic;\nuniform sampler2D baked_roughness : filter_linear_mipmap_anisotropic;\nuniform sampler2D baked_ao : filter_linear_mipmap_anisotropic;\nuniform vec4 tint : source_color = vec4(1.0);\nuniform float hit = 0.0;\nuniform float frost = 0.0;\nuniform float burn = 0.0;\nuniform float gait = 1.0;\nuniform float phase = 0.0;\nuniform float stride_phase = 0.0;\nuniform float dissolve = 0.0;\nuniform float death = 0.0;\nvoid fragment(){\n vec2 cell=floor(UV*450.0);\n float grain=fract(sin(dot(cell,vec2(12.9898,78.233))+phase)*43758.5453);\n if(dissolve>0.0 && grain<dissolve)discard;\n vec3 tex = texture(cuticle,UV).rgb;\n vec3 base = tex*tint.rgb;\n NORMAL_MAP=texture(baked_normal,UV).rgb;\n NORMAL_MAP_DEPTH=0.45;\n AO=texture(baked_ao,UV).r;\n AO_LIGHT_AFFECT=.25;\n base = mix(base,vec3(0.30,0.75,0.94),frost*0.8);\n base = mix(base,base*vec3(.65,.65,.61),death*.65);\n ALBEDO = mix(base,vec3(1.0,0.94,0.77),hit);\n METALLIC = 0.0;\n ROUGHNESS = clamp(texture(baked_roughness,UV).r,.16,.85);\n SPECULAR = 0.32;\n EMISSION = vec3(1.0,0.18,0.025)*burn*0.7 + vec3(1.0,0.76,0.3)*hit*0.7;\n}"
































	var m = ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("cuticle", load("res://assets/production/roach/roach_albedo.png"))
	m.set_shader_parameter("baked_normal", load("res://assets/production/roach/roach_normal.png"))
	m.set_shader_parameter("baked_roughness", load("res://assets/production/roach/roach_roughness.png"))
	m.set_shader_parameter("baked_ao", load("res://assets/production/roach/roach_ao.png"))
	return m

static func player_model() -> Node3D:
	var root: Node3D = load("res://assets/production/hero/hero.gltf").instantiate()
	var rig = preload("res://anatomy.gd").collect(root)
	root.set_meta("rig", rig)
	var hand = Node3D.new()
	hand.name = "Weapon"
	hand.position = Vector3(0.24, 0.64, - 0.23)
	root.add_child(hand)
	return root

static func weapon_model(id: String) -> Node3D:
	return load("res://assets/production/chainsaw/chainsaw.gltf" if id == "chainsaw" else "res://assets/weapons/" + id + ".gltf").instantiate()

static func wing_point(side: int, t: float, u: float) -> Vector3:
	var width = 0.29 * pow(maxf(0.0001, sin(PI * (0.055 + t * 0.945))), 0.54)
	var arch = pow(maxf(0.0, 1 - u * u), 0.55)
	return Vector3(side * ( - 0.004 + width * u), 0.255 + 0.131 * arch * pow(maxf(0.0001, sin(PI * (0.16 + t * 0.84))), 0.35), - 0.255 + t * 0.91)

static func roach_parts() -> Dictionary:
	var parts = {}
	var shell = mat(Color("b48e70"))
	shell.set_meta("atlas", 0)
	var edge = mat(Color("9e8264"))
	edge.set_meta("atlas", 3)
	var line = mat(Color("d4b389"))
	line.set_meta("atlas", 2)
	var membrane = mat(Color("855637"))
	membrane.set_meta("atlas", 1)
	var dark = mat(Color(0.028, 0.022, 0.019, 0.3))
	var body = Node3D.new()
	loft(body, [Vector4( - 0.36, 0.12, 0.235, 0.07), Vector4( - 0.25, 0.235, 0.218, 0.092), Vector4( - 0.05, 0.267, 0.217, 0.107), Vector4(0.22, 0.28, 0.215, 0.104), Vector4(0.44, 0.245, 0.218, 0.079), Vector4(0.6, 0.122, 0.221, 0.035), Vector4(0.655, 0.005, 0.22, 0.005)], edge, 24, 2)

	for i in range(7):
		var z = - 0.08 + i * 0.1
		var width = 0.26 * (1.0 - pow(float(i) / 9, 3))
		var points: Array = []
		for k in range(13):
			var a = PI * k / 12
			points.append(Vector3( - cos(a) * width, 0.23 + sin(a) * 0.067, z + sin(a) * 0.026))
		curve(body, points, 0.009, line, 0.85)

	loft(body, [Vector4( - 0.555, 0.015, 0.275, 0.012), Vector4( - 0.515, 0.17, 0.291, 0.06), Vector4( - 0.435, 0.259, 0.3, 0.1), Vector4( - 0.34, 0.269, 0.295, 0.109), Vector4( - 0.245, 0.215, 0.274, 0.069), Vector4( - 0.22, 0.04, 0.263, 0.016)], shell, 28, 3)
	loft(body, [Vector4( - 0.72, 0.027, 0.215, 0.025), Vector4( - 0.653, 0.11, 0.236, 0.069), Vector4( - 0.555, 0.126, 0.244, 0.078), Vector4( - 0.485, 0.055, 0.24, 0.031)], edge, 20, 2)
	for side in [-1, 1]:
		var border: Array = []
		for k in range(14):
			var t = float(k) / 13
			border.append(Vector3(side * (0.08 + 0.19 * sin(t * PI)), 0.295, - 0.52 + t * 0.28))
		curve(body, border, 0.008, line, 0.85)

		var antenna: Array = []
		for k in range(29):
			var t = float(k) / 28
			antenna.append(Vector3(side * (0.094 + 0.39 * t + 0.08 * sin(t * PI)), 0.255 + 0.1 * sin(t * PI) - 0.1 * t, - 0.647 - 0.83 * t))
		curve(body, antenna, 0.011, edge, 0.04)
		for k in range(1, 24):
			var q: Vector3 = antenna[k]
			sphere(body, q, Vector3(0.015, 0.014, 0.018) * (1.0 - float(k) / 36), line, 8)
		for k in range(2):
			curve(body, [Vector3(side * 0.06, 0.211, - 0.687), Vector3(side * (0.1 + k * 0.018), 0.195, - 0.733), Vector3(side * 0.068, 0.18, - 0.782 - k * 0.025)], 0.009, line, 0.35)
		curve(body, [Vector3(side * 0.115, 0.22, 0.594), Vector3(side * 0.165, 0.21, 0.687), Vector3(side * 0.184, 0.18, 0.759)], 0.017, edge, 0.2)
	for side in [-1, 1]:

		sphere(body, Vector3(side * 0.042, 0.215, - 0.704), Vector3(0.068, 0.083, 0.065), shell, 18)
		curve(body, [Vector3(side * 0.04, 0.19, - 0.722), Vector3(side * 0.064, 0.154, - 0.749), Vector3(side * 0.013, 0.153, - 0.774)], 0.016, dark, 0.2)
		for j in range(3):
			curve(body, [Vector3(side * 0.08, 0.2 - j * 0.014, - 0.69), Vector3(side * (0.14 + j * 0.014), 0.17, - 0.735), Vector3(side * 0.1, 0.148, - 0.8 - j * 0.013)], 0.006, line, 0.15)
	parts["body"] = merge(body)
	body.free()
	var eyes = Node3D.new()
	for side in [-1, 1]:
		sphere(eyes, Vector3(side * 0.137, 0.286, - 0.573), Vector3(0.09, 0.083, 0.112), dark, 16)
	parts["eyes"] = merge(eyes)
	eyes.free()
	for side in [-1, 1]:
		var wing = Node3D.new()
		var rows: Array = []
		for j in range(25):
			var row: Array = []
			for k in range(11): row.append(wing_point(side, float(j) / 24, float(k) / 10))
			rows.append(row)
		grid_mesh(wing, rows, membrane, side == 1)

		for vein in range(6):
			var points: Array = []
			for k in range(19):
				var t = 0.06 + k * 0.049
				var u = 0.1 + vein * 0.143 + sin(t * PI) * 0.018
				points.append(wing_point(side, t, u) + Vector3(0, 0.0018, 0))
			curve(wing, points, 0.0015, membrane, 0.2)

		for j in range(4):
			var t = 0.24 + j * 0.137
			var u = 0.22 + j * 0.133
			curve(wing, [wing_point(side, t, u) + Vector3(0, 0.001, 0), wing_point(side, t + 0.09, u + 0.075) + Vector3(0, 0.001, 0), wing_point(side, t + 0.16, u + 0.14) + Vector3(0, 0.001, 0)], 0.00065, membrane, 0.18)
		var margin: Array = []
		for k in range(23): margin.append(wing_point(side, float(k) / 22, 0.995))
		curve(wing, margin, 0.006, edge, 0.55)
		parts["wing_l" if side == -1 else "wing_r"] = merge(wing)
		wing.free()
		for j in range(3):
			var leg = Node3D.new()
			var z = - 0.29 + j * 0.31
			var a = Vector3(side * 0.19, 0.23, z)
			var hip = Vector3(side * 0.28, 0.216, z - 0.045)
			var b = Vector3(side * (0.48 + 0.05 * j), 0.17, z + (j - 1) * 0.22)
			var c = Vector3(side * (0.62 + 0.06 * j), 0.043, z + 0.14 + (j - 1) * 0.31)
			rod(leg, a, hip, 0.028, edge)
			rod(leg, hip, b, 0.03, shell)
			sphere(leg, b, Vector3(0.053, 0.052, 0.051), edge, 10)
			rod(leg, b, c, 0.018, shell)
			var foot = c + Vector3(side * 0.075, - 0.021, 0.062)
			curve(leg, [c, c.lerp(foot, 0.45) + Vector3(0, 0.014, 0), foot, foot + Vector3(side * 0.032, 0, 0.052)], 0.01, edge, 0.15)
			for k in range(8):
				var q = b.lerp(c, 0.1 + k * 0.1)
				rod(leg, q, q + Vector3(side * 0.044, 0.01, - 0.041), 0.0047, dark)
			parts["leg_" + str(j + (0 if side == -1 else 3))] = merge(leg)
			leg.free()
	return parts


static func collect_static(node: Node3D, relative: Transform3D, groups: Dictionary) -> void :
	var transform = relative * node.transform
	if node is MeshInstance3D and node.mesh:
		for index in range(node.mesh.get_surface_count()):
			var m = node.material_override if node.material_override else node.mesh.surface_get_material(index)
			if not m is StandardMaterial3D: continue
			var key = str(m.albedo_color, m.roughness, m.metallic, m.cull_mode, m.uv1_scale, m.albedo_texture.resource_path if m.albedo_texture else "", m.normal_texture.resource_path if m.normal_texture else "", m.roughness_texture.resource_path if m.roughness_texture else "", m.ao_texture.resource_path if m.ao_texture else "")
			if not groups.has(key):
				var surface = SurfaceTool.new()
				surface.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[key] = {"surface": surface, "material": m}
			groups[key].surface.append_from(node.mesh, index, transform)
	for c in node.get_children():
		if c is Node3D: collect_static(c, transform, groups)

static func batch_static(root: Node3D) -> void :
	var groups = {}
	for child in root.get_children():
		if child is Node3D: collect_static(child, Transform3D.IDENTITY, groups)
	for child in root.get_children(): child.free()
	for key in groups:
		var node = MeshInstance3D.new()
		node.mesh = groups[key].surface.commit()
		node.material_override = groups[key].material
		root.add_child(node)
