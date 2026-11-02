extends Node3D

@export var initial_character: PlayerBody
@export var possession_distance := 40.0
@export var transition_duration := 0.45
@export var transition_fov_boost := 25.0
@export_range(0.1, 0.95) var transition_turn_start := 0.6

const MOUSE_SENSITIVITY = 0.005
const BASE_FOV = 75.0
const BOB_FREQ = 2.0
const BOB_AMP = 0.08

var controlled_character: PlayerBody
var yaw := 0.0
var pitch := 0.0
var t_bob := 0.0
var possession_requested := false
var transitioning := false
var transition_elapsed := 0.0
var transition_start := Vector3.ZERO
var transition_start_rotation := Quaternion.IDENTITY
var movement_fov := BASE_FOV

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D


func _ready() -> void:
	# Supply movement commands before the character runs its physics step.
	process_physics_priority = -1
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	controlled_character = initial_character
	controlled_character.set_controlled(true)
	_read_view_direction()
	_update_character_view()
	head.global_position = controlled_character.view_anchor.global_position
	head.global_basis = controlled_character.view_anchor.global_basis.orthonormalized()
	camera.make_current()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		get_viewport().set_input_as_handled()
		return

	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseButton and event.pressed:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			get_viewport().set_input_as_handled()
		return

	if transitioning:
		return

	if event is InputEventMouseMotion:
		yaw -= event.relative.x * MOUSE_SENSITIVITY
		pitch = clampf(pitch - event.relative.y * MOUSE_SENSITIVITY, deg_to_rad(-85), deg_to_rad(85))
		_update_character_view()
		head.global_basis = controlled_character.view_anchor.global_basis.orthonormalized()

	if event.is_action_pressed("possess"):
		# Ray queries are performed in the physics step.
		possession_requested = true


func _physics_process(_delta: float) -> void:
	if possession_requested:
		possession_requested = false
		_try_possess()

	var can_move := not transitioning and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	controlled_character.move_input = Input.get_vector("left", "right", "forward", "back") if can_move else Vector2.ZERO
	controlled_character.wants_sprint = can_move and Input.is_action_pressed("sprint")
	controlled_character.wants_jump = can_move and Input.is_action_just_pressed("jump")


func _process(delta: float) -> void:
	var destination := controlled_character.view_anchor.global_position
	var fov_boost := 0.0
	if transitioning:
		transition_elapsed += delta
		var progress := clampf(transition_elapsed / maxf(transition_duration, 0.001), 0.0, 1.0)
		var weight := smoothstep(0.0, 1.0, progress)
		# A pulse that starts and ends at zero, peaking halfway through the transfer.
		fov_boost = transition_fov_boost * pow(sin(progress * PI), 2.0)
		head.global_position = transition_start.lerp(destination, weight)
		var target_rotation := controlled_character.view_anchor.global_basis.get_rotation_quaternion()
		var flight_rotation := transition_start_rotation
		var flight_direction := destination - transition_start
		if flight_direction.length_squared() > 0.000001:
			var direction := flight_direction.normalized()
			# Avoid a degenerate look basis when travelling vertically.
			var up := Vector3.RIGHT if absf(direction.dot(Vector3.UP)) > 0.999 else Vector3.UP
			flight_rotation = Basis.looking_at(direction, up).get_rotation_quaternion()
		# Aim along the flight first; adopt the body's view only on arrival.
		var aim_weight := smoothstep(0.0, 0.15, progress)
		var turn_weight := smoothstep(transition_turn_start, 1.0, progress)
		var travel_rotation := transition_start_rotation.slerp(flight_rotation, aim_weight)
		head.global_basis = Basis(travel_rotation.slerp(target_rotation, turn_weight))
		camera.position = Vector3.ZERO
		if progress >= 1.0:
			transitioning = false
	else:
		head.global_position = destination
		head.global_basis = controlled_character.view_anchor.global_basis.orthonormalized()
		t_bob += delta * controlled_character.velocity.length() * float(controlled_character.is_on_floor())
		camera.position = Vector3(
			cos(t_bob * BOB_FREQ / 2.0) * BOB_AMP,
			sin(t_bob * BOB_FREQ) * BOB_AMP,
			0.0
		)

	# Include vertical velocity so jumping and falling also affect FOV.
	var speed := PlayerBody.SPRINT_SPEED if controlled_character.wants_sprint else PlayerBody.WALK_SPEED
	var target_fov := BASE_FOV + clampf(controlled_character.velocity.length(), 0.5, speed)
	movement_fov = lerpf(movement_fov, target_fov, minf(delta * 8.0, 1.0))
	camera.fov = movement_fov + fov_boost


func _try_possess() -> void:
	if transitioning:
		return

	var origin := camera.global_position
	var end := origin - camera.global_basis.z * possession_distance
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [controlled_character.get_rid()]
	# Keep world geometry in the query so walls block possession.
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return

	var target := hit["collider"] as PlayerBody
	if target == null or target == controlled_character:
		return

	possess(target)


func possess(target: PlayerBody) -> void:
	transition_start = camera.global_position
	transition_start_rotation = camera.global_basis.get_rotation_quaternion()
	controlled_character.set_controlled(false)
	controlled_character = target
	controlled_character.set_controlled(true)
	_read_view_direction()
	_update_character_view()
	transition_elapsed = 0.0
	transitioning = true
	t_bob = 0.0
	# Preserve the current view, including its headbob offset, at departure.
	head.global_position = transition_start
	camera.position = Vector3.ZERO
	camera.rotation = Vector3.ZERO


func _read_view_direction() -> void:
	# Each body remembers its view in its own anchor, including vertical look.
	var view_rotation := controlled_character.view_anchor.global_rotation
	yaw = view_rotation.y
	pitch = view_rotation.x


func _update_character_view() -> void:
	controlled_character.global_rotation.y = yaw
	# Restore the world-space look after turning the anchor's parent body.
	controlled_character.view_anchor.global_rotation = Vector3(pitch, yaw, 0.0)
