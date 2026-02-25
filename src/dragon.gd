extends DumbNPC

func _ready() -> void:
	super._ready()
	can_jump = false

func safe_play(anim_name: String):
	var n = anim_name
	if anim_player.has_animation(n):
		if anim_player.current_animation != n:
			anim_player.play(n, 0.2)
	
