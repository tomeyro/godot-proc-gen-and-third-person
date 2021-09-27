extends Spatial
class_name ProceduralIsland


onready var mesh_instance: MeshInstance = $StaticBody/MeshInstance
onready var mesh_shape: CollisionShape = $StaticBody/CollisionShape
onready var noise_sprite: Sprite = $Control/Sprite


export var map_size: float = 100
export var map_outside: float = 50
export var square_size: float = 3
export var min_height: float = 1
export var max_height: float = 100
export var map_bottom: float = -30

var center
var max_distance

var noise: OpenSimplexNoise
var noise2: OpenSimplexNoise
var tree_noise: OpenSimplexNoise
var point_heights = {}

var initialized: bool = false

var material: Material = preload("res://material.tres")

var tree: Mesh = preload("res://low_poly_tree.obj")
var tree_meshinstance: MeshInstance
var tree_bottom_material: Material = preload("res://tree_bottom_material.tres")
var tree_top_material: Material = preload("res://tree_top_material.tres")

var mesh_container: Spatial


func init() -> void:
    if initialized:
        return

    mesh_container = Spatial.new()
    add_child(mesh_container)

    tree.surface_set_material(0, tree_bottom_material)
    tree.surface_set_material(1, tree_top_material)
    tree_meshinstance = MeshInstance.new()
    tree_meshinstance.mesh = tree;
    tree_meshinstance.create_trimesh_collision()

    initialized = true


func clean() -> void:
    for child in mesh_container.get_children():
        child.free()


func generate() -> void:
    init()
    clean()
    randomize()

    noise = OpenSimplexNoise.new()
    noise.seed = randi()
    noise.octaves = 9
    #noise.persistence = rand_range(0.25, 0.75)
    noise.persistence = .5

    noise2 = OpenSimplexNoise.new()
    noise2.seed = randi()
    noise2.octaves = 9
    #noise2.persistence = rand_range(0.25, 0.75)
    noise2.persistence = 0.5

    tree_noise = OpenSimplexNoise.new()
    tree_noise.seed = randi()
    tree_noise.octaves = 9
    #tree_noise.persistence = rand_range(0.25, 0.75)
    tree_noise.persistence = 0.75

    DebugConsole.command_output(
        "Map Generated:\n" +
        ("Map Size: %s" % map_size) + "\n" +
        ("Map Extra: %s" % map_outside) + "\n" +
        ("Square Size: %s" % square_size) + "\n" +
        ("Min Height: %s" % min_height) + "\n" +
        ("Max Height: %s" % max_height) + "\n" +
        ("Map Bottom: %s" % map_bottom) + "\n" +
        ("Base Noise Seed: %s" % noise.seed) + "\n" +
        ("Base Noise Octaves: %s" % noise.octaves) + "\n" +
        ("Base Noise Persistence: %s" % noise.persistence) + "\n" +
        ("Added Noise Seed: %s" % noise2.seed) + "\n" +
        ("Added Noise Octaves: %s" % noise2.octaves) + "\n" +
        ("Added Noise Persistence: %s" % noise2.persistence)
    )

    var texture_size = map_size
    var texture: ImageTexture = ImageTexture.new()
    texture.create_from_image(noise.get_image(texture_size, texture_size))
    noise_sprite.texture = texture
    noise_sprite.scale = Vector2(1024 / texture_size * .125, 1024 / texture_size * .125)

    _build_array_mesh()


func _build_array_mesh() -> void:
    var array_mesh: ArrayMesh = ArrayMesh.new()

    var verts = PoolVector3Array()

    var normals_dict = {}
    var normals_avgs = {}

    var heights = []

    center = Vector2(map_size / 2.0, map_size / 2.0)
    max_distance = Vector2.ZERO.distance_squared_to(center)

    for x in range(-map_outside, map_size + map_outside):
        for z in range(-map_outside, map_size + map_outside):
            var pos_x = x * square_size
            var pos_z = z * square_size

            var noise_value = _get_noise_value(x, z)

            if not noise_value in heights:
                heights.append(noise_value)

            if noise_value == 0:
                continue

            var center_point = Vector3(pos_x + (square_size / 2), noise_value, pos_z + (square_size / 2))

            var avgs = []
            for set in [Vector2(-1, 1), Vector2(1, 1), Vector2(1, -1), Vector2(-1, -1)]:
                var upd_x = set.y
                var upd_z = set.x

                var avg_noise = (
                    noise_value + _get_noise_value(x, z + upd_z) + _get_noise_value(x + upd_x, z + upd_z) + _get_noise_value(x + upd_x, z)
                ) / 4
                avgs.append(avg_noise)

            var top_right = Vector3(pos_x + square_size, avgs[0], pos_z)
            var bottom_right = Vector3(pos_x + square_size, avgs[1], pos_z + square_size)
            var bottom_left = Vector3(pos_x, avgs[2], pos_z + square_size)
            var top_left = Vector3(pos_x, avgs[3], pos_z)

            var triangles = [
                center_point, top_right, bottom_right,
                center_point, bottom_right, bottom_left,
                center_point, bottom_left, top_left,
                center_point, top_left, top_right,
            ]

            verts.append_array(triangles)
            for t in range(4):
                var tnormal = _get_triangle_normal(triangles[(3 * t) + 2], triangles[(3 * t) + 1], triangles[(3 * t)])
                normals_dict[triangles[(3 * t)]] = normals_dict.get(triangles[(3 * t)], []) + [tnormal]
                normals_dict[triangles[(3 * t) + 1]] = normals_dict.get(triangles[(3 * t) + 1], []) + [tnormal]
                normals_dict[triangles[(3 * t) + 2]] = normals_dict.get(triangles[(3 * t) + 2], []) + [tnormal]

            if ((tree_noise.get_noise_2d(x, z) / 2.0) + .5) > .65 and noise_value > 1.2:
                var tree_copy = tree_meshinstance.duplicate()
                tree_copy.transform.origin = center_point
                var tree_scale = rand_range(0.020, 0.040)
                tree_copy.scale = Vector3(tree_scale, tree_scale, tree_scale)
                mesh_container.add_child(tree_copy)

    for vector_point in normals_dict:
        var normal_avg = Vector3.ZERO
        for tnormal in normals_dict[vector_point]:
            normal_avg += tnormal
        normal_avg = normal_avg / len(normals_dict[vector_point])
        normals_avgs[vector_point] = normal_avg

    var normals = PoolVector3Array()
    for vector_point in verts:
        normals.append(normals_avgs[vector_point])

    var array = []
    array.resize(Mesh.ARRAY_MAX)
    array[Mesh.ARRAY_VERTEX] = verts
    array[Mesh.ARRAY_NORMAL] = normals

    array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, array)

    array_mesh.surface_set_material(0, material)

    mesh_instance.mesh = array_mesh

    mesh_shape.shape = array_mesh.create_trimesh_shape()


func _get_noise_value(x: float, z: float) -> float:
    if x < 0 or x >= map_size or z < 0 or z >= map_size:
        return map_bottom

    var noise_value = (noise.get_noise_2d(x, z) / 2.0) + .5
    var distance = (Vector2(x, z).distance_squared_to(center) / max_distance)
    noise_value = max(noise_value - distance, 0)

    var noise_mod = (noise2.get_noise_2d(x, z) / 2.0) + .5
    var height_diff = max_height - min_height
    noise_value = noise_value * (min_height + (height_diff * noise_mod))

    return noise_value if noise_value != 0.0 else map_bottom


func _get_triangle_normal(a, b, c):
    # find the surface normal given 3 vertices (counter clock wise)
    var side1 = b - a
    var side2 = c - a
    var normal = side1.cross(side2)
    return normal.normalized()
