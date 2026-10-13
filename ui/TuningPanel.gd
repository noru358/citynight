# Tab: every movement number as a slider. Changes apply at once; the button saves
# them to data/movement_tuning.json (works when run from the project folder).
extends PanelContainer
var stage: Node2D

func _ready() -> void:
	custom_minimum_size = Vector2(620,600)
	var scroll: ScrollContainer = ScrollContainer.new()
	add_child(scroll)
	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size.x = 580
	scroll.add_child(column)
	var save: Button = Button.new()
	save.text = "수치 저장 (data/movement_tuning.json)"
	save.focus_mode = Control.FOCUS_NONE
	save.pressed.connect(func() -> void:
		var file: FileAccess = FileAccess.open(stage.tuning_path,FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(stage.tuning,"  ")+"\n")
			save.text = "저장 완료"
		else: save.text = "저장 실패: 쓰기 권한 확인")
	column.add_child(save)
	for key: String in stage.schema:
		var label: Label = Label.new()
		label.text = "%s: %s" % [key,stage.tuning[key]]
		column.add_child(label)
		var slider: HSlider = HSlider.new()
		slider.min_value = stage.schema[key].min
		slider.max_value = stage.schema[key].max
		slider.step = stage.schema[key].step
		slider.value = stage.tuning[key]
		slider.focus_mode = Control.FOCUS_NONE
		slider.value_changed.connect(func(value: float) -> void:
			stage.tuning[key] = value
			label.text = "%s: %.3f" % [key,value]
			if key in ["player_width","player_height"]: stage.hero.set_body_size(Vector2(stage.tuning.player_width,stage.tuning.player_height)))
		column.add_child(slider)
