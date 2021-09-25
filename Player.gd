extends Spatial


export var speed: float = 20
export var acceleration: float = 15
export var air_acceleration: float = 5
export var gravity: float = 75
export var max_fall_speed: float = 50
export var jump_force: float = 20

export var mouse_sensitivity: float = .3

export(float, -90, 0) var min_pitch: float = -50
export(float, 0, 90) var max_pitch: float = 50

onready var player: KinematicBody = $Player
onready var camera_pivot: Spatial = $CameraPivot
onready var camera_y_rotation: float = 0.0

var velocity: Vector3 = Vector3.ZERO
var y_velocity: float = 0


func _ready() -> void:
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _process(delta: float) -> void:
    if Input.is_action_just_pressed("ui_cancel"):
        if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
            Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
        else:
            Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
        #rotation_degrees.y -= event.relative.x * mouse_sensitivity
        camera_pivot.rotation_degrees.y -= event.relative.x * mouse_sensitivity

        camera_pivot.rotation_degrees.x -= event.relative.y * mouse_sensitivity
        camera_pivot.rotation_degrees.x = clamp(camera_pivot.rotation_degrees.x, min_pitch, max_pitch)


func _physics_process(delta: float) -> void:
    var movement = Vector3.ZERO
    #movement += transform.basis.z * (Input.get_action_strength("move_back") - Input.get_action_strength("move_forward"))
    #movement += transform.basis.x * (Input.get_action_strength("move_right") - Input.get_action_strength("move_left"))
    movement += camera_pivot.transform.basis.z * (Input.get_action_strength("move_back") - Input.get_action_strength("move_forward"))
    movement += camera_pivot.transform.basis.x * (Input.get_action_strength("move_right") - Input.get_action_strength("move_left"))
    movement = movement.normalized()

    if (not is_zero_approx(movement.x) or not is_zero_approx(movement.z)) and not is_equal_approx(player.rotation_degrees.y, camera_pivot.rotation_degrees.y):
        player.rotation_degrees.y = rad2deg(lerp_angle(deg2rad(player.rotation_degrees.y), deg2rad(camera_pivot.rotation_degrees.y), 10 * delta))

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
