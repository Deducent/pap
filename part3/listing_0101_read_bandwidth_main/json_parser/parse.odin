package json_parser

import p "../profiler"
import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"

Type :: enum {
	OBJECT,
	LIST,
	STRING,
	NUMBER,
	BOOLEAN,
	NULL_TYPE,
}

Json_object :: map[string]Json_value
Json_list :: [dynamic]Json_value
NULL :: struct {}

Json_value :: union {
	string,
	f64,
	u64,
	bool,
	Json_object,
	Json_list,
	NULL,
}


Symbols :: enum {
	CURLY_OPEN,
	CURLY_CLOSE,
	COLON,
	STRING,
	NUMBER,
	ARRAY_OPEN,
	ARRAY_CLOSE,
	COMMA,
	BOOLEAN,
	NULL_TYPE,
}

to_string :: proc() {

}

parse_list :: proc(tokens: []Token, token_index: int) -> (int, Json_list) {
	p.time_function(byte_count = len(tokens) * size_of(Token))
	defer p.time_function_end()
	i := token_index
	list: Json_list
	value: Json_value
	token: Token
	ok: bool

	loop: for {
		i += 1
		token := tokens[i]

		#partial switch (token.type) {
		case .STRING:
			value = token.value
		case .NUMBER:
			value, ok = strconv.parse_f64(token.value)
			assert(ok, "invalid number")
		case .BOOLEAN:
			value, ok = strconv.parse_bool(token.value)
			assert(ok, "invalid bool")
		case .CURLY_OPEN:
			i, value = parse_object(tokens[:], i)
		case .ARRAY_OPEN:
			i, value = parse_list(tokens[:], i)
		}

		i += 1
		token = tokens[i]
		assert(token.type == .COMMA || token.type == .ARRAY_CLOSE, "INVALID JSON LIST")

		append(&list, value)
		#partial switch (token.type) {
		case .COMMA:
			continue loop
		case .ARRAY_CLOSE:
			break loop
		}

	}

	return i, list
}


parse_object :: proc(tokens: []Token, token_index: int) -> (int, Json_object) {
	i := token_index
	token: Token
	object: Json_object
	value: Json_value
	key: string
	ok: bool

	loop: for {
		i += 1
		token = tokens[i]
		assert(token.type == .STRING, "invalid json string key not found")
		key = token.value

		i += 1
		token = tokens[i]
		assert(token.type == .COLON, "invalid json colon not found")

		i += 1
		token = tokens[i]

		#partial switch (token.type) {
		case .STRING:
			value = token.value
		case .NUMBER:
			value, ok = strconv.parse_f64(token.value)
			assert(ok, "invalid number")
		case .BOOLEAN:
			value, ok = strconv.parse_bool(token.value)
			assert(ok, "invalid bool")
		case .CURLY_OPEN:
			i, value = parse_object(tokens[:], i)

		case .ARRAY_OPEN:
			// p.time_block_start("pl")
			i, value = parse_list(tokens[:], i)
		// p.time_block_end("pl")
		}

		i += 1
		token = tokens[i]
		assert(token.type == .COMMA || token.type == .CURLY_CLOSE, "INVALID JSON OBJECT")

		object[key] = value
		#partial switch token.type {
		case .COMMA:
			continue loop
		case .CURLY_CLOSE:
			break loop
		}
	}

	return i, object
}

parse :: proc(data: string) -> Json_value {
	p.time_function(byte_count = len(data))
	defer p.time_function_end()

	tokens: []Token = get_tokens(data)
	// INFO: Debugging
	// print_tokens(tokens)

	outer_object: Json_object
	assert(tokens[0].type == .CURLY_OPEN, "invalid json '{' not found ")

	i := 0
	token: Token

	// p.time_block_start("p")
	i, outer_object = parse_object(tokens[:], i)
	// p.time_block_end("p")

	token = tokens[i]

	assert(token.type == .CURLY_CLOSE, "invalid json '}' is missing for closing object")

	return outer_object
}


main :: proc() {
	data, ok := os.read_entire_file("./data.json", context.allocator)
	assert(ok, "Failed to read")
	defer delete(data, context.allocator)

	parsed := parse(string(data))
	fmt.println(parsed)

}
