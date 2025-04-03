package json_parser

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

parse_list :: proc(tokens: []Token) -> (int, Json_list) {
	i := 0
	list: Json_list
	value: Json_value
	ok: bool

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
		i += 1
		i, value = parse_object(tokens[:], i)
	case .ARRAY_OPEN:
		i, value = parse_list(tokens[i:])
	// unhandled case
	case .CURLY_CLOSE:
		fmt.println("unreachable")
	case .ARRAY_CLOSE:
		fmt.println("unreachable")
	}
	append(&list, value)

	return i, list
}


parse_object :: proc(tokens: []Token, token_index: int) -> (int, Json_object) {
	i := token_index
	object: Json_object
	value: Json_value
	ok: bool
	print_tokens(tokens)

	token := tokens[i]
	assert(token.type == .STRING, "invalid json string key not found")
	key: string = token.value

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
		i += 1
		i, value = parse_object(tokens[:], i)

	case .ARRAY_OPEN:
		i += 1
		i, value = parse_list(tokens[i:])

	// unhandled case
	case .CURLY_CLOSE:
		fmt.println("unreachable")
	case .ARRAY_CLOSE:
		fmt.println("unreachable")
	}

	object[key] = value
	return i, object
}

parse :: proc(data: string) -> Json_value {
	tokens: []Token = get_tokens(data)

	outer_object: Json_object
	assert(tokens[0].type == .CURLY_OPEN, "invalid json '{' not found ")

	i := 0
	token: Token
	loop: for {
		token = tokens[i]

		switch (token.type) {
		case .COLON:
		case .COMMA:
		case .STRING:
		case .NUMBER:
		case .BOOLEAN:
		case .NULL_TYPE:
		case .ARRAY_OPEN:
			break loop
		case .CURLY_OPEN:
			i += 1
			i, outer_object = parse_object(tokens[:], i)
			break loop

		// unhandled case
		case .CURLY_CLOSE:
			fmt.println("unreachable")
			break loop
		case .ARRAY_CLOSE:
			fmt.println("unreachable")
			break loop
		}

	}

	i += 1
	token = tokens[i]

	assert(token.type == .CURLY_CLOSE, "invalid json '}' is missing for closing object")

	return outer_object
}


main :: proc() {
	data, ok := os.read_entire_file("./test.json", context.allocator)
	if !ok {
		fmt.println("Fail to read!")
	}
	defer delete(data, context.allocator)

	parsed := parse(string(data))
	fmt.println(parsed)

}
