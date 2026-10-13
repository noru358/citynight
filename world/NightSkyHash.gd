class_name NightSkyHash
# Stable 0..1 noise from two integers, shared by the sky and the buildings.
static func h(a: int, b: int) -> float:
	var x: int = (a*73856093) ^ (b*19349663)
	x = (x ^ (x >> 13))*1274126177
	return float(absi(x) % 10007)/10007.0
