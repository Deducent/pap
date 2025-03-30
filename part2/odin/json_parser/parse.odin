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

	token := tokens[i]

	#partial switch (token.type) {
	case .STRING:
		value = token.value
		break
	case .NUMBER:
		value, _ = strconv.parse_f64(token.value)
		break
	case .BOOLEAN:
		value, _ = strconv.parse_bool(token.value)
		break
	case .CURLY_OPEN:
		i += 1
		i, value = parse_object(tokens[i:])
		break
	case .ARRAY_OPEN:
		i, value = parse_list(tokens[i:])
		break
	// unhandled case
	case .CURLY_CLOSE:
		fmt.println("unreachable")
		break
	case .ARRAY_CLOSE:
		fmt.println("unreachable")
		break
	}
	append(&list, value)

	return i, list
}


parse_object :: proc(tokens: []Token) -> (int, Json_object) {
	i := 0
	object: Json_object
	value: Json_value

	token := tokens[i]
	assert(token.type == .STRING, "invalid json string key not found")
	key: string = token.value

	i += 1
	token = tokens[i]
	assert(token.type == .COLON, "invalid json colon not found")

	i += 1

	#partial switch (token.type) {
	case .STRING:
		value = token.value
	case .NUMBER:
		value, _ = strconv.parse_f64(token.value)
	case .BOOLEAN:
		value, _ = strconv.parse_bool(token.value)
	case .CURLY_OPEN:
		i += 1
		i, value = parse_object(tokens[i:])

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

parse :: proc() -> Json_value {
	tokens: []Token = get_tokens()

	outer_object: Json_object
	assert(tokens[0].type == .CURLY_OPEN, "invalid json '{' not found ")

	i := 0
	token: Token
	for {
		token = tokens[i]

		switch (token.type) {
		case .COLON:
		case .COMMA:
		case .STRING:
		case .NUMBER:
		case .BOOLEAN:
		case .NULL_TYPE:
		case .ARRAY_OPEN:
			continue
		case .CURLY_OPEN:
			i += 1
			i, outer_object = parse_object(tokens[i:])


		// unhandled case
		case .CURLY_CLOSE:
			fmt.println("unreachable")
			break
		case .ARRAY_CLOSE:
			fmt.println("unreachable")
			break
		}

	}

	assert(tokens[i].type == .CURLY_CLOSE, "invalid json '}' is missing for closing object")

	return outer_object
}


main :: proc() {
	fmt.println(parse())
}
