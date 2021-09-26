extends CanvasLayer


enum POSITIONS {
    top,
    bottom,
}


export(POSITIONS) var show: int = POSITIONS.bottom
export var log_history: float = 250
export var command_history: float = 250


onready var console: Control = $Console
onready var console_bg: Control = $Console/Background
onready var console_container: Control = $Console/MainContainer

onready var label: Label = $Console/MainContainer/OutputContainer/LiveContainer/TextContainer/Label

onready var live_text_scroll: ScrollContainer = $Console/MainContainer/OutputContainer/LiveContainer
onready var live_text_container: VBoxContainer = $Console/MainContainer/OutputContainer/LiveContainer/TextContainer
onready var fixed_text_scroll: ScrollContainer = $Console/MainContainer/OutputContainer/FixedContainer
onready var fixed_text_container: VBoxContainer = $Console/MainContainer/OutputContainer/FixedContainer/TextContainer

onready var command_line: LineEdit = $Console/MainContainer/InputContainer/CommandLine

onready var send_btn: Button = $Console/MainContainer/InputContainer/SendButton
onready var pause_btn: Button = $Console/MainContainer/InputContainer/PauseButton


var _registered_objects = {}

var fixed_messages: Dictionary = {}

var live_paused: bool = false

var command_line_focused: bool = false
var command_history_list: Array = []
var command_history_idx: int = -1

var console_height: float

# This list is printed using the help() command on the console.
# Use add_help to add additional messages to this list.
var _help = [
    "help() -> Show this message.",
    "clear() -> Clear the live console (left side).",
    "clear_fixed() -> Clear the fixed console (right side).",
    "exit() -> Exit the game.",
    "pause() -> Pause the live console.",
    "resume() -> Resume the live console.",
    "top() -> Move console to the top of the screen.",
    "bottom() -> Move console to the bottom of the screen.",
    "bigger([val: Float]) -> Increase the height of the console. Optionally pass the value you want to increase.",
    "smaller([val: Float]) -> Decrease the height of the console. Optionally pass the value you want to decrease.",
    "height(val: Float) -> Set a specific height for the console. If no value is passed, the current value is printed.",
    "register_object(key: String, obj) -> Register a new object to be accessible from the console (use DebugConsole.register_console programatically).",
    "add_help(command: String, help_msg: String) -> Add an additional message to this help list (use DebugConsole.add_help programatically).",
]


func _ready() -> void:
    # To test the debug console, add the DebugConsole.tscn scene in Project Settings > Autoload.
    if self != DebugConsole:
        queue_free()
        return

    console.visible = false

    live_text_container.remove_child(label)

    send_btn.connect("pressed", self, "_submit_command")
    pause_btn.connect("pressed", self, "_toggle_pause_live")

    command_line.connect("focus_entered", self, "_on_command_line_focused")
    command_line.connect("focus_exited", self, "_on_command_line_unfocused")

    fix_message("FPS", 0.0)
    welcome_message()
    command_line.grab_focus()

    console_height = get_viewport().size.y / 2


func _process(delta: float) -> void:
    fix_message("FPS", "%.2f" % ((1.0 / delta) if not is_zero_approx(delta) else 0.0))

    var viewport_size = get_viewport().size
    console_bg.rect_size = Vector2(viewport_size.x, console_height)
    console_container.rect_size = Vector2(viewport_size.x, console_height)
    if show == POSITIONS.top:
        console.rect_position = Vector2.ZERO
    else:
        console.rect_position = Vector2(0, viewport_size.y - console_height)
    if console_height > (viewport_size.y - 15):
        height(viewport_size.y)


func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed:
        match event.scancode:
            KEY_F9:
                if Input.is_key_pressed(KEY_CONTROL):
                    command_line.editable = !command_line.editable
                    continue
                console.visible = !console.visible
                if console.visible:
                    command_line.grab_focus()
                else:
                    command_line_focused = false
            KEY_ENTER:
                _submit_command()
            KEY_UP:
                _get_previous_command_from_history()
            KEY_DOWN:
                _get_next_command_from_history()


# Live Messages Methods


func log_message(msg, force: bool = false) -> void:
    if live_paused and not force:
        return
    var new_label = label.duplicate()
    new_label.text = "%s" % str(msg)
    live_text_container.add_child(new_label)
    if live_text_container.get_child_count() > log_history:
        live_text_container.get_children()[0].free()
    # Wait for next frame so the scroll container is actually resized.
    yield(get_tree(), "idle_frame")
    live_text_scroll.scroll_vertical = 99999999


func _toggle_pause_live() -> void:
    live_paused = !live_paused


# Fixed Messages Methods


func fix_message(key: String, msg) -> void:
    var new_label: Label = fixed_messages.get(key)
    if not new_label:
        new_label = label.duplicate()
    new_label.text = "%s: %s" % [key, msg]
    fixed_messages[key] = new_label
    if not new_label.get_parent():
        fixed_text_container.add_child(new_label)


# Command Line Methods


func _on_command_line_focused() -> void:
    command_line_focused = true


func _on_command_line_unfocused() -> void:
    command_line_focused = true


func _submit_command() -> void:
    if not command_line_focused or not console.visible:
        return

    var cmd = command_line.text.strip_edges()
    command_line.text = ""
    command_line.grab_focus()

    if not cmd or cmd == "":
        return

    log_message("$ %s" % cmd, true)
    _add_command_to_history(cmd)

    var expr = Expression.new()
    expr.parse(cmd, PoolStringArray(_registered_objects.keys()))
    var res = expr.execute(_registered_objects.values(), self)

    if expr.has_execute_failed():
        log_message("! ERROR: %s" % expr.get_error_text(), true)

    if res != null and not (res is GDScriptFunctionState):
        command_output(str(res))


func command_output(output) -> void:
    log_message("> %s" % output, true)


func _add_command_to_history(cmd_line: String) -> void:
    command_history_idx = -1
    if len(command_history_list) and command_history_list[0] == cmd_line:
        return
    command_history_list.push_front(cmd_line)
    if len(command_history_list) > command_history:
        command_history_list.pop_back()


func _get_command_from_history(add_idx: int) -> void:
    if not command_line_focused or not console.visible:
        return
    command_history_idx = min(max(command_history_idx + add_idx, -1), len(command_history_list) - 1)
    if command_history_idx < 0:
        command_line.text = ""
        return
    command_line.text = command_history_list[command_history_idx]


func _get_previous_command_from_history() -> void:
    _get_command_from_history(1)


func _get_next_command_from_history() -> void:
    _get_command_from_history(-1)


func register_object(key: String, object) -> void:
    # Registered objects will be accessible on the console using the specified key.
    # For example if you call: register_object('player', Player)
    # You can then access Player methods on the console by calling: player.method()
    _registered_objects[key.replace(" ", "_").strip_edges()] = object


# Default Commands


func welcome_message() -> void:
    command_output("Welcome to Godot's Debug Console :)")
    command_output("Call help() to see more commands.")
    command_output("Press CTRL + F9 to disable the input field.")
    command_output("====================================")


func clear() -> void:
    for free_label in live_text_container.get_children():
        free_label.free()
    welcome_message()


func clear_fixed() -> void:
    var copy_dict = {}
    for key in fixed_messages:
        copy_dict[key] = fixed_messages[key]
    fixed_messages = {}
    for key in copy_dict:
        copy_dict[key].free()


func exit() -> void:
    get_tree().quit()


func pause() -> void:
    live_paused = true
    command_output("Live console paused.")


func resume() -> void:
    live_paused = false
    command_output("Live console resumed.")


func top() -> void:
    show = POSITIONS.top


func bottom() -> void:
    show = POSITIONS.bottom


func bigger(increase: float = 10) -> void:
    height(max(console_height + increase, 0))


func smaller(decrease: float = 10) -> void:
    height(max(console_height - decrease, 0))


func height(value: float = -1) -> void:
    if value < 0:
        command_output("Current_height: %.2f" % console_container.rect_size.y)
        return
    console_height = min(max(value, 45), get_viewport().size.y - 15)


func help() -> void:
    var full_msg = ""
    for help_msg in _help:
        full_msg += "· %s\n" % help_msg
    if _registered_objects:
        full_msg += "· Registered objects: %s\n" % [_registered_objects.keys()]
    log_message(full_msg, true)


func add_help(method: String, help_msg: String) -> void:
    _help.append("%s -> %s" % [method.strip_edges(), help_msg.strip_edges()])
