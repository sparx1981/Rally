extends Node
## Compare drive layouts using identical tyres, gearing and power on the same stage.
var trace: FileAccess
var failed := false

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--trace="):
			trace = FileAccess.open(argument.trim_prefix("--trace="),FileAccess.WRITE)
			if trace == null:
				push_error("Cannot open handling trace")
				get_tree().quit(1)
				return
			trace.store_csv_line(["stage","drive","corner","tick","throttle","brake","steer","handbrake","wheel_load_FR_FL_RR_RL","wheel_grip_FR_FL_RR_RL","axle_demand_F_R","axle_delivered_F_R","axle_slip_F_R","lateral_capacity_F_R"])
	for index in [0,28]:
		var stage := Stage.new()
		add_child(stage)
		stage.build(Catalog.stages()[index])
		var launches := {}
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
					if trace:
						trace.store_csv_line([stage.def.name, drive, turn, tick, car.throttle, car.brake, car.steer, car.handbrake, str(car.wheel_load), str(car.wheel_grip), str(car.axle_demand), str(car.longitudinal_force), str(car.axle_slip), str(car.lateral_capacity)])
					if not car.vel.is_finite() or not car.longitudinal_force.is_finite():
						failed = true
					peak = maxf(peak,car.slip)
				print("%s %s %s speed %.2f m/s, yaw %.1f deg, peak slip %.3f" % [
					stage.def.name,drive,"corner" if turn else "launch",car.speed(),rad_to_deg(absf(car.h-initial)),peak])
				if not turn:
					launches[drive] = car.speed()
					if drive == "fwd" and index == 0:
						_check_split_grip(car)
				car.free()
		if index == 28 and launches.awd <= maxf(launches.rwd, launches.fwd):
			failed = true
			push_error("AWD failed the equal-spec traction-limited launch")
		stage.free()
	get_tree().quit(1 if failed else 0)

## Isolate differential torque bias on an axle straddling a low-grip strip.
func _check_split_grip(car: Car) -> void:
	car.wheel_load.fill(0.25)
	car.wheel_grip.fill(1.0)
	car.wheel_grip[0] = 0.12
	car.stats.differential_bias = 1.0
	car._axle_forces(0.0,1.0,0.0,0.0,Race.FIXED)
	var open_force := car.longitudinal_force.x
	car.stats.differential_bias = 2.5
	car._axle_forces(0.0,1.0,0.0,0.0,Race.FIXED)
	var biased := car.longitudinal_force.x
	var yaw := car.traction_yaw
	car.wheel_grip[0] = 1.0
	car.wheel_grip[1] = 0.12
	car._axle_forces(0.0,1.0,0.0,0.0,Race.FIXED)
	if biased <= open_force or not is_equal_approx(yaw,-car.traction_yaw) or car.longitudinal_force.y != 0.0:
		push_error("Split-grip differential transfer or mirrored wheel response failed")
		failed = true
	car.wheel_load.fill(0.0)
	car._axle_forces(0.0,1.0,0.0,0.0,Race.FIXED)
	if car.longitudinal_force.length_squared() > 0.0:
		push_error("Unsupported wheels delivered tractive force")
		failed = true
