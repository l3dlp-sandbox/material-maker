extends "res://material_maker/widgets/option_edit/option_edit.gd"
class_name SizeOptionButton

@export var min_size : int = 4: set = set_min_size
@export var max_size : int = 13: set = set_max_size
@export var size_value : int = 10: set = set_size_value

signal size_value_changed(s)

func _ready() -> void:
	super()
	theme_type_variation = "MM_NodeOptionEdit"
	connect("item_selected", Callable(self, "_on_item_selected"))
	update_options()

func set_min_size(m : int) -> void:
	min_size = m
	update_options()

func set_max_size(m : int) -> void:
	max_size = m
	update_options()

func set_size_value(v : int) -> void:
	size_value = v
	update_options()

func update_options() -> void:
	clear()
	for i in range(min_size, max_size+1):
		var s = pow(2, i)
		add_item("%d×%d" % [ s, s ])
	selected = size_value-min_size

func _on_item_selected(id : int) -> void:
	size_value = id + min_size
	emit_signal("size_value_changed", size_value)
