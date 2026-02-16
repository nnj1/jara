extends Node

# Configuration
var music_folder: String = "res://assets/music/Mind's Eye Pack/Pack/"
var music_player: AudioStreamPlayer

var playlist: Array[String] = []
var current_track_index: int = -1

func _ready() -> void:
	# 1. Initialize the player
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	music_player.bus = "Music" # Ensure you have a 'Music' bus in your Audio bus layout
	
	# 2. Connect the finished signal to loop through the playlist
	music_player.finished.connect(_on_track_finished)
	
	# 3. Load the tracks and start playing
	_load_music_from_folder()
	play_next()

func _load_music_from_folder() -> void:
	var dir = DirAccess.open(music_folder)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if not dir.current_is_dir():
				# Filter for audio files (supporting import-remapped files)
				if file_name.ends_with(".import"):
					file_name = file_name.replace(".import", "")
				
				if file_name.ends_with(".ogg") or file_name.ends_with(".mp3") or file_name.ends_with(".wav"):
					playlist.append(music_folder + file_name)
			
			file_name = dir.get_next()
		
		playlist.shuffle() # Optional: Randomize the order
	else:
		push_error("MusicManager: Could not open directory " + music_folder)

func play_next() -> void:
	if playlist.is_empty():
		return
		
	current_track_index = (current_track_index + 1) % playlist.size()
	var track_path = playlist[current_track_index]
	
	# Use ResourceLoader to load the stream
	var stream = ResourceLoader.load(track_path) as AudioStream
	
	if stream:
		music_player.stream = stream
		music_player.play()
		print("Now playing: ", track_path.get_file())

func _on_track_finished() -> void:
	play_next()
