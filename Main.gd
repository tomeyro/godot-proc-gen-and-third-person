extends Spatial


onready var island: ProceduralIsland = $ProceduralIsland
onready var player = $PlayerController/Player
onready var targetables = $Targetables


func _ready() -> void:
    DebugConsole.register_object("world", self)
    DebugConsole.register_object("player", player)

    DebugConsole.add_help(
        "world.generate_island(size: float, square_size: float, max_height: float, min_height: float)",
        "Regenerate the island with the given values. All values are optional. If 0 is passed in any value, the current value will be kept.")

    generate_island()


func generate_island(size: float = 0, square_size: float = 0, max_height: float = 0, min_height: float = 0) -> void:
    island.generate()
    if size > 0:
        island.map_size = size
    if square_size > 0:
        island.square_size = square_size
    if max_height > 0:
        island.max_height = max_height
    if min_height > 0:
        island.min_height = min_height
    player.translation = Vector3(island.center.x * island.square_size, 100, island.center.y * island.square_size)
    var targetable_offset = Vector3(5, 0, 5)
    var offset_multiplier = 1
    for targetable in targetables.get_children():
        targetable.translation = player.translation + (targetable_offset * offset_multiplier)
        targetable_offset += Vector3(5, 0, 5)
        offset_multiplier *= -1
