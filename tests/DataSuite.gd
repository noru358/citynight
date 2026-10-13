# Fail-closed loading: a good chapter loads; broken ones refuse with a reason.
extends Node
var failures: int = 0

func _ready() -> void:
	var dir: String = OS.get_environment("CITYNIGHT_TEST_DIR")
	if dir.is_empty(): dir = OS.get_user_data_dir()
	_check("good", "res://data/chapters/ch00.json", true, "")
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapters/ch00.json"))
	var map: String = FileAccess.get_file_as_string("res://maps/ch00_rooftops.txt")
	_write(dir+"/ok.txt",map)
	var missing_beat: Dictionary = base.duplicate(true)
	missing_beat.beats.erase("2")
	missing_beat.map = "ok.txt"
	_write(dir+"/missing_beat.json",JSON.stringify(missing_beat))
	_check("beat in map but not in chapter", dir+"/missing_beat.json", false, "비트 2")
	var extra_beat: Dictionary = base.duplicate(true)
	extra_beat.beats["9"] = {"caption":"x"}
	extra_beat.map = "ok.txt"
	_write(dir+"/extra_beat.json",JSON.stringify(extra_beat))
	_check("beat in chapter but not in map", dir+"/extra_beat.json", false, "비트 9")
	_write(dir+"/no_end.txt",map.replace("E","."))
	var no_end: Dictionary = base.duplicate(true)
	no_end.map = "no_end.txt"
	_write(dir+"/no_end.json",JSON.stringify(no_end))
	_check("no ending spot", dir+"/no_end.json", false, "E 없음")
	print("RESULT data failures=%d" % failures)
	get_tree().quit(failures)

func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path,FileAccess.WRITE)
	file.store_string(text)

func _check(name: String, path: String, should_load: bool, needle: String) -> void:
	var stage: Node2D = load("res://world/stage.tscn").instantiate()
	stage.chapter_path = path
	add_child(stage)
	var loaded: bool = stage.errors.is_empty()
	var ok: bool = loaded == should_load and (needle.is_empty() or "\n".join(stage.errors).contains(needle))
	if not ok:
		failures += 1
		print("FAIL: %s loaded=%s errors=%s" % [name,loaded,stage.errors])
	else: print("ok: "+name)
	stage.free()
