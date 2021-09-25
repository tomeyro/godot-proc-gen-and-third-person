extends Spatial


const map_size = 250

var noise: OpenSimplexNoise


func _ready() -> void:
    randomize()
    _generate()


func _process(delta: float) -> void:
    if Input.is_action_just_pressed("ui_end"):
        _generate()


func _generate() -> void:
    noise = OpenSimplexNoise.new()
    noise.seed = randi()
    noise.octaves = 9
    noise.persistence = rand_range(0.25, 0.75)

    var t = ImageTexture.new()
    t.create_from_image(noise.get_image(map_size, map_size))
    $Control/Sprite.texture = t
    $Control/Sprite.scale = Vector2(1024 / map_size * .125, 1024 / map_size * .125)

    _rebuild_gridmap()


func _rebuild_gridmap() -> void:
    $GridMap.clear()
    var heights = []

    var center = Vector2(map_size / 2.0, map_size / 2.0)
    var max_distance = Vector2.ZERO.distance_squared_to(center)

    var highest_point = Vector3(0, 0, 0)

    var max_height = round(rand_range(10.0, 40.0))

    for x in range(map_size):
        for z in range(map_size):
            var noise_value = (noise.get_noise_2d(x, z) / 2.0) + .5
            var distance = (Vector2(x, z).distance_squared_to(center) / max_distance)
            noise_value = max(noise_value - distance, 0)

            noise_value = round(noise_value * max_height)

            if not noise_value in heights:
                heights.append(noise_value)

            if noise_value == 0:
                continue

            if noise_value > highest_point.y:
                highest_point = Vector3(x, noise_value, z)

            for y in range(round(rand_range(-10, -6)), noise_value):
                $GridMap.set_cell_item(x, y, z, 0 if y < 0 else min(y + 1, 3))

    print(heights, highest_point)

    $Player.translation = (highest_point * 2) + Vector3(1, 10, 1)
