extends CharacterBody3D

const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0
var speed
const JUMP_VELOCITY = 4.5
const GRAVITY = 9.8
const MOUSE_SENSITIVITY = 0.005

const BASE_FOV = 75.0

const BOB_FREQ = 2.0
const BOB_AMP = 0.08
var t_bob = 0.0

@onready var Head = $Head
@onready var Camera = $Head/Camera3D

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		Head.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		Camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		Camera.rotation.x = clamp(Camera.rotation.x, deg_to_rad(-85), deg_to_rad(85))
		

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Handle jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Handle sprint
	if Input.is_action_pressed("sprint"):
		speed = SPRINT_SPEED
	else:
		speed = WALK_SPEED

	# Handle movement
	var input_dir := Input.get_vector("left", "right", "forward", "back")
	var direction = (Head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if is_on_floor():
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = lerp(velocity.x, direction.x * speed, delta * 7.0)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * 7.0)
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 3.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 3.0)
		
	Camera.transform.origin = _headbob(delta)
	
	# FOV
	var target_fov = BASE_FOV + clamp(velocity.length(), 0.5, speed)
	Camera.fov = lerp(Camera.fov, target_fov, delta * 8.0)

	move_and_slide()

func _headbob(delta) -> Vector3:
	t_bob += delta * velocity.length() * float(is_on_floor())
	var pos = Vector3.ZERO
	pos.y = sin(t_bob * BOB_FREQ) * BOB_AMP
	pos.x = cos(t_bob * BOB_FREQ / 2) * BOB_AMP
	return pos
