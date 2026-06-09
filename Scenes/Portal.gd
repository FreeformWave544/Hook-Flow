extends CSGBox3D

## The scene to load when the player enters the portal.
@export_file("*.tscn") var next_level

@onready var player_spawner: Node3D = $PlayerSpawner

# When the player enters the portal, change the scene to the next level.
func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is Player:
		UserInterface.change_scene(next_level, player_spawner.global_transform)
