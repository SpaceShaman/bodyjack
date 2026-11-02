extends CharacterBody3D
class_name PlayerBody

const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0
const JUMP_VELOCITY = 4.5
const GRAVITY = 9.8

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


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if is_controlled and wants_jump and is_on_floor():
		velocity.y = JUMP_VELOCITY
	wants_jump = false

	var speed := SPRINT_SPEED if wants_sprint else WALK_SPEED
	var input_dir := move_input if is_controlled else Vector2.ZERO
	var direction := (global_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if is_on_floor() and direction != Vector3.ZERO:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		var weight := minf(delta * (7.0 if is_on_floor() else 3.0), 1.0)
		velocity.x = lerpf(velocity.x, direction.x * speed, weight)
		velocity.z = lerpf(velocity.z, direction.z * speed, weight)

	move_and_slide()
