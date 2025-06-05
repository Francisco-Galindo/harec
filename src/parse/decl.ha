use ascii;
use hare::ast;
use hare::lex;
use hare::lex::{ltok};
use strings;
use fmt;

// Parses the declarations for a sub-unit.
export fn decls(lexer: *lex::lexer) ([]ast::decl | error) = {
	let decls: []ast::decl = [];
	for (true) {
		let loc = lex::mkloc(lexer);
		if (peek(lexer, ltok::EOF)? is lex::token) break;
		append(decls, decl_func(lexer)?);
		want(lexer, ltok::SEMICOLON)?;
	};
	return decls;
};


fn decl_func(lexer: *lex::lexer) (ast::decl | error) = {
	let loc = lex::mkloc(lexer);

	want(lexer, ltok::FN)?;
	let ident_loc = lex::mkloc(lexer);
	let ident = ident(lexer)?;
	let proto_start = lex::mkloc(lexer);
	let prototype = prototype(lexer)?;
	let proto_end = lex::prevloc(lexer);

	let tok = want(lexer, ltok::EQUAL, ltok::SEMICOLON)?;
	let body = switch (tok.0) {
	case ltok::EQUAL =>
		yield alloc(expr(lexer)?);
	case ltok::SEMICOLON =>
		lex::unlex(lexer, tok);
		yield null;
	case => abort(); // unreachable
	};

	return ast::decl {
		exported = false,
		start = loc,
		end = lex::prevloc(lexer),
		decl = ast::decl_func {
			symbol = "",
			ident = ident,
			prototype = alloc(ast::_type {
				start = proto_start,
				end = proto_end,
				flags = 0,
				repr = prototype,
			}),
			body = body,
			attrs = ast::fndecl_attr::NONE,
		},
		docs =  "",
	};
};
