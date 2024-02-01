extends Node


signal loaded
signal banks_updated

var has_loaded: bool = false

var _1d_players: Array[PooledAudioStreamPlayer] = []
var _2d_players: Array[PooledAudioStreamPlayer2D] = []
var _3d_players: Array[PooledAudioStreamPlayer3D] = []
var _event_table: Dictionary = {}
var _event_table_hash: int


func _init():
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	initialise_pool(ProjectSettings.get_setting(
			ResonatePlugin.POOL_1D_SIZE_SETTING_NAME,
			ResonatePlugin.POOL_1D_SIZE_SETTING_DEFAULT),
			create_player_1d)
			
	initialise_pool(ProjectSettings.get_setting(
			ResonatePlugin.POOL_2D_SIZE_SETTING_NAME,
			ResonatePlugin.POOL_2D_SIZE_SETTING_DEFAULT),
			create_player_2d)
			
	initialise_pool(ProjectSettings.get_setting(
			ResonatePlugin.POOL_3D_SIZE_SETTING_NAME,
			ResonatePlugin.POOL_3D_SIZE_SETTING_DEFAULT),
			create_player_3d)
	
	auto_add_events()
	
	var scene_root = get_tree().root.get_tree()
	scene_root.node_added.connect(on_scene_node_added)
	scene_root.node_removed.connect(on_scene_node_removed)
	

func _process(_p_delta) -> void:
	if _event_table_hash != _event_table.hash():
		banks_updated.emit()
		_event_table_hash = _event_table.hash()
		
	if has_loaded:
		return
		
	has_loaded = true
	loaded.emit()


func on_scene_node_added(p_node: Node) -> void:
	if not p_node is SoundBank:
		return
		
	add_bank(p_node)
	
	
func on_scene_node_removed(p_node: Node) -> void:
	if not p_node is SoundBank:
		return
		
	remove_bank(p_node)


func initialise_pool(p_size: int, p_creator_fn: Callable) -> void:
	for i in p_size:
		p_creator_fn.call_deferred()


func auto_add_events() -> void:
	var sound_banks = ResonateUtils.find_all_nodes(self, "SoundBank")
	
	for sound_bank in sound_banks:
		add_bank(sound_bank)
		
	_event_table_hash = _event_table.hash()
		

func add_bank(p_bank: SoundBank) -> void:
	_event_table[p_bank.label] = {
		"name": p_bank.label,
		"bus": p_bank.bus,
		"mode": p_bank.mode,
		"events": create_events(p_bank.events)
	}
	

func remove_bank(p_bank: SoundBank) -> void:
	_event_table.erase(p_bank.label)
	

func create_events(p_events: Array[SoundEventResource]) -> Dictionary:
	var events = {}
	
	for event in p_events:
		events[event.name] = {
			"name": event.name,
			"bus": event.bus,
			"streams": event.streams,
		}
		
	return events


func get_bus(p_bank_bus: String, p_event_bus: String) -> String:
	if p_event_bus != null and p_event_bus != "":
		return p_event_bus
	
	if p_bank_bus != null and p_bank_bus != "":
		return p_bank_bus
		
	return ProjectSettings.get_setting(
		ResonatePlugin.SOUND_BANK_SETTING_NAME,
		ResonatePlugin.SOUND_BANK_SETTING_DEFAULT)


func instance_manual(p_bank_label: String, p_event_name: String, p_reserved: bool = false, p_bus: String = "", p_poly: bool = false, p_attachment = null) -> Variant:
	if not has_loaded:
		push_error("Resonate - The event [%s] on bank [%s] can't be instanced as the SoundManager has not loaded yet. Use the [loaded] signal/event to determine when it is ready." % [p_event_name, p_bank_label])
		return null
		
	if not _event_table.has(p_bank_label):
		push_error("Resonate - Tried to instance the event [%s] from an unknown bank [%s]." % [p_event_name, p_bank_label])
		return null
		
	if not _event_table[p_bank_label]["events"].has(p_event_name):
		push_error("Resonate - Tried to instance an unknown event [%s] from the bank [%s]." % [p_event_name, p_bank_label])
		return null
	
	var bank = _event_table[p_bank_label] as Dictionary
	var event = bank["events"][p_event_name] as Dictionary
	
	if event.streams.size() == 0:
		push_error("Resonate - The music track [%s] on bank [%s] has no stems, you'll need to add one at minimum." % [p_event_name, p_bank_label])
		return
		
	var player = get_player(p_attachment)
	
	if event.streams.size() == 0 or player == null:
		push_error("Resonate - The event [%s] on bank [%s] can't be played; no streams or players available." % [p_event_name, p_bank_label])
		return null
	
	if is_vector_attachment(p_attachment):
		player.global_position = p_attachment
		
	if is_node_attachment(p_attachment):
		player.global_position = p_attachment.global_position
		player.reparent(p_attachment)
		
	var bus = p_bus if p_bus != "" else get_bus(bank.bus, event.bus)
	
	player.configure(event.streams, p_reserved, bus, p_poly, bank.mode)
	
	if not p_reserved:
		player.trigger()
		
	return player


func play(p_bank_label: String, p_event_name: String, p_bus: String = "") -> void:
	instance_manual(p_bank_label, p_event_name, false, p_bus, false, null)
	

func play_at_position(p_bank_label: String, p_event_name: String, p_position, p_bus: String = "") -> void:
	instance_manual(p_bank_label, p_event_name, false, p_bus, false, p_position)
	

func play_on_node(p_bank_label: String, p_event_name: String, p_node, p_bus: String = "") -> void:
	instance_manual(p_bank_label, p_event_name, false, p_bus, false, p_node)


func instance(p_bank_label: String, p_event_name: String, p_bus: String = "") -> Variant:
	return instance_manual(p_bank_label, p_event_name, true, p_bus, false, null)
	

func instance_at_position(p_bank_label: String, p_event_name: String, p_position, p_bus: String = "") -> Variant:
	return instance_manual(p_bank_label, p_event_name, true, p_bus, false, p_position)
	

func instance_on_node(p_bank_label: String, p_event_name: String, p_node, p_bus: String = "") -> Variant:
	return instance_manual(p_bank_label, p_event_name, true, p_bus, false, p_node)
	
	
func instance_poly(p_bank_label: String, p_event_name: String, p_bus: String = "") -> Variant:
	return instance_manual(p_bank_label, p_event_name, true, p_bus, true, null)
	

func instance_at_position_poly(p_bank_label: String, p_event_name: String, p_position, p_bus: String = "") -> Variant:
	return instance_manual(p_bank_label, p_event_name, true, p_bus, true, p_position)
	

func instance_on_node_poly(p_bank_label: String, p_event_name: String, p_node, p_bus: String = "") -> Variant:
	return instance_manual(p_bank_label, p_event_name, true, p_bus, true, p_node)


func is_player_free(p_player) -> bool:
	return not p_player.playing and not p_player.reserved


func get_player_from_pool(p_pool: Array) -> Variant:
	if p_pool.size() == 0:
		push_error("Resonate - Player pool has not been initialised. This can occur when calling a [play/instance*] function from [_ready].")
		return null
	
	for player in p_pool:
		if is_player_free(player):
			return player
	
	push_warning("Resonate - Player pool exhausted, consider increasing the pool size in the project settings (Audio/Manager/Pooling) or releasing unused audio stream players.")
	return null
	

func get_player_1d() -> PooledAudioStreamPlayer:
	return get_player_from_pool(_1d_players)
	

func get_player_2d() -> PooledAudioStreamPlayer2D:
	return get_player_from_pool(_2d_players)
	

func get_player_3d() -> PooledAudioStreamPlayer3D:
	return get_player_from_pool(_3d_players)


func get_player(p_attachment = null) -> Variant:
	if p_attachment is Vector2 or p_attachment is Node2D:
		return get_player_2d()
	
	if p_attachment is Vector3 or p_attachment is Node3D:
		return get_player_3d()
		
	return get_player_1d()


func is_vector_attachment(p_attachment = null) -> bool:
	return true if p_attachment is Vector2 or p_attachment is Vector3 else false
	

func is_node_attachment(p_attachment = null) -> bool:
	return true if p_attachment is Node2D or p_attachment is Node3D else false


func add_player_to_pool(p_player, p_pool) -> Variant:
	add_child(p_player)
	
	p_player.released.connect(on_player_released.bind(p_player))
	p_pool.append(p_player)
	
	return p_player


func create_player_1d() -> PooledAudioStreamPlayer:
	return add_player_to_pool(PooledAudioStreamPlayer.create(), _1d_players)
	

func create_player_2d() -> PooledAudioStreamPlayer2D:
	return add_player_to_pool(PooledAudioStreamPlayer2D.create(), _2d_players)
	
	
func create_player_3d() -> PooledAudioStreamPlayer3D:
	return add_player_to_pool(PooledAudioStreamPlayer3D.create(), _3d_players)


func auto_release(p_base: Node, p_instance: Node, p_finish_playing: bool = false) -> Variant:
	if p_instance == null:
		return p_instance
		
	p_base.tree_exiting.connect(on_player_reserver_exiting.bind(p_instance, p_finish_playing))
	
	return p_instance


func on_player_reserver_exiting(p_instance: Node, p_finish_playing: bool) -> void:
	p_instance.release(p_finish_playing)
	

func on_player_released(p_player: Node) -> void:
	var player_parent = p_player.get_parent()
	
	if player_parent == null or not player_parent == self:
		p_player.reparent(self)
	
