extends Node3D

@export var segments := 5
var newest_rope
func _ready() -> void:
	for i in range(segments):
		newest_rope = get_child(i)
		if not newest_rope or newest_rope is not RigidBody3D: continue
		var new = newest_rope.duplicate()
		add_child(new, true)
		new.position.y -= 0.3
		var pin
		for p in new.get_children():
			if p is PinJoint3D: pin = p
		pin.node_a = newest_rope.get_path()
		pin.node_b = new.get_path()
