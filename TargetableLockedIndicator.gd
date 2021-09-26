extends Spatial


onready var parent = get_parent()


func _ready() -> void:
    visible = false

    PlayerSignals.connect("target_locked", self, "_on_target_locked")
    PlayerSignals.connect("target_unlocked", self, "_on_target_unlocked")


func _on_target_locked(targetable) -> void:
    if targetable == parent:
        visible = true


func _on_target_unlocked(targetable) -> void:
    if targetable == parent:
        visible = false
