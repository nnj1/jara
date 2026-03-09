extends Control

@export var character_width = 100
@export var north_vector = Vector3(0, 0 , -1)
@onready var facing_direction = north_vector : set = _update_label_text

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_update_label_text(north_vector)

func _update_label_text(given_facing_direction: Vector3):
	var string = _create_repeated_string(" ", character_width)
	var angle = north_vector.signed_angle_to(given_facing_direction, Vector3.UP)
	var percent_deviation = angle / (PI/2)
	var middle_char_index = int(character_width/2.0)
	
	# if deviation is 50%, N marker should move to the end of the string
	var north_marker_index = middle_char_index + int((character_width - 1)/2.0 * percent_deviation)
	var east_marker_index = north_marker_index + int((character_width - 1)/2.0)
	var west_marker_index = north_marker_index - int((character_width - 1)/2.0)
	var south_marker_index = north_marker_index + int((character_width - 1))
	
	if (north_marker_index > 0) and (north_marker_index < character_width):
		string[north_marker_index] = 'N'
	if (east_marker_index > 0) and (east_marker_index < character_width):
		string[east_marker_index] = 'E'
	if (west_marker_index > 0) and (west_marker_index < character_width):
		string[west_marker_index] = 'W'
	if (south_marker_index > 0) and (south_marker_index < character_width):
		string[south_marker_index] = 'S'
		
	$Label.text = string

func _create_repeated_string(given_char: String, times: int) -> String:
	var result: String = ""
	for i in range(times):
		result += given_char
	return result
