# Music that follows the scene. A track is a folder audio/<track>/ with stem files
# (e.g. base.ogg, drums.ogg, lead.ogg) that start together and loop; beats fade
# stems in and out. Missing folders or files are reported once and skipped, so the
# game runs before any music exists.
extends Node
var players: Dictionary = {}
var current: String = ""
var missing: Dictionary = {}

func play(track: String, stems_on: Array = []) -> void:
	if track == current: return
	stop()
	current = track
	var folder: String = "res://audio/"+track
	if track.is_empty() or not DirAccess.dir_exists_absolute(folder):
		_note_missing(folder)
		return
	for file: String in DirAccess.get_files_at(folder):
		if not (file.ends_with(".ogg") or file.ends_with(".wav") or file.ends_with(".mp3")): continue
		var stream: AudioStream = load(folder+"/"+file)
		if stream == null: continue
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.stream = stream
		player.volume_db = 0.0 if (stems_on.is_empty() or file.get_basename() in stems_on) else -80.0
		add_child(player)
		players[file.get_basename()] = player
	for player: AudioStreamPlayer in players.values(): player.play()

func stem(name: String, on: bool, seconds: float = 1.5) -> void:
	if not players.has(name):
		_note_missing("stem "+current+"/"+name)
		return
	var tween: Tween = create_tween()
	tween.tween_property(players[name],"volume_db",0.0 if on else -80.0,seconds)

func fade_all(seconds: float) -> void:
	for player: AudioStreamPlayer in players.values():
		create_tween().tween_property(player,"volume_db",-80.0,seconds)

func stop() -> void:
	for player: AudioStreamPlayer in players.values(): player.queue_free()
	players.clear()
	current = ""

func _note_missing(what: String) -> void:
	if missing.has(what): return
	missing[what] = true
	print("MUSIC_MISSING ",what)
