class_name PlayerBody
extends CharacterBody3D

const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0
const JUMP_VELOCITY = 4.5
const GRAVITY = 9.8
const MOUSE_SENSITIVITY = 0.005

var is_controlled := false
var move_input := Vector2.ZERO
var wants_sprint := false
var wants_jump := false

@onready var view_anchor: Marker3D = $ViewAnchor


func set_controlled(value: bool) -> void:
	is_controlled = value
	move_input = Vector2.ZERO
	wants_sprint = false
	wants_jump = false
	velocity.x = 0.0
	velocity.z = 0.0
	if value:
		_align_body_with_view(view_anchor.global_rotation)


func look(mouse_motion: Vector2) -> void:
	var view_rotation := view_anchor.global_rotation
	view_rotation.y -= mouse_motion.x * MOUSE_SENSITIVITY
	view_rotation.x = clampf(
		view_rotation.x - mouse_motion.y * MOUSE_SENSITIVITY,
		deg_to_rad(-85), deg_to_rad(85)
	)
	_align_body_with_view(view_rotation)


func _align_body_with_view(view_rotation: Vector3) -> void:
	global_rotation.y = view_rotation.y
	view_anchor.global_rotation = Vector3(view_rotation.x, view_rotation.y, 0.0)


func _physics_process(delta: float) -> void:
	_apply_gravity_and_jump(delta)
	_update_horizontal_velocity(delta)
	move_and_slide()


func _apply_gravity_and_jump(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif is_controlled and wants_jump:
		velocity.y = JUMP_VELOCITY
	wants_jump = false


func _update_horizontal_velocity(delta: float) -> void:
	var speed := SPRINT_SPEED if wants_sprint else WALK_SPEED
	var input_dir := move_input if is_controlled else Vector2.ZERO
	var direction := (global_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var target_velocity := direction * speed

	if is_on_floor() and direction != Vector3.ZERO:
		velocity.x = target_velocity.x
		velocity.z = target_velocity.z
	else:
		var acceleration := 7.0 if is_on_floor() else 3.0
		var weight := minf(delta * acceleration, 1.0)
		velocity.x = lerpf(velocity.x, target_velocity.x, weight)
		velocity.z = lerpf(velocity.z, target_velocity.z, weight)
