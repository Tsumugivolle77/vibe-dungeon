extends Node

const SFX_POOL_SIZE = 12

var music_player: AudioStreamPlayer
var sfx_pool: Array[AudioStreamPlayer] = []
var music_volume: float = 0.7
var sfx_volume: float = 1.0

func _ready():
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	for i in SFX_POOL_SIZE:
		var p = AudioStreamPlayer.new()
		add_child(p)
		sfx_pool.append(p)

func play_music(stream: AudioStream, _loop: bool = true):
	if not stream:
		return
	music_player.stream = stream
	music_player.volume_db = linear_to_db(music_volume)
	music_player.play()

func stop_music():
	music_player.stop()

func play_sfx(stream: AudioStream, vol: float = 1.0):
	if not stream:
		return
	for p in sfx_pool:
		if not p.playing:
			p.stream = stream
			p.volume_db = linear_to_db(sfx_volume * vol)
			p.play()
			return

func set_music_volume(v: float):
	music_volume = clamp(v, 0.0, 1.0)
	if music_player.playing:
		music_player.volume_db = linear_to_db(music_volume)

func set_sfx_volume(v: float):
	sfx_volume = clamp(v, 0.0, 1.0)
