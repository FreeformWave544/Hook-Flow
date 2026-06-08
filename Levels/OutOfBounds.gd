extends Area3D

# When the player enters the world boundary restart the level.
func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		UserInterface.restart_current_scene()
