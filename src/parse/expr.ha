use hare::ast;
use hare::lex;
use hare::lex::{ltok};
use math;
use strings;
use types;

fn struct_literal(lexer: *lex::lexer) (ast::struct_literal | error) = {
	let id: []str = [];
	if (!(try(lexer, ltok::STRUCT)? is lex::token)) {
		id = ident(lexer)?;
	};

	let autofill = false;

	want(lexer, ltok::LBRACE)?;

	let fields: [](ast::struct_value | *struct_literal) = [];
	for (true) {
		let loc = lex::mkloc(lexer);

		let field = match(try(lexer, ltok::NAME)) {
		case let tok: lex::token =>

			const typ: nullable *ast::_type =
				if (try(lexer, ltok::COLON)? is lex::token) {
					yield alloc(_type(lexer)?);
				} else null;

			want(lexer, ltok::EQUAL)?;

			let expr = expr(lexer)?;

			yield struct_value {
				name = tok.1 as str,
				_type = typ,
				init = expr,
			};
		case void =>
			yield alloc(struct_literal(lexer)?);
		};

		append(fields, field);

		// if (try(lexer, ltok::EQUAL)? is lex::token) {
		// 	parameters[len(parameters) - 1].default_value = expr(lexer)?;
		// };

		match (try(lexer, ltok::COMMA)) {
		case let tok: lex::token =>
			match (try(lexer, ltok::ELLIPSIS, ltok::RBRACE)) {
			case let tok: lex::token =>
				switch(tok.0) {
				case ltok::ELLIPSIS =>
					want(lexer, ltok::RBRACE)?;
					autofill = true;
					break;
				case ltok::RBRACE =>
					break;
				case => abort(); // unreachable
				};
			case void => continue;
			};
		case void =>
			want(lexer, ltok::RBRACE)?;
			break;
		};
	};

	return ast::struct_literal {
		autofill = autofill,
		alias = id,
		fields = fields,
	};
};

fn literal(lexer: *lex::lexer) (ast::literal_expr | error) = {
	const loc = lex::mkloc(lexer);

	let tok = peek(lexer)? as lex::token;
	let lit: ast::literal_expr = switch (tok.0) {
	case ltok::LIT_U8, ltok::LIT_U16, ltok::LIT_U32, ltok::LIT_U64,
			ltok::LIT_UINT, ltok::LIT_SIZE =>
		yield ast::number_literal {
			suff = tok.0,
			value = tok.1 as u64,
			sign = false,
		};
	case ltok::LIT_I8, ltok::LIT_I16, ltok::LIT_I32 ltok::LIT_I64,
			ltok::LIT_INT, ltok::LIT_ICONST =>
		yield ast::number_literal {
			suff = tok.0,
			value = tok.1 as i64,
			sign = false,
		};
	case ltok::LIT_F32, ltok::LIT_F64 =>
		yield ast::number_literal {
			suff = tok.0,
			value = tok.1 as f64,
			sign = false,
		};
	case ltok::TRUE =>
		yield true;
	case ltok::FALSE =>
		yield false;
	case ltok::NULL =>
		yield ast::_null;
	case ltok::VOID =>
		yield void;
	case ltok::DONE =>
		yield done;
	case ltok::LIT_RCONST, ltok::LIT_STR =>
		yield tok.1 as (rune | str);
	case ltok::STRUCT =>
		yield struct_literal(lexer)?;
	case =>
		return syntaxerr(lex::mkloc(lexer), "Expected literal expression");
	};

	return ast::expr {
		ast = tok.2,
		end = lex::prevloc(lexer),
		expr = lit,
	};
};

fn binding(lexer: *lex::lexer, is_static: bool) (ast::expr | error) = {
	const loc = lex::mkloc(lexer);
	const tok = want(lexer, ltok::DEF, ltok::CONST, ltok::LET)?.0;
	const kind = switch (tok) {
	case ltok::DEF =>
		assert(!is_static);
		yield ast::binding_kind::DEF;
	case ltok::CONST =>
		yield ast::binding_kind::CONST;
	case ltok::LET =>
		yield ast::binding_kind::LET;
	case => abort(); // unreachable
	};

	let bindings: []ast::binding = [];
	for (true) {
		const (tok, value, _) = want(lexer, ltok::NAME, ltok::LPAREN)?;
		const name = switch (tok) {
		case ltok::NAME =>
			yield value as str;
		case ltok::LPAREN =>
			if (kind == ast::binding_kind::DEF) {
				return syntaxerr(lex::mkloc(lexer),
					"Can't use tuple unpacking with def");
			};
			yield binding_unpack(lexer)?;
		case => abort();
		};
		const btype: nullable *ast::_type =
			if (try(lexer, ltok::COLON)? is lex::token) {
				yield alloc(_type(lexer)?);
			} else null;
		want(lexer, ltok::EQUAL)?;
		const init = alloc(expr(lexer)?);
		append(bindings, ast::binding {
			name = name,
			_type = btype,
			init = init,
		});
		match (try(lexer, ltok::COMMA)?) {
		case void => break;
		case lex::token => void;
		};
	};

	return ast::expr {
		start = loc,
		end = lex::prevloc(lexer),
		expr = ast::binding_expr {
			is_static = is_static,
			kind = kind,
			bindings = bindings,
		},
	};
};
