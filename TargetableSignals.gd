extends Node


signal targetable_on_screen(targetable)
signal targetable_off_screen(targetable)


func register_targetable(targetable: PhysicsBody, notifier: VisibilityNotifier) -> void:
    notifier.connect("screen_entered", self, "_on_screen", [targetable])
    notifier.connect("screen_exited", self, "_off_screen", [targetable])


func _on_screen(targetable):
    emit_signal("targetable_on_screen", targetable)


func _off_screen(targetable):
    emit_signal("targetable_off_screen", targetable)
