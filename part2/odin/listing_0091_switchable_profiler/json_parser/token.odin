package json_parser

import p "../profiler"
import "core:fmt"
import "core:os"
import "core:strings"

Token :: struct {
	value: string,
	type:  Symbols,
}

get_tokens :: proc(data: string) -> []Token {
	p.time_function()
	defer p.time_function_end()
	tokens: [dynamic]Token
	char: u8 = 0
	i := 0

	for {
		token: Token
		if (i < len(data)) {
			char = data[i]
		} else {
			return tokens[:]
		}
		defer i += 1
		switch {
		case char == ' ' || char == '\n' || char == '\t':
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
			builder := strings.builder_make(context.temp_allocator)
			i += 1
			defer strings.builder_destroy(&builder)
			for {
				char = data[i]
				if char != '"' {
					strings.write_byte(&builder, char)
					i += 1
				} else {
					str := strings.to_string(builder)
					token.value, _ = strings.clone(str)
					break
				}
			}

		case char == '-' || (char <= '9' && char >= '0'):
			token.type = Symbols.NUMBER
			builder := strings.builder_make(context.temp_allocator)
			defer strings.builder_destroy(&builder)
			for {
				char = data[i]
				if (char <= '9' && char >= '0') || char == '.' || char == '-' {
					strings.write_byte(&builder, char)
					i += 1
				} else {
					str := strings.to_string(builder)
					token.value, _ = strings.clone(str)
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

print_tokens :: proc(tokens: []Token) {
	for token, i in tokens {
		fmt.println(i, token.type, token.value)
	}
}
