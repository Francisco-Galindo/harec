use hare::ast;
use hare::ast::{builtin_type};
use hare::lex;
use hare::lex::{ltok};
use strings;
use fmt;

fn integer_type(lexer: *lex::lexer) (builtin_type | error) = {
	const tok = want(lexer)?;
	switch (tok.0) {
	case ltok::BOOL =>
		return builtin_type::BOOL;
	case ltok::DONE =>
		return builtin_type::DONE;
	case ltok::NEVER =>
		return builtin_type::NEVER;
	case ltok::OPAQUE =>
		return builtin_type::OPAQUE;
	case ltok::RUNE =>
		return builtin_type::RUNE;
	case ltok::STR =>
		return builtin_type::STR;
	case ltok::VALIST =>
		return builtin_type::VALIST;
	case ltok::VOID =>
		return builtin_type::VOID;
	case ltok::I8 =>
		return builtin_type::I8;
	case ltok::I16 =>
		return builtin_type::I16;
	case ltok::I32 =>
		return builtin_type::I32;
	case ltok::I64 =>
		return builtin_type::I64;
	case ltok::U8 =>
		return builtin_type::U8;
	case ltok::U16 =>
		return builtin_type::U16;
	case ltok::U32 =>
		return builtin_type::U32;
	case ltok::U64 =>
		return builtin_type::U64;
	case ltok::INT =>
		return builtin_type::INT;
	case ltok::UINT =>
		return builtin_type::UINT;
	case ltok::SIZE =>
		return builtin_type::SIZE;
	case ltok::UINTPTR =>
		return builtin_type::UINTPTR;
	case ltok::F32 =>
		return builtin_type::F32;
	case ltok::F64 =>
		return builtin_type::F64;
	case =>
		return syntaxerr(lex::mkloc(lexer), "Unexpected {}, was expecting integer type", lex::tokstr(tok));
	};

};

fn primitive_type(lexer: *lex::lexer) (ast::_type | error) = {
	let tok = want(lexer)?;
	let repr = switch(tok.0) {
	case ltok::I8, ltok::I16, ltok::I32,
			ltok::I64, ltok::U8, ltok::U16, ltok::U32,
			ltok::U64, ltok::INT, ltok::UINT, ltok::SIZE,
			ltok::UINTPTR =>
		lex::unlex(lexer, tok);
		yield integer_type(lexer)?;
	case ltok::RUNE =>
		yield builtin_type::RUNE;
	case ltok::STR =>
		yield builtin_type::STR;
	case ltok::F32 =>
		yield builtin_type::F32;
	case ltok::F64 =>
		yield builtin_type::F64;
	case ltok::BOOL =>
		yield builtin_type::BOOL;
	case ltok::DONE =>
		yield builtin_type::DONE;
	case ltok::VALIST =>
		yield builtin_type::VALIST;
	case ltok::VOID =>
		yield builtin_type::VOID;
	case ltok::OPAQUE =>
		yield builtin_type::OPAQUE;
	case ltok::NEVER =>
		yield builtin_type::NEVER;
	case =>
		return syntaxerr(lex::mkloc(lexer), "Unexpected {}, was expecting primitive type", lex::tokstr(tok));
	};

	return ast::_type {
		start = tok.2,
		end = lex::prevloc(lexer),
		flags = ast::type_flag::NONE,
		repr = repr,
	};
};

fn pointer_type(lexer: *lex::lexer) (ast::_type | error) = {
	const start = lex::mkloc(lexer);
	const flags = if(try(lexer, ltok::NULLABLE)? is lex::token) {
		yield ast::pointer_flag::NULLABLE;
	} else {
		yield ast::pointer_flag::NONE;
	};

	want(lexer, ltok::TIMES)?;
	const typ = _type(lexer)?;

	return ast::_type {
		start = start,
		end = lex::prevloc(lexer),
		flags = ast::type_flag::NONE,
		repr = ast::pointer_type {
			referent = alloc(typ),
			flags = flags,
		},
	};

};

fn struct_union_type(lexer: *lex::lexer) (ast::_type | error) = {
	const kind = want(lexer, ltok::STRUCT, ltok::UNION)?;
	let packed = false;

	if (kind.0 == ltok::STRUCT && try(lexer, ltok::ATTR_PACKED)? is lex::token) {
		packed = true;
	};

	want(lexer, ltok::LBRACE)?;

	let members: []ast::struct_member = [];

	for (true) {
		if (try(lexer, ltok::RBRACE)? is lex::token && len(members) == 0) {
			return syntaxerr(lex::mkloc(lexer), "Expected field list");
		};

		let comment = "";

		let offst: nullable *ast::expr = match (try(lexer, ltok::ATTR_OFFSET)?) {
		case void =>
			yield null;
		case lex::token =>
			comment = strings::dup(lex::comment(lexer));
			want(lexer, ltok::LPAREN)?;
			let ex = expr(lexer)?;
			want(lexer, ltok::RPAREN)?;
			yield alloc(ex);
		};

		let tok = want(lexer, ltok::NAME, ltok::STRUCT, ltok::UNION)?;
		if (comment == "") {
			comment = strings::dup(lex::comment(lexer));
		};

		switch (tok.0) {
		case ltok::NAME =>
			lex::unlex(lexer, tok);
			let member = struct_field_embedded_alias(lexer, offst, comment)?;
			append(members, member);
		case ltok::STRUCT, ltok::UNION =>
			lex::unlex(lexer, tok);
			let member = struct_union_type(lexer)?;
			append(members, ast::struct_member {
				_offset = offst,
				member = alloc(member),
				docs = comment,
			});
		case => abort();
		};

		switch (want(lexer, ltok::RBRACE, ltok::COMMA)?.0) {
		case ltok::RBRACE => break;
		case ltok::COMMA =>
			const linecomment = lex::comment(lexer);
			const docs= &members[len(members) - 1].docs;
			if (linecomment != "" && *docs == "") {
				*docs = strings::dup(linecomment);
				free(lexer.comment);
				lexer.comment = "";
			};
		case => abort();
		};
	};

	return ast::_type {
		start = kind.2,
		end = lex::prevloc(lexer),
		flags = ast::type_flag::NONE,
		repr = switch (kind.0) {
		case ltok::STRUCT =>
			yield ast::struct_type {
				members = members,
				packed = packed,
			};
		case ltok::UNION =>
			yield members;
		case => abort();
		},
	};
};

fn struct_field_embedded_alias(lexer: *lex::lexer, offst: nullable *ast::expr, docs: str) (ast::struct_member | error) = {
	const name = want(lexer, ltok::NAME)?;

	const out: ast::ident = match(try(lexer, ltok::COLON, ltok::DOUBLE_COLON)?) {
	    case void =>
		yield alloc([name.1 as str]);
	case let tok: lex::token =>
		yield switch (tok.0) {
		case ltok::DOUBLE_COLON =>
			let id = ident(lexer)?;
			insert(id[0], name.1 as str);
			yield id;
		case ltok::COLON =>
			const typ = _type(lexer)?;
			let field = ast::struct_field {
				name = name.1 as str,
				_type = alloc(typ),
			};
			return ast::struct_member {
				_offset = offst,
				member = field,
				docs = docs,
			};
		case => abort();
		};

	};

	return ast::struct_member{
		_offset = offst,
		member = out: ast::struct_alias,
		docs = docs,
	};
};

fn tagged_type(
	lexer: *lex::lexer,
	first: ast::_type,
	start: lex::location
) (ast::_type | error) = {
	let tagged: ast::tagged_type = [];
	append(tagged, alloc(first));
	for (true) {
		append(tagged, alloc(_type(lexer)?));

		match (try(lexer, ltok::BOR)?) {
		case lex::token =>
			match (try(lexer, ltok::RPAREN)) {
			case lex::token => break;
			case => void;
			};
		case void =>
			want(lexer, ltok::RPAREN)?;
			break;
		};
	};
	return ast::_type {
		start = start,
		end = lex::prevloc(lexer),
		flags = ast::type_flag::NONE,
		repr = tagged,
	};
};

fn tuple_type(
	lexer: *lex::lexer,
	first: ast::_type,
	start: lex::location
) (ast::_type | error) = {
	let tuple: ast::tuple_type = [];
	append(tuple, alloc(first));
	for (true) {
		append(tuple, alloc(_type(lexer)?));
		match (try(lexer, ltok::COMMA)?) {
		case lex::token =>
			match (try(lexer, ltok::RPAREN)) {
			case lex::token => break;
			case => void;
			};
		case void =>
			want(lexer, ltok::RPAREN)?;
			break;
		};
	};
	return ast::_type {
		start = start,
		end = lex::prevloc(lexer),
		flags = ast::type_flag::NONE,
		repr = tuple,
	};
};

fn slice_array_type(lexer: *lex::lexer) (ast::_type | error) = {
	const start =  want(lexer, ltok::LBRACKET)?;

	let length = match (try(lexer, ltok::RBRACKET, ltok::TIMES, ltok::UNDERSCORE)?) {
	case void =>
		want(lexer, ltok::RBRACKET)?;
		yield alloc(expr(lexer)?);
	case let tok: lex::token =>
		yield switch (tok.0) {
		case ltok::UNDERSCORE =>
			want(lexer, ltok::RBRACKET)?;
			yield ast::len_contextual;
		case ltok::TIMES =>
			want(lexer, ltok::RBRACKET)?;
			yield ast::len_unbounded;
		case ltok::RBRACKET =>
			yield ast::len_slice;
		case => abort();
		};
	};

	let typ = _type(lexer)?;

	return ast::_type {
		start = start.2,
		end = lex::prevloc(lexer),
		flags =  ast::type_flag::NONE,
		repr = ast::list_type {
			length = length,
			members = alloc(typ),
		},
	};
};

fn enum_type(lexer: *lex::lexer) (ast::_type | error) = {
	const start =  want(lexer, ltok::ENUM)?;

	let tok = peek(lexer)? as lex::token;

	const enum_storage = match(try(lexer, ltok::LBRACE, ltok::RUNE)?) {
	case void =>
		let storage = integer_type(lexer)?;
		want(lexer, ltok::LBRACE)?;
		yield storage;
	case let tok: lex::token =>
		yield switch(tok.0) {
		case ltok::LBRACE =>
			yield builtin_type::INT;
		case ltok::RUNE =>
			want(lexer, ltok::LBRACE)?;
			yield builtin_type::RUNE;
		case => abort();
		};
	};

	let fields: []ast::enum_field = [];
	for (true) {
		if (try(lexer, ltok::RBRACE)? is lex::token && len(fields) == 0) {
			return syntaxerr(lex::mkloc(lexer), "Expected member list");
		};

		let name_tok = want(lexer, ltok::NAME)?;
		let comment = strings::dup(lex::comment(lexer));

		let expr: nullable *ast::expr = match (try(lexer, ltok::EQUAL)?) {
		case void =>
			yield null;
		case lex::token =>
			let ex = expr(lexer)?;
			yield alloc(ex);
		};

		append(fields, ast::enum_field {
			name = name_tok.1 as str,
			value = expr,
			loc = name_tok.2,
			docs = comment,
		});

		match (try(lexer, ltok::COMMA)?) {
		case lex::token =>
			match (try(lexer, ltok::RBRACE)) {
			case lex::token => break;
			case => void;
			};
		case void =>
			want(lexer, ltok::RBRACE)?;
			break;
		};
	};

	return ast::_type {
		start = start.2,
		end = lex::prevloc(lexer),
		flags =  ast::type_flag::NONE,
		repr = ast::enum_type {
			storage = enum_storage,
			values = fields,
		},
	};
};


fn alias_type(lexer: *lex::lexer) (ast::_type | error) = {
	const loc = lex::mkloc(lexer);

	let unwrap = false;

	if (try(lexer, ltok::ELLIPSIS)? is lex::token) {
		unwrap = true;
	};
	let id = ident(lexer)?;

	return ast::_type {
		start = loc,
		end = lex::prevloc(lexer),
		flags =  ast::type_flag::NONE,
		repr = ast::alias_type {
			unwrap = unwrap,
			ident = id,
		},
	};
};

fn prototype(lexer: *lex::lexer) (ast::func_type | error) = {
	want(lexer, ltok::LPAREN)?;
	let variadism = ast::variadism::NONE;

	let parameters: []ast::func_param = [];
	for (true) {
		let loc = lex::mkloc(lexer);

		let name = match(try(lexer, ltok::NAME)) {
		case let tok: lex::token =>
			want(lexer, ltok::COLON)?;
			yield tok.1 as str;
		case void =>
			yield "";
		};

		if (name == "") {
			want(lexer, ltok::RPAREN)?;
			break;
		};

		let typ = _type(lexer)?;

		let func_param = ast::func_param {
			loc = loc,
			name = name,
			_type = alloc(typ),
			default_value = void,
		};
		append(parameters, func_param);

		if (try(lexer, ltok::EQUAL)? is lex::token) {
			parameters[len(parameters) - 1].default_value = expr(lexer)?;
		};

		match (try(lexer, ltok::COMMA, ltok::ELLIPSIS)) {
		case let tok: lex::token =>
			switch(tok.0) {
			case ltok::COMMA =>
				match (try(lexer, ltok::ELLIPSIS, ltok::RPAREN)) {
				case let tok: lex::token =>
					switch(tok.0) {
					case ltok::ELLIPSIS =>
						want(lexer, ltok::RPAREN)?;
						variadism = ast::variadism::C;
						break;
					case ltok::RPAREN =>
						break;
					case => abort(); // unreachable
					};
				case void => continue;
				};
			case ltok::ELLIPSIS =>
				want(lexer, ltok::RPAREN)?;
				variadism = ast::variadism::HARE;
				break;
			case =>
			    abort(); // unreachable
			};
		case void =>
			want(lexer, ltok::RPAREN)?;
			break;
		};
	};

	let result = _type(lexer)?;

	return ast::func_type {
		result = alloc(result),
		variadism = variadism,
		params = parameters,
	};
};

fn fn_type(lexer: *lex::lexer) (ast::_type | error) = {
	let loc = lex::mkloc(lexer);
	want(lexer, ltok::FN)?;

	let proto = prototype(lexer)?;

	return ast::_type {
		start = loc,
		end = lex::prevloc(lexer),
		flags =  ast::type_flag::NONE,
		repr = proto,
	};
};


export fn _type(lexer: *lex::lexer) (ast::_type | error) = {
	const loc = lex::mkloc(lexer);

	let flags = ast::type_flag::NONE;

	if (try(lexer, ltok::CONST)? is lex::token) {
		flags |= ast::type_flag::CONST;
	};

	if (try(lexer, ltok::LNOT)? is lex::token) {
		flags |= ast::type_flag::ERROR;
	};

	let tok = peek(lexer)? as lex::token;
	let typ: ast::_type = switch (tok.0) {
	case ltok::BOOL, ltok::DONE, ltok::NEVER, ltok::OPAQUE,
		    ltok::RUNE, ltok::STR, ltok::VALIST,
		    ltok::VOID, ltok::I8, ltok::I16, ltok::I32,
		    ltok::I64, ltok::U8, ltok::U16, ltok::U32,
		    ltok::U64, ltok::INT, ltok::UINT, ltok::SIZE,
		    ltok::UINTPTR, ltok::F32, ltok::F64 =>
		yield primitive_type(lexer)?;
	case ltok::TIMES, ltok::NULLABLE =>
		yield pointer_type(lexer)?;
	case ltok::STRUCT, ltok::UNION =>
		yield struct_union_type(lexer)?;
	case ltok::LPAREN =>
		want(lexer, ltok::LPAREN)?;
		let first_element = _type(lexer)?;
		yield switch (want(lexer, ltok::BOR, ltok::COMMA)?.0) {
		case ltok::BOR =>
			yield tagged_type(lexer, first_element, tok.2)?;
		case ltok::COMMA =>
			yield tuple_type(lexer, first_element, tok.2)?;
		case => abort();
		};
	case ltok::LBRACKET =>
		yield slice_array_type(lexer)?;
	case ltok::FN =>
		yield fn_type(lexer)?;
	case ltok::NAME, ltok::ELLIPSIS =>
		yield alias_type(lexer)?;
	case ltok::ENUM =>
		yield enum_type(lexer)?;
	case =>
		return syntaxerr(lex::mkloc(lexer), "Unexpected {}, was expecting type", lex::tokstr(tok));
	};

	typ.flags |= flags;
	return typ;
};
