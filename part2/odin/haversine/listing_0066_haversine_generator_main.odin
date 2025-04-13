package haversine

import "core:fmt"
import "core:os"
import "core:slice"
import "core:strconv"
import "core:strings"

Ranctx :: struct {
	a: u64,
	b: u64,
	c: u64,
	d: u64,
}

Config :: struct {
	generate:    bool,
	cluster:     bool,
	seed:        u64,
	data_amount: u64,
}

U64MAX :: max(u64)

seed :: proc(value: u64) -> Ranctx {
	x := Ranctx {
		a = 0xf1ea5eed,
		b = value,
		c = value,
		d = value,
	}

	for _ in 0 ..< 20 {
		_ = rand_value(&x)
	}

	return x
}

rotate :: proc(v: u64, shift: u64) -> u64 {
	return (v) << shift | (v) >> (64 - shift)
}

rand_value :: proc(x: ^Ranctx) -> u64 {
	e := x.a - rotate(x.b, 27)
	x.a = x.b ~ rotate(x.c, 17)
	x.b = x.c + x.d
	x.c = x.d + e
	x.d = x.a + e

	return x.d
}

random_in_range :: proc(series: ^Ranctx, min: f64, maximum: f64) -> f64 {
	t := f64(rand_value(series)) / f64(U64MAX)
	return (1.0 - t) * min + t * maximum
}

random_degree :: proc(series: ^Ranctx, center: f64, radius: f64, max_allowed: f64) -> f64 {
	minVal: f64 = center - radius
	if minVal < -max_allowed {
		minVal = -max_allowed
	}

	maxVal: f64 = center + radius
	if maxVal > max_allowed {
		maxVal = max_allowed
	}

	result: f64 = random_in_range(series, minVal, maxVal)
	return result
}

process_args :: proc() -> Config {
	config: Config
	argc: int = len(os.args)
	ok: bool

	for i := 1; i < argc; i += 1 {
		switch (os.args[i]) {
		case "--generate":
			config.generate = true
		case "--cluster":
			config.cluster = true
		case "--seed":
			next: string
			if i + 1 < argc {
				next = os.args[i + 1]
				i += 1
			} else {
			}

			config.seed, ok = strconv.parse_u64(next)
			assert(ok, "Only numeric please")
		case "--amount":
			next: string
			if i + 1 < argc {
				next = os.args[i + 1]
				i += 1
			} else {
			}

			config.data_amount, ok = strconv.parse_u64(next)
			assert(ok, "Only numeric please")
		case:
			fmt.println(os.args[i])
			fmt.println(
				`Usage
			--generate -- for data.json generation
			--seed <number> -- for seed
			--amount <number> -- for amount of pairs of in data.json 
			`,
			)
		}
	}

	return config
}

EARTH_RADIUS :: 6372.8

main :: proc() {
	// config := process_args()
	config: Config = {
		cluster     = true,
		generate    = true,
		seed        = 1,
		data_amount = 1,
	}
	fmt.println(config)

	cluster_count_left: u64 = U64MAX

	MAX_ALLOWED_X :: 180
	MAX_ALLOWED_Y :: 90
	MAX_PAIR_COUNT :: (1 << 34)

	CLUSTER_COUNT_MAX := 1 + (config.data_amount / 64)

	if (config.cluster) {
		cluster_count_left = 0
	} else {
		fmt.println("WARNING: Unregcognized method name. Using 'uniform'")
	}

	xCenter: f64 = 0
	yCenter: f64 = 0
	xRadius: f64 = MAX_ALLOWED_X
	yRadius: f64 = MAX_ALLOWED_Y

	sum: f64
	series := seed(config.seed)

	handle, err := os.open(
		"data.json",
		os.O_WRONLY | os.O_CREATE,
		os.S_IRUSR | os.S_IWUSR | os.S_IRGRP | os.S_IROTH,
	)
	defer os.close(handle)
	assert(err == nil, os.error_string(err))

	haversine_handle: os.Handle
	haversine_handle, err = os.open(
		"haversine.f64",
		os.O_WRONLY | os.O_CREATE,
		os.S_IRUSR | os.S_IWUSR | os.S_IRGRP | os.S_IROTH,
	)
	defer os.close(haversine_handle)

	assert(err == nil, os.error_string(err))

	_, err = os.write_string(handle, `{
	"pairs":
		[
			`)
	assert(err == nil, os.error_string(err))

	for i in 0 ..< config.data_amount {
		if (cluster_count_left == 0) {
			cluster_count_left = CLUSTER_COUNT_MAX
			xCenter = random_in_range(&series, -MAX_ALLOWED_X, MAX_ALLOWED_X)
			yCenter = random_in_range(&series, -MAX_ALLOWED_Y, MAX_ALLOWED_Y)
			xRadius = random_in_range(&series, 0, MAX_ALLOWED_X)
			yRadius = random_in_range(&series, 0, MAX_ALLOWED_Y)
		}

		cluster_count_left -= 1

		x1 := random_degree(&series, xCenter, xRadius, MAX_ALLOWED_X)
		y1 := random_degree(&series, yCenter, yRadius, MAX_ALLOWED_Y)
		x2 := random_degree(&series, xCenter, xRadius, MAX_ALLOWED_X)
		y2 := random_degree(&series, yCenter, yRadius, MAX_ALLOWED_Y)

		entry := fmt.aprintf(
			`{{"x0": %.16f, "y0": %.16f, "x1": %.16f, "y1": %.16f}}`,
			x1,
			y1,
			x2,
			y2,
		)
		defer delete(entry)
		fmt.println(entry)

		_, err = os.write_string(handle, entry)
		assert(err == nil, os.error_string(err))

		if (i != config.data_amount - 1) {
			_, err = os.write_string(handle, ",\n")
			assert(err == nil, os.error_string(err))
		}

		haversine := reference_haversine(x1, y1, x2, y2, EARTH_RADIUS)
		data := slice.to_bytes(slice.from_ptr(&haversine, 1))
		_, err = os.write(haversine_handle, data)
		assert(err == nil, os.error_string(err))

		sum += haversine
	}

	_, err = os.write_string(handle, `
		]
}`)
	assert(err == nil, os.error_string(err))

	data := slice.to_bytes(slice.from_ptr(&sum, 1))
	_, err = os.write(haversine_handle, data)
	assert(err == nil, os.error_string(err))

	fmt.printfln("average haversine %f", sum / f64(config.data_amount))
}
