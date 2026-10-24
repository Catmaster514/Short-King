extends CharacterBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var sfx: Node = $SFX

const MAX_SPEED = 300.0
const JUMP_VELOCITY = -400.0
const ACCELERATION_MODIFIER:float = .05

const WALLJUMP_SPEED:Vector2 = Vector2(600, -400)
const WALL_FALL_SPEED:float = 100
const WALL_GRACE_PERIOD:int = 7

const FLOOR_SNAP:float = 10.0

enum States {IDLE, RUN, CROUCH, SLIDE, WALLSLIDE, FALL, JUMP}

var baseGravityMult:float = 1
var gravityMult:float = 1

var wasOnWall = [false, 7, 1]
var holdingWall:bool = false
var floorDirection:int = 1

var playerState:States

func _physics_process(delta: float) -> void:
	# Add the gravity.
	var direction := Input.get_axis("Left", "Right")
	playerState = movementState(direction)
	print(get_floor_normal())
	
	if not is_on_floor():
		rotation = 0
		
		if wasOnWall[1] > 0 : wasOnWall[1] -= 1
		else: wasOnWall[0] = false 
		
		
		if playerState == States.WALLSLIDE: 
			wasOnWall = [true, WALL_GRACE_PERIOD, get_wall_normal().x]
			if velocity.y < 0: movePlayer(velocity.x, 0)
			else: 
				velocity.y = WALL_FALL_SPEED
		else: velocity += get_gravity() * delta * baseGravityMult
		
		
		if Input.is_action_just_pressed("Jump") && wasOnWall[0]: 
			movePlayer(WALLJUMP_SPEED.x * wasOnWall[2], WALLJUMP_SPEED.y, 1.0)
			playSound("Jump")
		
		if direction:
			movePlayer(MAX_SPEED * direction)
			animated_sprite_2d.transform.x = Vector2(direction, 0)
			animated_sprite_2d.play("Run")
		else: animated_sprite_2d.play("Jump")

	else:
		
		if get_floor_angle():
			floorDirection = (get_floor_normal().x / abs(get_floor_normal().x))
			rotation = floorDirection * get_floor_angle()
			
		
		
		
		
		if playerState == States.RUN:
			movePlayer(MAX_SPEED * direction)
			animated_sprite_2d.transform.x = Vector2(direction, 0)
			animated_sprite_2d.play("Run")
		else:
			movePlayer(0)
			animated_sprite_2d.play("Idle")
		
		if Input.is_action_just_pressed("Jump"):
			velocity.y = JUMP_VELOCITY
			floor_snap_length = 0
			playSound("Jump")
	
	playPlayerSounds()
	apply_floor_snap()
	move_and_slide()

func movePlayer(xSpeed:float, ySpeed:float = velocity.y, acceleration = ACCELERATION_MODIFIER):
	var speed
	if acceleration == 1: speed = Vector2(xSpeed, ySpeed)
	else: speed = Vector2(move_toward(velocity.x, xSpeed, MAX_SPEED * acceleration), move_toward(velocity.y, ySpeed, MAX_SPEED * acceleration))
	
	velocity = speed
func playSound(name :String):
	var sound:AudioStreamPlayer2D = sfx.find_child(name)
	if !sound.playing: sound.play()

func movementState(direction:int):
	if is_on_floor():
		if get_floor_angle() && Input.is_action_pressed("Crouch"): return States.SLIDE
		elif direction: return States.RUN
		else: return States.IDLE
	else:
		if is_on_wall_only() && -get_wall_normal().x == direction: return States.WALLSLIDE
		else: return States.FALL

func playPlayerSounds():
	if playerState == States.RUN:playSound("Run")
	if playerState == States.SLIDE || playerState == States.WALLSLIDE: playSound("Slide")
