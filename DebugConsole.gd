extends Control


# Emmited when a new command is submitted in the terminal.
signal command_submitted(cmd, args)


export var log_history: float = 250
export var trigger_action: String = "debug_toggle"
export var command_history: float = 250
export var command_submit_action: String = "debug_submit_command"


onready var label: Label = $MainContainer/OutputContainer/LiveContainer/TextContainer/Label

onready var live_text_scroll: ScrollContainer = $MainContainer/OutputContainer/LiveContainer
onready var live_text_container: VBoxContainer = $MainContainer/OutputContainer/LiveContainer/TextContainer
onready var fixed_text_scroll: ScrollContainer = $MainContainer/OutputContainer/FixedContainer
onready var fixed_text_container: VBoxContainer = $MainContainer/OutputContainer/FixedContainer/TextContainer

onready var command_line: LineEdit = $MainContainer/InputContainer/CommandLine

onready var send_btn: Button = $MainContainer/InputContainer/SendButton
onready var pause_btn: Button = $MainContainer/InputContainer/PauseButton


var fixed_messages: Dictionary = {}
var live_paused: bool = false
var command_line_focused: bool = false
var command_history_list: Array = []
var command_history_idx: int = -1


func _ready() -> void:
    visible = false

    live_text_container.remove_child(label)

    connect("command_submitted", self, "_on_command_submitted")

    send_btn.connect("pressed", self, "submit_command")
    pause_btn.connect("pressed", self, "toggle_pause_live")

    command_line.connect("focus_entered", self, "_on_command_line_focused")
    command_line.connect("focus_exited", self, "_on_command_line_unfocused")

    fix_message("FPS", 0.0)
    welcome_message()


func _process(delta: float) -> void:
    if Input.is_action_just_pressed(trigger_action):
        visible = !visible
        if visible:
            command_line.grab_focus()

    fix_message("FPS", "%.2f" % ((1.0 / delta) if not is_zero_approx(delta) else 0))

    if command_line_focused:
        if Input.is_action_just_pressed(command_submit_action):
            submit_command()
        elif Input.is_action_just_pressed("ui_down"):
            _get_next_command_from_history()
        elif Input.is_action_just_pressed("ui_up"):
            _get_previous_command_from_history()


# Live Messages Methods


func log_message(msg, force: bool = false) -> void:
    if live_paused and not force:
        return
    var new_label = label.duplicate()
    new_label.text = "%s" % msg
    live_text_container.add_child(new_label)
    if live_text_container.get_child_count() > log_history:
        live_text_container.get_children()[0].free()
    # Wait for next frame so the scroll container is actually resized.
    yield(get_tree(), "idle_frame")
    live_text_scroll.scroll_vertical = 9999999


func toggle_pause_live() -> void:
    live_paused = !live_paused


func pause_live() -> void:
    live_paused = true


func unpause_live() -> void:
    live_paused = false


func welcome_message() -> void:
    command_output("Welcome to Godot's Debug Terminal :)")
    command_output("====================================")


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


func submit_command() -> void:
    var cmd_line = command_line.text.strip_edges()
    if not cmd_line or cmd_line == "":
        command_line.text = ""
        command_line.grab_focus()
        return
    log_message('$ %s' % cmd_line, true)
    var cmd = cmd_line.split(" ", true, 1)[0].to_lower()
    var args = cmd_line.split(" ", true, 1)[1] if " " in cmd_line else ""
    emit_signal("command_submitted", cmd, args)
    command_line.text = ""
    command_line.grab_focus()
    _add_command_to_history(cmd_line)


func _add_command_to_history(cmd_line: String) -> void:
    command_history_idx = -1
    if len(command_history_list) and command_history_list[0] == cmd_line:
        return
    command_history_list.push_front(cmd_line)
    if len(command_history_list) > command_history:
        command_history_list.pop_back()


func _get_command_from_history(add_idx: int) -> void:
    command_history_idx = min(max(command_history_idx + add_idx, -1), len(command_history_list) - 1)
    if command_history_idx < 0:
        command_line.text = ""
        return
    command_line.text = command_history_list[command_history_idx]


func _get_previous_command_from_history() -> void:
    _get_command_from_history(1)


func _get_next_command_from_history() -> void:
    _get_command_from_history(-1)


# Default Commands


func command_output(output: String) -> void:
    log_message('> %s' % output, true)


func _on_command_submitted(cmd: String, args: String) -> void:
    var cmd_method = "_do_%s" % cmd
    if has_method(cmd_method):
        call(cmd_method, args)


func _do_echo(args: String) -> void:
    command_output(args)


func _do_fix(args: String) -> void:
    var split_args = args.split(" ", true, 1)
    if len(split_args) != 2:
        command_output("ERROR: Incorrect syntax. Expected: \"fix {key} {msg}\"")
        return
    fix_message(split_args[0], split_args[1])


func _do_clear(_args: String) -> void:
    for free_label in live_text_container.get_children():
        free_label.free()
    welcome_message()


func _do_clear_fixed(_args: String) -> void:
    var copy_dict = {}
    for key in fixed_messages:
        copy_dict[key] = fixed_messages[key]
    fixed_messages = {}
    for key in copy_dict:
        copy_dict[key].free()


func _do_quit_game(_args: String) -> void:
    get_tree().quit()


func _do_p(_args: String) -> void:
    toggle_pause_live()
    command_output("Live log paused." if live_paused else "Live log resumed.")


func _do_eval(args: String) -> void:
    var expr = Expression.new()
    expr.parse(args)
    var res = expr.execute()
    command_output("ERROR" if expr.has_execute_failed() else ("%s" % res))
