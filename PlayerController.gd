extends Spatial


export var speed: float = 20
export var acceleration: float = 15
export var air_acceleration: float = 5
export var gravity: float = 75
export var max_fall_speed: float = 50
export var jump_force: float = 20

export var targetable_distance: float = 40

export var mouse_sensitivity: float = .3

export(float, -90, 0) var min_pitch: float = -50
export(float, 0, 90) var max_pitch: float = 50


onready var player: KinematicBody = $Player
onready var camera_pivot: Spatial = $CameraPivot
onready var target_pivot: Spatial = $TargetPivot


var camera_y_rotation: float = 0.0
var velocity: Vector3 = Vector3.ZERO
var y_velocity: float = 0

var on_screen_targets: Array = []
var targetable_targets: Array = []
var locked_target: Spatial


func _ready() -> void:
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

    TargetableSignals.connect("targetable_on_screen", self, "_on_targetable_on_screen")
    TargetableSignals.connect("targetable_off_screen", self, "_on_targetable_off_screen")


func _process(_delta: float) -> void:
    if Input.is_action_just_pressed("ui_cancel"):
        if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
            Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
        else:
            Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

    elif Input.is_action_just_pressed("lock_target"):
        _lock_on_next_target()


func _input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
        # Move camera pivot horizontally
        camera_pivot.rotation_degrees.y -= event.relative.x * mouse_sensitivity
        # Move camera pivot vertically
        camera_pivot.rotation_degrees.x -= event.relative.y * mouse_sensitivity
        camera_pivot.rotation_degrees.x = clamp(camera_pivot.rotation_degrees.x, min_pitch, max_pitch)


func _physics_process(delta: float) -> void:
    check_targets()

    var rotate_on = camera_pivot
    if locked_target != null:
        var target_pos = locked_target.global_transform.origin
        target_pivot.look_at(target_pos, Vector3.UP)
        rotate_on = target_pivot

    var movement = Vector3.ZERO
    movement += camera_pivot.transform.basis.z * (Input.get_action_strength("move_back") - Input.get_action_strength("move_forward"))
    movement += camera_pivot.transform.basis.x * (Input.get_action_strength("move_right") - Input.get_action_strength("move_left"))
    movement = movement.normalized()

    if (not is_zero_approx(movement.x) or not is_zero_approx(movement.z) or locked_target) and not is_equal_approx(player.rotation_degrees.y, rotate_on.rotation_degrees.y):
        player.rotation_degrees.y = rad2deg(lerp_angle(deg2rad(player.rotation_degrees.y), deg2rad(rotate_on.rotation_degrees.y), 10 * delta))

    var accel = acceleration if player.is_on_floor() else air_acceleration

    velocity = velocity.linear_interpolate(movement * speed, accel * delta)

    #if is_on_floor() and Input.is_action_just_pressed("jump"):
    if Input.is_action_just_pressed("jump"):
        y_velocity = jump_force
    elif player.is_on_floor():
        y_velocity = -.001
    else:
        y_velocity = max(y_velocity - (gravity * delta), -max_fall_speed)

    velocity.y = y_velocity

    if y_velocity > 0 or not player.is_on_floor():
        velocity = player.move_and_slide(velocity, Vector3.UP)
    else:
        velocity = player.move_and_slide_with_snap(velocity, Vector3.DOWN, Vector3.UP)

    camera_pivot.transform.origin = player.transform.origin
    target_pivot.transform.origin = player.transform.origin


func check_targets() -> void:
    targetable_targets = []
    var targets_to_check = [] + on_screen_targets
    if locked_target and not (locked_target in targets_to_check):
        targets_to_check.append(locked_target)
    for target in targets_to_check:
        if player.global_transform.origin.distance_to(target.global_transform.origin) > targetable_distance:
            continue
        targetable_targets.append(target)
    if locked_target and not (locked_target in targetable_targets):
        _unlock_target()


func _on_targetable_on_screen(targetable: PhysicsBody) -> void:
    on_screen_targets.append(targetable)


func _on_targetable_off_screen(targetable: PhysicsBody) -> void:
    on_screen_targets.erase(targetable)


func _lock_on_next_target() -> void:
    var available_targets = []
    for target in targetable_targets:
        if target in on_screen_targets:
            available_targets.append(target)
    var idx = -1
    if locked_target:
        idx = available_targets.find(locked_target)
    idx += 1
    _unlock_target()
    if not available_targets:
        return
    if idx >= len(available_targets):
        idx = 0
    locked_target = available_targets[idx]
    PlayerSignals.emit_signal("target_locked", locked_target)


func _unlock_target() -> void:
    if not locked_target:
        return
    PlayerSignals.emit_signal("target_unlocked", locked_target)
    locked_target = null
