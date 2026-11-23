extends SceneTree
## Pre-generates every stage's road layout into res://data/tracks so phones never run the search.
## Run: godot --headless --script res://tools/pregen_tracks.gd

func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://data/tracks")
	var keep := {}
	for def in Catalog.stages():
		var L := float(def["length"]) + Track.POST_FINISH
		var key := Track.cache_key(int(def["seed"]), L, float(def["twist"]))
		keep[key + ".bin"] = true
		var path := "res://data/tracks/%s.bin" % key
		if FileAccess.file_exists(path):
			continue
		var t := Track.new()
		t.width = float(def["width"])
		var t0 := Time.get_ticks_msec()
		t._generate_fresh(int(def["seed"]), L, float(def["twist"]))
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_buffer(var_to_bytes(t.pts))
		print("%s  %.0f m  %d ms" % [def["id"], t.length, Time.get_ticks_msec() - t0])
	for fn in DirAccess.get_files_at("res://data/tracks"):
		if fn.ends_with(".bin") and not keep.has(fn):
			DirAccess.remove_absolute("res://data/tracks/" + fn)
	quit()
