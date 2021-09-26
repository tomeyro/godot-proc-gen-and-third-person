extends Spatial


onready var island: ProceduralIsland = $ProceduralIsland
onready var player = $PlayerController/Player


func _ready() -> void:
    DebugConsole.register_object("world", self)
    DebugConsole.register_object("player", player)

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
    player.translation = Vector3(island.center.x, 100, island.center.y)
