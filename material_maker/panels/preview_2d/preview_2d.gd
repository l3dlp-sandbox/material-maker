extends ColorRect

@export_multiline var shader_context_defs : String = "" # (String, MULTILINE)
@export_multiline var shader : String = "" # (String, MULTILINE)

var generator : MMGenBase = null
var output : int = 0
var is_greyscale : bool = false

var need_generate : bool = false

var last_export_filename : String = ""
var last_export_size = 4


signal generator_changed


func _enter_tree():
	set_generator(generator, output, true)

func generate_preview_shader(source, template) -> String:
	return MMGenBase.generate_preview_shader(source, source.output_type, template)

func do_update_material(source, target_material : ShaderMaterial, template : String):
	if source.output_type == "":
		return
	is_greyscale = source.output_type == "f"
	# Update shader
	if template.find("TIME") != -1:
		print("Template has time") # This should not happen
	var code = generate_preview_shader(source, template)
	mm_deps.create_buffer("preview_"+str(get_instance_id()), self)
	await mm_deps.buffer_create_shader_material("preview_"+str(get_instance_id()), MMShaderMaterial.new(target_material), code)
	for u in source.uniforms:
		if u.value:
			if u.value is MMTexture:
				target_material.set_shader_parameter(u.name, await u.value.get_texture())
			else:
				target_material.set_shader_parameter(u.name, u.value)
	# Make sure position/size parameters are setup
	on_resized()

func update_material(source):
	do_update_material(source, material, shader_context_defs+get_shader_custom_functions()+shader)

func get_shader_custom_functions():
	return ""

func set_generator(g : MMGenBase, o : int = 0, force : bool = false) -> void:
	if !is_visible_in_tree():
		generator = g
		output = o
		need_generate = true
		return
	if !force and generator == g and output == o:
		return
	need_generate = false
	if is_instance_valid(generator) and generator.is_connected("parameter_changed",Callable(self,"on_parameter_changed")):
		generator.disconnect("parameter_changed",Callable(self,"on_parameter_changed"))
	var source = MMGenBase.get_default_generated_shader()
	if is_instance_valid(g):
		generator = g
		output = o
		generator.connect("parameter_changed",Callable(self,"on_parameter_changed"))
		var gen_output_defs = generator.get_output_defs()
		if ! gen_output_defs.is_empty():
			var context : MMGenContext = MMGenContext.new()
			source = generator.get_shader_code("uv", output, context)
			if source.output_type == "":
				source = MMGenBase.get_default_generated_shader()
	else:
		generator = null

	generator_changed.emit()
	update_material(source)

var refreshing_generator : bool = false
func on_parameter_changed(n : String, v) -> void:
	if n == "__output_changed__" and output == v:
		if ! refreshing_generator and is_inside_tree():
			refreshing_generator = true
			await get_tree().process_frame
			set_generator(generator, output, true)
			refreshing_generator = false
		return
	var p = generator.get_parameter_def(n)
	if p.has("type"):
		match p.type:
			"float", "color", "gradient":
				pass
			_:
				set_generator(generator, output, true)

func set_preview_shader_parameter(parameter_name, value):
	material.set_shader_parameter(parameter_name, value)

func on_dep_update_value(_buffer_name, parameter_name, value) -> bool:
	if value is MMTexture:
		value = await value.get_texture()
	set_preview_shader_parameter(parameter_name, value)
	return false


func on_resized() -> void:
	material.set_shader_parameter("preview_2d_size", size)


func export_animation() -> void:
	if generator == null:
		return
	var window = load("res://material_maker/windows/export_animation/export_animation.tscn").instantiate()
	mm_globals.main_window.add_dialog(window)
	window.set_source(generator, output)
	window.exclusive = true
	window.hide()
	window.popup_centered()#e(get_window(), Rect2(get_window().size())


func export_taa() -> void:
	if generator == null:
		return
	var window = load("res://material_maker/windows/export_taa/export_taa.tscn").instantiate()
	mm_globals.main_window.add_dialog(window)
	window.set_source(generator, output)
	window.hide()
	window.popup_centered()


func create_image(_renderer_function : String, _params : Array, image_size : Vector2i) -> void:
	if generator != null:
		var _texture : MMTexture = await generator.render_output_to_texture(output, image_size)


func export_as_image_file(file_name : String, image_size : Vector2i) -> void:
	mm_globals.config.set_value("path", "save_preview", file_name.get_base_dir())
	if generator != null:
		var texture : MMTexture = await generator.render_output_to_texture(output, image_size)
		await texture.save_to_file(file_name)
	last_export_filename = file_name
	last_export_size = image_size


func export_to_reference(image_size : Vector2i):
	if generator != null:
		var texture : MMTexture = await generator.render_output_to_texture(output, image_size)
		mm_globals.main_window.get_panel("Reference").add_reference(await texture.get_texture())


func _on_Preview2D_visibility_changed():
	if need_generate and is_visible_in_tree():
		set_generator(generator, output, true)
