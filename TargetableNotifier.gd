extends VisibilityNotifier


func _ready() -> void:
    TargetableSignals.register_targetable(get_parent(), self)
