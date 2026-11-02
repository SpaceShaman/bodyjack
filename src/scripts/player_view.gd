class_name PlayerView
extends Node3D

@export var transition_duration := 0.45
@export var transition_fov_boost := 25.0
@export_range(0.1, 0.95) var transition_turn_start := 0.6

const BASE_FOV = 75.0
const BOB_FREQUENCY = 2.0
const BOB_AMPLITUDE = 0.08

var character: PlayerBody
var transition_progress := 1.0
var transition_start_position := Vector3.ZERO
var transition_start_rotation := Quaternion.IDENTITY
var movement_fov := BASE_FOV
var bob_time := 0.0
var is_transitioning: bool:
	get:
		return transition_progress < 1.0

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	camera.make_current()


func follow_character(target: PlayerBody, animate: bool) -> void:
	transition_start_position = camera.global_position
	transition_start_rotation = camera.global_basis.get_rotation_quaternion()
	character = target
	transition_progress = 0.0 if animate else 1.0
	bob_time = 0.0
	camera.position = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	if animate:
		global_position = transition_start_position
	else:
		_follow_view_anchor()


func _process(delta: float) -> void:
	if is_transitioning:
		_update_camera_flight(delta)
	else:
		_follow_view_anchor()
		_update_headbob(delta)
	_update_fov(delta)


func _follow_view_anchor() -> void:
	global_position = character.view_anchor.global_position
	global_basis = character.view_anchor.global_basis.orthonormalized()


func _update_camera_flight(delta: float) -> void:
	transition_progress = minf(transition_progress + delta / maxf(transition_duration, 0.001), 1.0)
	var destination := character.view_anchor.global_position
	var position_weight := smoothstep(0.0, 1.0, transition_progress)
	global_position = transition_start_position.lerp(destination, position_weight)

	var flight_rotation := _get_flight_rotation(destination)
	var target_rotation := character.view_anchor.global_basis.get_rotation_quaternion()
	var aim_weight := smoothstep(0.0, 0.15, transition_progress)
	var turn_weight := smoothstep(transition_turn_start, 1.0, transition_progress)
	var travel_rotation := transition_start_rotation.slerp(flight_rotation, aim_weight)
	global_basis = Basis(travel_rotation.slerp(target_rotation, turn_weight))


func _get_flight_rotation(destination: Vector3) -> Quaternion:
	var direction := destination - transition_start_position
	if direction.length_squared() < 0.000001:
		return transition_start_rotation
	direction = direction.normalized()
	# A vertical flight needs a different up axis to keep the basis valid.
	var up := Vector3.RIGHT if absf(direction.dot(Vector3.UP)) > 0.999 else Vector3.UP
	return Basis.looking_at(direction, up).get_rotation_quaternion()


func _update_headbob(delta: float) -> void:
	if character.is_on_floor():
		bob_time += delta * character.velocity.length()
	camera.position = Vector3(
		cos(bob_time * BOB_FREQUENCY / 2.0) * BOB_AMPLITUDE,
		sin(bob_time * BOB_FREQUENCY) * BOB_AMPLITUDE,
		0.0
	)


func _update_fov(delta: float) -> void:
	var speed_limit := PlayerBody.SPRINT_SPEED if character.wants_sprint else PlayerBody.WALK_SPEED
	var target_fov := BASE_FOV + clampf(character.velocity.length(), 0.5, speed_limit)
	movement_fov = lerpf(movement_fov, target_fov, minf(delta * 8.0, 1.0))
	var flight_boost := transition_fov_boost * pow(sin(transition_progress * PI), 2.0)
	camera.fov = movement_fov + flight_boost
