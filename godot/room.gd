extends Node3D
const G = preload("res://geometry.gd")
var blocks: Array[Rect2] = []
var nests: Array[Vector3] = []
var room_size = Vector2(42, 56)
var rng = RandomNumberGenerator.new()
var floor_mat: StandardMaterial3D
var board_mat: StandardMaterial3D
var navigation: AStarGrid2D

func build(seed_number: int) -> void :
	rng.seed = seed_number
	floor_mat = G.mat(Color("d4cbc0"), 0.94)
	if ResourceLoader.exists("res://assets/floor.png"):
		floor_mat.albedo_texture = load("res://assets/floor.png")
		floor_mat.uv1_scale = Vector3(7, 9, 1)
	board_mat = G.mat(Color("e0ceaf"), 0.91)
	if ResourceLoader.exists("res://assets/cardboard.png"):
		board_mat.albedo_texture = load("res://assets/cardboard.png")
	G.box(self, Vector3(0, -0.13, 0), Vector3(room_size.x, 0.25, room_size.y), floor_mat)
	var wall = G.mat(Color("4b4840"))
	G.box(self, Vector3(-21, 1.5, 0), Vector3(0.6, 3, 56), wall)
	G.box(self, Vector3(21, 1.5, 0), Vector3(0.6, 3, 56), wall)
	G.box(self, Vector3(0, 1.5, -28), Vector3(42, 3, 0.6), wall)
	G.box(self, Vector3(0, 0.15, 28), Vector3(42, 0.3, 0.6), wall)
	for pos in [Vector2(-15, -21), Vector2(14, -20), Vector2(-15, -6), Vector2(14, 8), Vector2(-13, 21)]:
		var c = pos + Vector2(rng.randf_range(-1.7, 1.7), rng.randf_range(-1.6, 1.6))
		make_box(c, Vector2(rng.randf_range(5.0, 7.5), rng.randf_range(4.5, 6)), rng.randf_range(2.8, 4.5))
	for pos in [Vector2(-5, -13), Vector2(6, 16), Vector2(8, -5)]:
		make_box(pos + Vector2(rng.randf_range(-1.3, 1.3), rng.randf_range(-1, 1)), Vector2(3.6, 4.1), 2.1)
	make_box(Vector2(5.8, 3.0), Vector2(4.5, 5.5), 3.2)
	make_slipper(Vector2(-5.5, 9.0))
	make_shelf(Vector2(15, 23))
	make_brush(Vector2(12, -12))
	make_cable(Vector3(-5.6, 0, 11.8))
	make_cable(Vector3(11.5, 0, -17.0))
	var paper = G.mat(Color("c9bda6"), 0.96)
	var dark = G.mat(Color("5a4936"), 0.94)
	var metal = G.mat(Color("707374"), 0.36, 0.72)
	var litter = Node3D.new()
	add_child(litter)
	for i in range(300):
		var p = Vector3(rng.randf_range(-20, 20), 0.025, rng.randf_range(-27, 27))
		if not clear_at(p, 0.05): continue
		if i % 19 == 0:
			make_paper(litter, p, Vector2(rng.randf_range(0.5, 1.3), rng.randf_range(0.5, 1.6)), paper)
		elif i % 29 == 0:
			make_screw(litter, p, metal)
		else:
			var size = rng.randf_range(0.022, 0.075)
			var grit = G.sphere(litter, p, Vector3(size * 1.8, size, size * 1.3), dark, 6)
			grit.rotation.y = rng.randf() * TAU
	for p in [Vector3(-2.8, 0.025, 4.5), Vector3(3.2, 0.025, 10.8), Vector3(-1.5, 0.025, 12.3)]:
		make_paper(litter, p, Vector2(1.5, 1.1), paper)
	make_screw(litter, Vector3(-3.4, 0.03, 7), metal)
	make_screw(litter, Vector3(2.7, 0.03, 6.3), metal)
	G.batch_static(self)
	rebuild_navigation()

func rebuild_navigation() -> void :
	navigation = AStarGrid2D.new()
	navigation.region = Rect2i(-26, -35, 53, 71)
	navigation.cell_size = Vector2(0.78, 0.78)
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.update()
	for x in range(-26, 27):
		for y in range(-35, 36):
			navigation.set_point_solid(Vector2i(x, y), not clear_at(Vector3(x * 0.78, 0, y * 0.78), 0.38))

func walkable_line(a: Vector3, b: Vector3) -> bool:
	var count = maxi(2, int(a.distance_to(b) * 4))
	for i in range(1, count + 1):
		if not clear_at(a.lerp(b, float(i) / count), 0.3): return false
	return true

func open_cell(p: Vector3) -> Vector2i:
	var cell = Vector2i(roundi(p.x / 0.78), roundi(p.z / 0.78))
	cell.x = clampi(cell.x, -25, 25)
	cell.y = clampi(cell.y, -34, 34)
	if not navigation.is_point_solid(cell): return cell
	for radius in range(1, 5):
		for x in range( - radius, radius + 1):
			for y in range( - radius, radius + 1):
				var candidate = cell + Vector2i(x, y)
				if navigation.is_in_boundsv(candidate) and not navigation.is_point_solid(candidate): return candidate
	return cell

func path_to(a: Vector3, b: Vector3) -> PackedVector3Array:
	var result = PackedVector3Array()
	var start = open_cell(a)
	var end = open_cell(b)
	if navigation.is_point_solid(start) or navigation.is_point_solid(end): return result
	var path = navigation.get_point_path(start, end)
	for point in path: result.append(Vector3(point.x, 0, point.y))
	return result

func make_paper(parent: Node3D, p: Vector3, size: Vector2, _m: Material) -> void :
	var variants = ["paper_crumpled_flat", "paper_crushed_heap", "paper_folded_torn"]
	var root: Node3D = load("res://assets/production/room-props/" + variants[rng.randi_range(0, 2)] + ".gltf").instantiate()
	root.position = p
	root.rotation.y = rng.randf() * TAU
	root.scale = Vector3(size.x, minf(size.x, size.y) * 0.75, size.y)
	parent.add_child(root)

func make_screw(parent: Node3D, p: Vector3, m: Material) -> void :
	var root = Node3D.new()
	root.position = p + Vector3(0, 0.1, 0)
	root.rotation.y = rng.randf() * TAU
	parent.add_child(root)
	G.rod(root, Vector3(0, 0, - 0.22), Vector3(0, 0, 0.36), 0.043, m)
	var head = G.rod(root, Vector3(0, 0, - 0.24), Vector3(0, 0, - 0.16), 0.108, m)
	head.mesh.radial_segments = 12
	var slot = G.mat(Color("29282a"), 0.58, 0.3)
	G.box(root, Vector3(0, 0, - 0.255), Vector3(0.142, 0.025, 0.009), slot)
	for j in range(7):
		var thread = G.ring(root, Vector3(0, 0, - 0.09 + j * 0.058), 0.065, 0.014, m)
		thread.rotation.x = PI / 2

func make_cable(p: Vector3) -> void :
	var cable = G.mat(Color("252323"), 0.48)
	var points: Array = []
	for i in range(95):
		var t = float(i) / 94 * TAU * 2.15
		var radius = 1.28 + 0.085 * t
		points.append(p + Vector3(cos(t) * radius, 0.115 + i * 0.0007, sin(t) * radius * 0.65))
	G.curve(self, points, 0.105, cable, 1)
	var end: Vector3 = points[-1]
	var lead = [end, end + Vector3(0.3, - 0.02, 0.45), end + Vector3(0.9, - 0.06, 0.85), end + Vector3(1.5, - 0.06, 1.1)]
	G.curve(self, lead, 0.102, cable, 1)
	G.box(self, lead[-1] + Vector3(0.18, 0.09, 0), Vector3(0.7, 0.29, 0.43), cable)
	var steel = G.mat(Color("a6a198"), 0.3, 0.85)
	for k in [-1, 1]:
		G.box(self, lead[-1] + Vector3(0.64, 0.09, k * 0.12), Vector3(0.32, 0.08, 0.055), steel)

func make_box(c: Vector2, size: Vector2, h: float) -> void :
	var root: Node3D = load("res://assets/production/box/box.gltf").instantiate()
	root.position = Vector3(c.x, 0.42, c.y)
	root.scale = Vector3(size.x, h, size.y)
	add_child(root)
	var edge = G.mat(Color("755238"), 0.95)
	for side in [-1, 1]:
		G.box(self, Vector3(c.x + side * (size.x * 0.5 - 0.18), 0.23, c.y), Vector3(0.32, 0.46, size.y * 0.86), board_mat)
	blocks.append(Rect2(c - size * 0.5, size))
	var nest = Vector3(c.x, 0, c.y + size.y * 0.5 + 0.65)
	nests.append(nest)
	var egg = G.mat(Color("776044"), 0.66)
	for j in range(3):
		var q = nest + Vector3(j * 0.32 - 0.32, 0.11, - 0.2)
		G.sphere(self, q, Vector3(0.24, 0.19, 0.42), egg, 12)
		for k in range(4):
			G.rod(self, q + Vector3( - 0.07, 0.075, - 0.12 + k * 0.075), q + Vector3(0.07, 0.075, - 0.12 + k * 0.075), 0.012, edge)

func make_slipper(c: Vector2) -> void :
	var root: Node3D = load("res://assets/production/room-props/worn_denim_slipper.gltf").instantiate()
	root.position = Vector3(c.x, 0, c.y)
	root.rotation.y = - 0.28
	root.scale = Vector3(3.0, 2.3, 6.4)
	add_child(root)
	blocks.append(Rect2(c - Vector2(1.5, 3.2), Vector2(3, 6.4)))

func make_shelf(c: Vector2) -> void :
	var m = G.mat(Color("555e60"), 0.4, 0.65)
	for dx in [-2.0, 2.0]:
		for dz in [-2.0, 2.0]:
			G.box(self, Vector3(c.x + dx, 2.5, c.y + dz), Vector3(0.35, 5, 0.35), m)
			blocks.append(Rect2(Vector2(c.x + dx - 0.3, c.y + dz - 0.3), Vector2(0.6, 0.6)))
	G.box(self, Vector3(c.x, 3.3, c.y), Vector3(4.6, 0.2, 4.6), m)

func make_brush(c: Vector2) -> void :
	var wood = G.mat(Color("9d784e"), 0.81)
	var bristle = G.mat(Color("8e7d5a"), 0.95)
	var root = Node3D.new()
	root.position = Vector3(c.x, 0, c.y)
	add_child(root)
	G.sphere(root, Vector3(0, 0.45, 0), Vector3(4.0, 0.45, 1.8), wood, 24)
	for i in range(26):
		for j in range(5):
			var x = -1.77 + i * 0.14
			var z = - 0.58 + j * 0.25
			G.rod(root, Vector3(x, 0.34, z), Vector3(x + rng.randf_range( - 0.08, 0.12), 0.027, z + 0.22), 0.025, bristle)
	blocks.append(Rect2(c - Vector2(2, 0.9), Vector2(4, 1.8)))

func clear_at(pos: Vector3, radius: float = 0.35) -> bool:
	if absf(pos.x) > 20.3 - radius or absf(pos.z) > 27.3 - radius:
		return false
	var p = Vector2(pos.x, pos.z)
	for b in blocks:
		if b.grow(radius).has_point(p):
			return false
	return true

func move_safe(pos: Vector3, delta: Vector3, radius: float = 0.35) -> Vector3:
	var next = pos + delta
	if clear_at(next, radius):
		return next
	var x = pos + Vector3(delta.x, 0, 0)
	if clear_at(x, radius):
		pos = x
	var z = pos + Vector3(0, 0, delta.z)
	if clear_at(z, radius):
		pos = z
	return pos

func visible_line(a: Vector3, b: Vector3) -> bool:
	var count = maxi(2, int(a.distance_to(b) * 2))
	for i in range(1, count):
		if not clear_at(a.lerp(b, float(i) / count), 0.02):
			return false
	return true

func random_floor() -> Vector3:
	for i in range(120):
		var p = Vector3(rng.randf_range(-19, 19), 0, rng.randf_range(-26, 26))
		if clear_at(p, 0.8):
			return p
	return Vector3.ZERO
