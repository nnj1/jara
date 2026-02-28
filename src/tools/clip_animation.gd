@tool
extends Node

## Drag your long .anim file here
@export var source_animation: Animation
## The start time of the segment (in seconds)
@export var start_time: float = 0.0
## The end time of the segment (in seconds)
@export var end_time: float = 1.0
## Where to save the new file (e.g., "res://animations/walk.anim")
@export var save_path: String = "res://new_animation.anim"

## Click this checkbox in the Inspector to run the script
@export var run_process: bool = false:
	set(value):
		if value and source_animation:
			trim_and_save()
		run_process = false

func trim_and_save():
	var new_anim = Animation.new()
	var duration = end_time - start_time
	
	if duration <= 0:
		push_error("End time must be greater than start time.")
		return

	# Copy tracks from source to new animation
	for track_idx in source_animation.get_track_count():
		var new_track_idx = new_anim.add_track(source_animation.track_get_type(track_idx))
		new_anim.track_set_path(new_track_idx, source_animation.track_get_path(track_idx))
		
		# Iterate through keys in the source track
		for key_idx in source_animation.track_get_key_count(track_idx):
			var key_time = source_animation.track_get_key_time(track_idx, key_idx)
			
			# Only keep keys within our window
			if key_time >= start_time and key_time <= end_time:
				var key_value = source_animation.track_get_key_value(track_idx, key_idx)
				var transition = source_animation.track_get_key_transition(track_idx, key_idx)
				
				# Shift the time so it starts at 0.0
				new_anim.track_insert_key(new_track_idx, key_time - start_time, key_value, transition)

	new_anim.length = duration
	
	var error = ResourceSaver.save(new_anim, save_path)
	if error == OK:
		print("Successfully saved trimmed animation to: ", save_path)
	else:
		print("Error saving animation: ", error)
