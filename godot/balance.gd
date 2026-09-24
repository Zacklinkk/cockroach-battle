extends RefCounted
const CAMPAIGN_ROOMS = 5
# World distances are game units, not metres or literal biological measurements.
static func room_stats(number: int) -> Dictionary:
	var n = maxi(0,number-1)
	return {
		"health":64.0*(1.0+0.44*n+0.04*n*n),
		"mother_health":720.0*(1.0+0.42*n+0.03*n*n),
		"part_scale":0.95+0.24*n+0.018*n*n,
		"armor":minf(0.32,n*0.05),
		"control_resist":minf(0.45,n*0.075),
		"sight":minf(11.5,5.8+n*1.1),
		"chase_speed":minf(2.85,1.42+n*0.23),
		"dash_speed":minf(8.0,4.3+n*0.45),
		"near_count":mini(13,3+n*2),
		"far_count":mini(60,18+n*6),
		"far_distance":17.0 if n==0 else 11.5,
		"population_cap":mini(84,44+n*8),
		"spawn_interval":maxf(4.0,12.0-n*1.3),
		"spawn_batch":mini(3,1+int(n/2)),
		"dash_slots":mini(3,1+int(n/2)),
		"dash_grace":25.0 if n==0 else 5.0,
		"dash_windup":maxf(0.42,0.68-n*0.065),
		"noise_scale":minf(1.0,0.43+n*0.16),
		"rally_radius":minf(5.0,2.4+n*0.65)
	}

static func noise_radius(weapon: String) -> float:
	return float({"wand":10.0,"spray":8.5,"slipper":13.0,"staple":11.0,"chainsaw":16.0,"zapper":13.0,"slingshot":10.5,"vacuum":14.0}.get(weapon,10.0))

static func leg_mobility(lost: int) -> float:
	return maxf(0.35,1.0-0.10*lost)
