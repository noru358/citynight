# Input in one place. Keyboard: WASD/arrows move and aim, Space jump, Shift dash,
# K bash (hold to aim, release to launch). Pad: left stick, A jump, B dash, Y bash.
# Tests switch `scripted` on and write `held`/`edges` each physics frame instead.
extends Node
const ACTIONS: Dictionary = {
	&"left": [KEY_A, KEY_LEFT, JOY_BUTTON_DPAD_LEFT],
	&"right": [KEY_D, KEY_RIGHT, JOY_BUTTON_DPAD_RIGHT],
	&"up": [KEY_W, KEY_UP, JOY_BUTTON_DPAD_UP],
	&"down": [KEY_S, KEY_DOWN, JOY_BUTTON_DPAD_DOWN],
	&"jump": [KEY_SPACE, JOY_BUTTON_A],
	&"dash": [KEY_SHIFT, JOY_BUTTON_B],
	&"bash": [KEY_K, JOY_BUTTON_Y],
}
const DEADZONE: float = 0.3
var scripted: bool = false
var held: Dictionary = {}
var edges: Dictionary = {}
var blocked: bool = false

func _ready() -> void:
	process_physics_priority = 1000 # after everything else: scripted edges last one frame
	process_mode = Node.PROCESS_MODE_ALWAYS
	for action: StringName in ACTIONS:
		if InputMap.has_action(action): continue
		InputMap.add_action(action,0.2)
		for code: int in ACTIONS[action]:
			if code >= KEY_SPACE:
				var key: InputEventKey = InputEventKey.new()
				key.physical_keycode = code
				InputMap.action_add_event(action,key)
			else:
				var button: InputEventJoypadButton = InputEventJoypadButton.new()
				button.button_index = code
				InputMap.action_add_event(action,button)
	for pair: Array in [[&"left",JOY_AXIS_LEFT_X,-1.0],[&"right",JOY_AXIS_LEFT_X,1.0],[&"up",JOY_AXIS_LEFT_Y,-1.0],[&"down",JOY_AXIS_LEFT_Y,1.0]]:
		var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
		motion.axis = pair[1]
		motion.axis_value = pair[2]
		InputMap.action_add_event(pair[0],motion)

func _physics_process(_delta: float) -> void:
	edges.clear()

func is_held(action: StringName) -> bool:
	if blocked: return false
	if scripted: return bool(held.get(action,false))
	return Input.is_action_pressed(action)

func just(action: StringName) -> bool:
	if blocked: return false
	if scripted: return edges.has(action)
	return Input.is_action_just_pressed(action)

# Raw stick/keys direction, each axis in -1..1.
func dir() -> Vector2:
	if blocked: return Vector2.ZERO
	if scripted:
		return Vector2(float(held.get(&"right",0))-float(held.get(&"left",0)),float(held.get(&"down",0))-float(held.get(&"up",0)))
	var value: Vector2 = Vector2(Input.get_action_strength(&"right")-Input.get_action_strength(&"left"),Input.get_action_strength(&"down")-Input.get_action_strength(&"up"))
	return Vector2(value.x if absf(value.x) > DEADZONE else 0.0,value.y if absf(value.y) > DEADZONE else 0.0)

# Direction snapped to the 8 ways, or zero.
func dir8() -> Vector2:
	var value: Vector2 = dir()
	return Vector2(signf(value.x),signf(value.y)).normalized()
