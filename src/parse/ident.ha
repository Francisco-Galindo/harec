use bufio;
use hare::ast;
use hare::lex;
use hare::lex::{ltok};
use memio;
use strings;

export fn ident(lexer: *lex::lexer) (ast::ident | error) = {
	let ident: []str = [];
	const first = want(lexer, ltok::NAME)?;

	append(ident, first.1 as str);
	for (true) {
		match (try(lexer, ltok::DOUBLE_COLON)?) {
		case void => break;
		case lex::token =>
			const name = want(lexer, ltok::NAME)?.1 as str;
			append(ident, name);
		};
	};

	return ident;
};
