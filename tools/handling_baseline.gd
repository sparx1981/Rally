extends Node
## Compare drive layouts using identical tyres, gearing and power on the same stage.
func _ready() -> void:
	for index in [0,28]:
		var stage := Stage.new()
		add_child(stage)
		stage.build(Catalog.stages()[index])
		for drive in ["fwd","rwd","awd"]:
			for turn: bool in [false,true]:
				var stats: Dictionary = Catalog.cars()[0].duplicate(true)
				stats.drive = drive
				var car := Car.new()
				car.is_player = true
				add_child(car)
				car.setup(stats,1,stage,stage.paper_mat)
				car.place_at(stage.track.start_s,0)
				car.frozen = false
				car.throttle = 1
				if turn:
					car.vel = car.fwd()*14.0
					car.steer = 0.45
				var initial := car.h
				var peak := 0.0
				for tick in (72 if turn else 180):
					car.step(Race.FIXED)
					peak = maxf(peak,car.slip)
				print("%s %s %s speed %.2f m/s, yaw %.1f deg, peak slip %.3f" % [
					stage.def.name,drive,"corner" if turn else "launch",car.speed(),rad_to_deg(absf(car.h-initial)),peak])
				car.free()
		stage.free()
	get_tree().quit()
