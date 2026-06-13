extends Area2D

# Spike terrain: hurts the player standing on it (10 damage every 0.5s). Does not
# block movement (it's a floor hazard).

const DAMAGE   = 10.0
const INTERVAL = 0.5

var _player_on: bool = false
var _timer: float    = 0.0

func _ready():
	collision_layer = 0
	collision_mask  = 2   # player
	monitoring = true
	var spr = PixelArt.sprite_from(PixelArt.make_spikes())
	add_child(spr)   # renders above floor tiles (added after them), below player
	var col = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(26, 22)
	col.shape = rect
	add_child(col)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D):
	if body.is_in_group("player"):
		_player_on = true
		_timer = 0.0   # hit immediately on stepping on

func _on_body_exited(body: Node2D):
	if body.is_in_group("player"):
		_player_on = false

func _process(delta: float):
	if not _player_on:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = INTERVAL
		var pl = GameManager.player_ref
		if is_instance_valid(pl) and pl.has_method("take_damage"):
			pl.take_damage(DAMAGE)
