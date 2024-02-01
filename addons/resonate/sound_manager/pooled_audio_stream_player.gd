class_name PooledAudioStreamPlayer
extends AudioStreamPlayer


signal released

var pool_type
var reserved: bool
var poly: bool
var streams: Array


func _ready() -> void:
	finished.connect(on_finished)


static func create() -> PooledAudioStreamPlayer:
	return PoolEntity.create(PooledAudioStreamPlayer.new())


func configure(p_streams: Array, p_reserved: bool, p_bus: String, p_poly: bool, p_mode: Node.ProcessMode) -> void:
	var is_polyphonic = PoolEntity.configure(self, p_streams, p_reserved, p_bus, p_poly, p_mode)
	
	if is_polyphonic:
		super.play()


func trigger() -> void:
	var should_play = PoolEntity.trigger(self, false, 1.0, 0.0)
	
	if should_play:
		super.play()


func trigger_varied(p_pitch: float = 1.0, p_volume: float = 0.0) -> void:
	var should_play = PoolEntity.trigger(self, true, p_pitch, p_volume)
	
	if should_play:
		super.play()


func release(p_finish_playing: bool = false) -> void:
	PoolEntity.release(self, p_finish_playing)


func on_finished() -> void:
	PoolEntity.finished(self)
