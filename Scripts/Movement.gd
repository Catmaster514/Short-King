extends CharacterBody2D

@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var animated_sprite_2d: AnimatedSprite2D = $rotater/AnimatedSprite2D
@onready var sfx: audioContainerNode = $SFX
@onready var rotater: Node2D = $rotater

const MAX_SPEED = 1000.0

const HILL_SLIDE_SPEED = 700.0
const FLAT_SLIDE_SPEED = 350.0
const RUN_SPEED = 300.0
const JUMP_VELOCITY = -400.0

const ACCELERATION_MODIFIER:float = .05
const SLIDE_ACEL_MOD:float = 0.01
const SLIDE_SLOW_MODIFIER:float = 0.0001
const WALL_SLIDE_SPEED_MULT:float = 1
const AIR_SLIDE_ANGLE_MIN_SPEED = 100

const CROUCH_HEIGHT:int = 15
const C_BOX_HEIGHT:int = 33
const BASE_C_BOX_OFFSET:float = 0.0

const WALLJUMP_SPEED:Vector2 = Vector2(600, -400)
const WALL_SLIDE_JUMP_SPEED:Vector2 = Vector2(500, 400)
const WALL_FALL_SPEED:float = 100
const WALL_GRACE_PERIOD:int = 7

const VELOCITY_FRAMES_STORED:int = 3

const FLOOR_SNAP:float = 10.0

enum States {IDLE, RUN, CROUCH, WALLGRAB, WALLSLIDE, FALL, JUMP, SLIDE}
const STATE_NAMES = ["IDLE", "RUN", "CROUCH", "WALLGRAB","WALLSLIDE", "FALL", "JUMP", "SLIDE"]
const LOCKED_STATES = ["SLIDE"]

var baseGravityMult:float = 1
var gravityMult:float = 1

#checks if the player was sliding on the last frame, keeps them sliding in the air
var isSliding = false

var wasOnWall = [false, 7, 1]
var slidOffWall = true
var holdingWall:bool = false
var hitWall = [false,false]
var floorDirection:int = 1

var playerState:States
var direction:int = 0
var wallSlideDirection:Vector2 = Vector2.ONE
var lastVelocity:Vector2 = Vector2.ZERO
var velocityDirection:Vector2 = Vector2.ZERO



func _physics_process(delta: float) -> void:
	# Sets the player state based off of inputs
	playerState = movementState()
	velocityDirection = getDirection(velocity)
	
	if not is_on_floor():
		if wasOnWall[1] > 0 : wasOnWall[1] -= 1
		else: wasOnWall[0] = false 
		match playerState:
			States.WALLSLIDE:
				if hitWall[0]:
					if !hitWall[1]: 
						velocity.y =  wallSlideDirection.y * abs(lastVelocity.x) * WALL_SLIDE_SPEED_MULT
						print("Last x Velocity: " + str(lastVelocity.x) + ", NEW y velocity: " + str(velocity.y))
					
					wallSlideDirection = Vector2(get_wall_normal().x , getDirection(lastVelocity).y)
					
					rotation_degrees = 90 * wallSlideDirection.x
					
					
					hitWall[1] = false
					hitWall[0] = false
				direction = wallSlideDirection.x * wallSlideDirection.y
				if velocity.y > 0: velocity += get_gravity() * delta * baseGravityMult
				animated_sprite_2d.play("SLIDE")
				
				if Input.is_action_just_pressed("JUMP"): 
					velocity = Vector2(WALL_SLIDE_JUMP_SPEED.x * wallSlideDirection.x, WALL_SLIDE_JUMP_SPEED.y * velocityDirection.y)
					slidOffWall = false
				
			States.WALLGRAB:
				wasOnWall = [true, WALL_GRACE_PERIOD, get_wall_normal().x]
				if velocity.y > 0: velocity.y = WALL_FALL_SPEED
				else: velocity += get_gravity() * delta * baseGravityMult
				velocity.x = -wasOnWall[2]
				animated_sprite_2d.play("WALLGRAB")
				
			States.SLIDE:
				if velocity.x != 0:
					var velocityAngle = atan(velocity.y / velocity.x)
					rotater.rotation = velocityAngle
				direction = getDirection(velocity).x
				
				velocity += get_gravity() * delta * baseGravityMult
				animated_sprite_2d.play("SLIDE")
				
			States.JUMP:
				velocity += get_gravity() * delta * baseGravityMult
				animated_sprite_2d.play("JUMP")
				if direction: movePlayer(RUN_SPEED*direction)
				
			_:
				velocity += get_gravity() * delta * baseGravityMult
				animated_sprite_2d.play("FALL")
				if direction: movePlayer(RUN_SPEED*direction)
				

		if Input.is_action_just_pressed("JUMP") && wasOnWall[0]: 
			movePlayer(WALLJUMP_SPEED.x * wasOnWall[2], WALLJUMP_SPEED.y, 1.0, 1.0)
			sfx.playSound("JUMP")

	else:
		floor_snap_length = FLOOR_SNAP
		if get_floor_angle():
			floorDirection = getDirection(get_floor_normal()).x
			rotation = floorDirection * get_floor_angle()

		match playerState:
			States.WALLSLIDE: 
				velocity = Vector2(0,clamp(lastVelocity.x, -HILL_SLIDE_SPEED, -FLAT_SLIDE_SPEED))
				hitWall[1] = true
			States.CROUCH:
				if roundf(get_floor_angle() * 10):
					isSliding = true
					direction = floorDirection
					
					movePlayer(HILL_SLIDE_SPEED * direction, 0, SLIDE_ACEL_MOD, 1)
					
					direction = velocityDirection.x
					
					playerState = States.SLIDE
					animated_sprite_2d.play("SLIDE")
					
					if Input.is_action_just_pressed("JUMP"):
						playerState = States.JUMP
						floor_snap_length = 0
						
						velocity.y = JUMP_VELOCITY
						sfx.playSound("JUMP")
				elif velocity.x != 0:
					isSliding = true
					direction = velocityDirection.x
					playerState = States.SLIDE
					
					movePlayer(0, velocity.y, SLIDE_SLOW_MODIFIER, 1)
					animated_sprite_2d.play("SLIDE")
				else: 
					animated_sprite_2d.play("CROUCH")
					isSliding = false
				changeHitBox(CROUCH_HEIGHT)
			States.RUN:
				movePlayer(RUN_SPEED * direction)
				animated_sprite_2d.play("RUN")
			_:
				movePlayer(0)
				animated_sprite_2d.play("IDLE")

		if Input.is_action_just_pressed("JUMP"):
			playerState = States.JUMP
			velocity.y = JUMP_VELOCITY
			
			floor_snap_length = 0
			sfx.playSound("JUMP")

	if direction:
		animated_sprite_2d.transform.x = Vector2(direction * animated_sprite_2d.scale.x, 0)
	lastVelocity = velocity
	
	playPlayerSounds()
	apply_floor_snap()
	move_and_slide()
	#print(velocity)
#resets all player values to their base
func reset():
	rotation = 0
	rotater.rotation = 0
	isSliding = Input.is_action_pressed("CROUCH") && isSliding
	changeHitBox(C_BOX_HEIGHT)
	hitWall[0] = is_on_wall()
	hitWall[1] = hitWall[0] && is_on_floor()
	
	

func movePlayer(xSpeed:float, ySpeed:float = velocity.y, accelerationX = ACCELERATION_MODIFIER, accelerationY = ACCELERATION_MODIFIER):
	var speed = Vector2(move_toward(velocity.x, xSpeed, MAX_SPEED * accelerationX), move_toward(velocity.y, ySpeed, MAX_SPEED * accelerationY))
	
	
	velocity = speed


func movementState(resetOnChange := true):
	direction = Input.get_axis("LEFT", "RIGHT")
	var state
	
	if is_on_floor():
		if Input.is_action_just_pressed("JUMP"):
			state = States.JUMP
		elif Input.is_action_pressed("CROUCH"):
			if is_on_wall():
				state = States.WALLSLIDE 
			else:
				state = States.CROUCH
		elif direction:
			state = States.RUN
		else:
			state = States.IDLE
	else:
		if is_on_wall_only() && isSliding && Input.is_action_pressed("CROUCH"):
			state = States.WALLSLIDE
		elif (is_on_wall() || (is_on_ceiling() && get_wall_normal())) && -get_wall_normal().x == direction: 
			state = States.WALLGRAB
		elif isSliding && Input.is_action_pressed("CROUCH"):
			state = States.SLIDE
		elif velocity.y > 0:
			state = States.FALL
		else: 
			state = States.JUMP
	
	if resetOnChange && playerState != state: 
		#print("state is:" + str(STATE_NAMES[state] + ", last state is: " + str(STATE_NAMES[playerState])))
		if state == States.SLIDE && playerState == States.WALLSLIDE:
			wallSlideToFall()
		reset()
	# warning large print statement for testing
	#print("on wall:" + str(is_on_wall()) + ", fake on wall:" + str(is_on_ceiling() && get_wall_normal()) + ", combo bool statement: " + str((is_on_wall() || (is_on_ceiling() && get_wall_normal())) && -get_wall_normal().x == direction))
	return state
	

func playPlayerSounds():
	if playerState == States.RUN: sfx.playSound("RUN")
	elif playerState == States.SLIDE || playerState == States.WALLSLIDE: sfx.playSound("SLIDE")

func changeHitBox(height:int):
	var currentBoxHeight = collision.shape.height
	if height != currentBoxHeight:
		var offset:float = (currentBoxHeight - height)/2.0
		if offset < 0: offset = 0
		collision.position.y = offset + BASE_C_BOX_OFFSET
		collision.shape.height = height

#turns the player around a corner when they are sliding on a wall
func wallSlideToFall():
	for i in 4:
		await get_tree().process_frame
	velocity = Vector2(abs(velocity.y) * -wallSlideDirection.x, 0)
	print("boosted")

func getDirection(value:Vector2):
	var vectorDirection = Vector2.ZERO
	if value.x != 0: vectorDirection.x = value.x / abs(value.x) 
	if value.y != 0: vectorDirection.y = value.y / abs(value.y) 
	return vectorDirection
