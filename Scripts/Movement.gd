extends CharacterBody2D

@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var sfx: Node = $SFX

const MAX_SPEED = 1000.0
const HILL_SLIDE_SPEED = 400.0
const FLAT_SLIDE_SPEED = 250.0
const RUN_SPEED = 300.0
const JUMP_VELOCITY = -400.0
const ACCELERATION_MODIFIER:float = .05
const SLIDE_ACEL_MOD:float = 0.1
const SLIDE_SLOW_MODIFIER:float = 0.001

const CROUCH_HEIGHT:int = 15
const C_BOX_HEIGHT:int = 33
const BASE_C_BOX_OFFSET:float = 0.0

const WALLJUMP_SPEED:Vector2 = Vector2(600, -400)
const WALL_FALL_SPEED:float = 100
const WALL_GRACE_PERIOD:int = 7

const FLOOR_SNAP:float = 10.0

enum States {IDLE, RUN, CROUCH, WALLSLIDE, FALL, JUMP, SLIDE}

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
	scale = Vector2.ONE
	rotation = 0
	changeHitBox(C_BOX_HEIGHT)
	
	if not is_on_floor():
		
		
		
		if wasOnWall[1] > 0 : wasOnWall[1] -= 1
		else: wasOnWall[0] = false 
		
		
		if playerState == States.WALLSLIDE: 
			wasOnWall = [true, WALL_GRACE_PERIOD, get_wall_normal().x]
			if velocity.y < 0: movePlayer(velocity.x, 0)
			else: 
				velocity.y = WALL_FALL_SPEED
			animated_sprite_2d.play("WallSlide")
		else: 
			velocity += get_gravity() * delta * baseGravityMult
			if velocity.y < 0 : animated_sprite_2d.play("Jump")
			else: animated_sprite_2d.play("Fall")
		
		
		if Input.is_action_just_pressed("Jump") && wasOnWall[0]: 
			movePlayer(WALLJUMP_SPEED.x * wasOnWall[2], WALLJUMP_SPEED.y, 1.0, 1.0)
			playSound("Jump")
		
		if direction:
			if abs(velocity.x) < RUN_SPEED: 
				movePlayer(RUN_SPEED * direction)
				print("air move")
			
			
		
		

	else:
		floor_snap_length = FLOOR_SNAP
		if get_floor_angle():
			floorDirection = (get_floor_normal().x / abs(get_floor_normal().x))
			rotation = floorDirection * get_floor_angle()
		
		
		match playerState:
			States.CROUCH:
				if roundf(get_floor_angle() * 10):
					
					direction = floorDirection
					print(floorDirection)
					movePlayer(HILL_SLIDE_SPEED * get_floor_normal().x, 1000, SLIDE_ACEL_MOD, 1)
					playerState = States.SLIDE
					animated_sprite_2d.play("Slide")
					
					if Input.is_action_just_pressed("Jump"):
						playerState = States.JUMP
						movePlayer(HILL_SLIDE_SPEED * direction, JUMP_VELOCITY, 1,1)
						floor_snap_length = 0
						playSound("Jump")
				elif velocity.x != 0:
					direction = velocity.x / abs(velocity.x)
					movePlayer(0, velocity.y, SLIDE_SLOW_MODIFIER, 1)
					playerState = States.SLIDE
				else: animated_sprite_2d.play("Crouch")
				changeHitBox(CROUCH_HEIGHT)
			States.RUN:
				movePlayer(RUN_SPEED * direction)
				animated_sprite_2d.play("Run")
			_:
				movePlayer(0)
				animated_sprite_2d.play("Idle")
		
		if Input.is_action_just_pressed("Jump"):
			playerState = States.JUMP
			velocity.y = JUMP_VELOCITY
			
			floor_snap_length = 0
			playSound("Jump")
			print("jumped")
	
	if direction: animated_sprite_2d.scale.x = direction * abs(animated_sprite_2d.scale.x)
	
	playPlayerSounds()
	apply_floor_snap()
	move_and_slide()

func movePlayer(xSpeed:float, ySpeed:float = velocity.y, accelerationX = ACCELERATION_MODIFIER, accelerationY = ACCELERATION_MODIFIER):
	var speed = Vector2(move_toward(velocity.x, xSpeed, MAX_SPEED * accelerationX), move_toward(velocity.y, ySpeed, MAX_SPEED * accelerationY))
	
	velocity = speed
func playSound(name:String):
	var sound:AudioStreamPlayer2D = sfx.find_child(name)
	if !sound.playing: sound.play()

func movementState(direction:int):
	if is_on_floor():
		
		if Input.is_action_pressed("Crouch"): return States.CROUCH
		elif direction: return States.RUN
		else: return States.IDLE
	else:
		if is_on_wall_only() && -get_wall_normal().x == direction: return States.WALLSLIDE
		else: return States.FALL

func playPlayerSounds():
	if playerState == States.RUN:playSound("Run")
	if playerState == States.SLIDE || playerState == States.WALLSLIDE: playSound("Slide")

func changeHitBox(height:int):
	var currentBoxHeight = collision.shape.size.y
	if height != currentBoxHeight:
		var offset:float = (currentBoxHeight - height)/2.0
		if offset < 0: offset = 0
		collision.position.y = offset + BASE_C_BOX_OFFSET
		collision.shape.size.y = height
