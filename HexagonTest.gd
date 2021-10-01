extends Spatial


const hex_radius: float = 2.0


export var world_size: int = 5
export var min_height: int = 0
export var max_height: int = 10

export var noise_octaves: int = 9
export(float, 0.1, 1, 0.1) var noise_persitance: float = 0.5


onready var hex = $hexagon
onready var player = $PlayerController/Player

onready var hex_land: Material = preload("res://hex_land.tres")
onready var hex_water: Material = preload("res://hex_water.tres")

onready var tree: Mesh = preload("res://low_poly_tree.obj")
onready var tree_bottom_material: Material = preload("res://tree_bottom_material.tres")
onready var tree_top_material: Material = preload("res://tree_top_material.tres")


var noise: OpenSimplexNoise
var tree_noise: OpenSimplexNoise
var hex_container: Spatial

var hex_long_diagonal: float
var hex_short_diagonal: float
var hex_apothem: float  # incircle_radius
var hex_half_radius: float

var half_world_size: float
var center: Vector2
var max_distance: float
var height_diff: float

var tree_meshinstance: MeshInstance


func _ready() -> void:
    remove_child(hex)

    tree.surface_set_material(0, tree_bottom_material)
    tree.surface_set_material(1, tree_top_material)
    tree_meshinstance = MeshInstance.new()
    tree_meshinstance.mesh = tree;
    tree_meshinstance.create_trimesh_collision()

    _generate()


func _generate() -> void:
    randomize()

    noise = OpenSimplexNoise.new()
    noise.seed = randi()
    noise.octaves = noise_octaves
    noise.persistence = noise_persitance

    tree_noise = OpenSimplexNoise.new()
    tree_noise.seed = randi()
    tree_noise.octaves = noise_octaves
    tree_noise.persistence = noise_persitance

    _clean_world()
    _compute_vars()
    _create_world()
    _position_player()


func _clean_world() -> void:
    if hex_container:
        hex_container.free()
    hex_container = Spatial.new()
    add_child(hex_container)


func _compute_vars() -> void:
    hex_long_diagonal = hex_radius * 2.0
    hex_short_diagonal = sqrt(3.0) * hex_radius
    hex_apothem = hex_short_diagonal / 2.0
    hex_half_radius = hex_radius / 2.0

    half_world_size = world_size / 2.0
    center = Vector2(half_world_size, half_world_size)
    max_distance = Vector2.ZERO.distance_squared_to(center)
    height_diff = max_height - min_height


func _create_world() -> void:
    var world_range = range(-half_world_size, world_size + half_world_size)
    for x in world_range:
        var odd_x = x % 2 != 0
        for z in world_range:
            var distance = (Vector2(x, z).distance_squared_to(center) / max_distance)
            var actual_distance = distance
            if x < 0 or z < 0 or x >= world_size or z >= world_size:
                distance = 1

            var noise_value = max((noise.get_noise_2d(x, z) / 2.0) + .5 - distance, 0)
            var y = min_height + round(height_diff * noise_value)

            var hex_offset = Vector3(hex_half_radius * x, 0.0, hex_apothem if odd_x else 0.0)
            var hex_position = Vector3(x, 0, z) * Vector3(hex_long_diagonal, 1.0, hex_short_diagonal)
            var hex_translation = hex_position - hex_offset

            for loop_y in range(min_height, y + 1):
                var new_hex = hex.duplicate()
                new_hex.translation = hex_translation + Vector3(0, loop_y, 0)
                var material: ShaderMaterial = (hex_land if loop_y > min_height else hex_water).duplicate()
                material.set_shader_param("object_translation", new_hex.translation)
                material.set_shader_param("distance_from_center", actual_distance)
                new_hex.get_node("Circle").material_override = material
                hex_container.add_child(new_hex)

            if y > min_height:
                var tree_noise_value = (tree_noise.get_noise_2d(x, z) / 2.0) + .5
                if tree_noise_value > 0.55:
                    var tree_copy = tree_meshinstance.duplicate()
                    tree_copy.transform.origin = hex_translation + Vector3(0, y, 0)
                    var tree_scale = rand_range(0.020, 0.040)
                    tree_copy.scale = Vector3(tree_scale, tree_scale, tree_scale)
                    hex_container.add_child(tree_copy)


func _position_player() -> void:
    player.transform.origin = Vector3(center.x, max_height + 5, center.y)


func _process(delta: float) -> void:
    if Input.is_action_just_pressed("ui_end"):
        _generate()
