extends Node3D

@export var initial_character: PlayerBody
@export var possession_distance := 40.0

var controlled_character: PlayerBody
var possession_requested := false

@onready var view: PlayerView = $Head


func _ready() -> void:
	# Movement commands must be ready before the body runs its physics step.
	process_physics_priority = -1
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	possess(initial_character, false)


func _unhandled_input(event: InputEvent) -> void:
	if view.is_transitioning:
		return
	if event is InputEventMouseMotion:
		controlled_character.look(event.relative)
	elif event.is_action_pressed("possess"):
		possession_requested = true


func _physics_process(_delta: float) -> void:
	if possession_requested:
		possession_requested = false
		_try_possess_aimed_character()
	_update_movement_input()


func _update_movement_input() -> void:
	var can_move := not view.is_transitioning
	controlled_character.move_input = Input.get_vector("left", "right", "forward", "back") if can_move else Vector2.ZERO
	controlled_character.wants_sprint = can_move and Input.is_action_pressed("sprint")
	controlled_character.wants_jump = can_move and Input.is_action_just_pressed("jump")


func _try_possess_aimed_character() -> void:
	if view.is_transitioning:
		return
	var target := _get_aimed_character()
	if target != null:
		possess(target)


func _get_aimed_character() -> PlayerBody:
	var origin := view.camera.global_position
	var end := origin - view.camera.global_basis.z * possession_distance
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [controlled_character.get_rid()]
	# Query world geometry too, so walls block possession.
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.get("collider") as PlayerBody


func possess(target: PlayerBody, animate := true) -> void:
	if controlled_character != null:
		controlled_character.set_controlled(false)
	controlled_character = target
	controlled_character.set_controlled(true)
	view.follow_character(target, animate)
