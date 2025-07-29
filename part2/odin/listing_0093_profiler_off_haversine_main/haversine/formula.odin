package haversine

import "core:math"

radians_from_degree :: proc(degrees: f64) -> f64 {
	return 0.01745329251994329577 * degrees
}

reference_haversine :: proc(x0: f64, y0: f64, x1: f64, y1: f64, earth_radius: f64) -> f64 {
	lat1: f64 = y0
	lat2: f64 = y1
	lon1 := x0
	lon2 := x1

	dlat := radians_from_degree(lat2 - lat1)
	dlon := radians_from_degree(lon2 - lon1)
	lat1 = radians_from_degree(lat1)
	lat2 = radians_from_degree(lat2)

	a :=
		math.pow(math.sin(dlat / 2.0), 2) +
		math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dlon / 2), 2)
	c := 2 * math.asin(math.sqrt(a))

	return earth_radius * c
}
