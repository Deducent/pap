package json_parser

import "core:fmt"
import "core:os"
import "core:strings"

Token :: struct {
	value: string,
	type:  Symbols,
}

get_tokens :: proc() -> []Token {
	data, ok := os.read_entire_file("./data.json", context.allocator)
	if !ok {
		fmt.println("Fail to read!")
	}

	defer delete(data, context.allocator)
	file_string := string(data)

	tokens: [dynamic]Token
	char: u8 = 0
	i := 0
	for {
		token: Token
		if (i < len(file_string)) {
			char = file_string[i]
		} else {
			return tokens[:]
		}
		defer i += 1
		switch {
		case char == ' ' || char == '\n':
			continue
		case char == '{':
			token.type = Symbols.CURLY_OPEN
		case char == '}':
			token.type = Symbols.CURLY_CLOSE
		case char == '[':
			token.type = Symbols.ARRAY_OPEN

		case char == ']':
			token.type = Symbols.ARRAY_CLOSE

		case char == '"':
			token.type = Symbols.STRING
			bytes: [1024]byte
			builder := strings.builder_from_bytes(bytes[:])
			i += 1
			for {
				char = file_string[i]
				if char != '"' {
					strings.write_byte(&builder, char)
					i += 1
				} else {
					token.value = strings.to_string(builder)
					break
				}
			}

		case char == '-' || (char <= '9' && char >= '0'):
			token.type = Symbols.NUMBER
			bytes: [1024]byte
			builder := strings.builder_from_bytes(bytes[:])
			for {
				char = file_string[i]
				if (char <= '9' && char >= '0') || char == '.' || char == '-' {
					strings.write_byte(&builder, char)
					i += 1
				} else {
					token.value = strings.to_string(builder)
					i -= 1
					break
				}
			}

		case char == ':':
			token.type = Symbols.COLON

		case char == ',':
			token.type = Symbols.COMMA

		case char == 'f':
			token.type = Symbols.BOOLEAN
			token.value = "false"

		case char == 't':
			token.type = Symbols.BOOLEAN
			token.value = "true"

		}

		append(&tokens, token)
	}

}
