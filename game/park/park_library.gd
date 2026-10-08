class_name ParkLibrary
extends RefCounted
## Every park the player has made, kept side by side so starting a new one
## never throws an old one away. Each park is three files in user://parks:
##   <id>.park  the whole park (compressed JSON, see ParkData.to_dict)
##   <id>.json  a little summary for the list (name, date, money, guests)
##   <id>.png   a picture of the park from when it was last saved

const DIR := "user://parks/"
const THUMB_SIZE := Vector2i(320, 200)

## Where the library lives; tests point it somewhere else.
static var dir := DIR


static func _path(id: String, ext: String) -> String:
	return dir.path_join(id + ext)


static func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)


## Saves a park (and its guests, when `sim` is given) with a picture.
static func save(park: ParkData, sim: ParkSim = null, thumb: Image = null) -> bool:
	_ensure_dir()
	if sim:
		sim.store()
	park.updated = int(Time.get_unix_time_from_system())
	var f := FileAccess.open_compressed(_path(park.id, ".park"), FileAccess.WRITE, FileAccess.COMPRESSION_GZIP)
	if f == null:
		push_warning("Can't save park %s: %s" % [park.id, FileAccess.get_open_error()])
		return false
	f.store_string(JSON.stringify(park.to_dict()))
	f.close()
	var meta := summary(park, sim)
	var m := FileAccess.open(_path(park.id, ".json"), FileAccess.WRITE)
	if m:
		m.store_string(JSON.stringify(meta, "\t"))
		m.close()
	if thumb:
		var img := thumb.duplicate() as Image
		img.resize(THUMB_SIZE.x, THUMB_SIZE.y, Image.INTERPOLATE_BILINEAR)
		img.save_png(_path(park.id, ".png"))
	return true


static func summary(park: ParkData, sim: ParkSim = null) -> Dictionary:
	return {
		"id": park.id,
		"name": park.name,
		"scenario": park.scenario,
		"sandbox": park.sandbox,
		"money": park.money,
		"guests": sim.guests.size() if sim else park.guests.size(),
		"rating": sim.rating if sim else -1,
		"date": park.date_text(),
		"goal_state": park.goal_state,
		"rides": park.rides.size(),
		"created": park.created,
		"updated": park.updated,
		"play_seconds": park.play_seconds,
	}


## Summaries of every saved park, most recently played first.
static func list() -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if not f.ends_with(".park"):
			continue
		var id := f.get_basename()
		var meta := _read_meta(id)
		if meta.is_empty():
			# No summary: read the park itself.
			var p := load_park(id)
			if p == null:
				continue
			meta = summary(p)
		out.append(meta)
	out.sort_custom(func(a, b): return int(a.get("updated", 0)) > int(b.get("updated", 0)))
	return out


static func _read_meta(id: String) -> Dictionary:
	if not FileAccess.file_exists(_path(id, ".json")):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(_path(id, ".json")))
	return parsed if parsed is Dictionary else {}


static func exists(id: String) -> bool:
	return FileAccess.file_exists(_path(id, ".park"))


## The saved park, or null if it's missing or can't be read.
static func load_park(id: String) -> ParkData:
	var f := FileAccess.open_compressed(_path(id, ".park"), FileAccess.READ, FileAccess.COMPRESSION_GZIP)
	if f == null:
		return null
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		return null
	return ParkData.from_dict(parsed)


static func thumbnail(id: String) -> Texture2D:
	var p := _path(id, ".png")
	if not FileAccess.file_exists(p):
		return null
	var img := Image.load_from_file(p)
	return ImageTexture.create_from_image(img) if img else null


## Saves a copy under a new name; returns the copy's id, or "".
static func copy(id: String, new_name: String) -> String:
	var p := load_park(id)
	if p == null:
		return ""
	p.id = ParkData.new_id()
	while exists(p.id):
		p.id = ParkData.new_id()
	p.name = new_name
	p.created = int(Time.get_unix_time_from_system())
	if not save(p):
		return ""
	if FileAccess.file_exists(_path(id, ".png")):
		DirAccess.copy_absolute(_path(id, ".png"), _path(p.id, ".png"))
	return p.id


static func rename(id: String, new_name: String) -> bool:
	var p := load_park(id)
	if p == null:
		return false
	p.name = new_name
	var updated := p.updated
	var ok := save(p)
	# Renaming isn't playing: keep the park's place in the list.
	var meta := _read_meta(id)
	if ok and not meta.is_empty():
		meta.updated = updated
		var m := FileAccess.open(_path(id, ".json"), FileAccess.WRITE)
		if m:
			m.store_string(JSON.stringify(meta, "\t"))
	return ok


static func delete(id: String) -> void:
	for ext in [".park", ".json", ".png"]:
		if FileAccess.file_exists(_path(id, ext)):
			DirAccess.remove_absolute(_path(id, ext))


## `base`, or `base 2`, `base 3`... whichever no saved park uses yet.
static func unique_name(base: String) -> String:
	var used := {}
	for m in list():
		used[str(m.name)] = true
	if not used.has(base):
		return base
	var n := 2
	while used.has("%s %d" % [base, n]):
		n += 1
	return "%s %d" % [base, n]
