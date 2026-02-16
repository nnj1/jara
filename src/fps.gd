extends Label

@export var target_fps: int = 60
@export var warning_fps: int = 30

func _process(_delta: float) -> void:
	var fps = Engine.get_frames_per_second()
	text = "FPS: %d" % fps
	
	# Adjust color based on performance thresholds
	if fps >= target_fps:
		add_theme_color_override("font_color", Color.GREEN)
	elif fps >= warning_fps:
		add_theme_color_override("font_color", Color.YELLOW)
	else:
		add_theme_color_override("font_color", Color.RED)
