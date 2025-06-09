use bufio;
use errors;
use fmt;
use fs;
use getopt;
use io;

// Choose if you want to use the hare built-in lexer or ours:
use hare::lex; // uncomment to use built-in
use hare::lex::{ltok};
use parse;
use hare::ast;
use gen;

use os;
use types;

export fn main() void = {
	const cmd = getopt::parse(os::args,
		"Program for lexing Hare source code",
		('f', "file", "file to read from. If this flag is not used, will read from stdin"),
		('b', "present basic tokens"),
		('c', "count tokens"),
	);
	defer getopt::finish(&cmd);

	let file_path: str = "";
	let basic: bool = false;
	let count: bool = false;

	for (let opt .. cmd.opts) {
		switch (opt.0) {
		case 'f' =>
			file_path = opt.1;
		case 'b' =>
			basic = true;
		case 'c' =>
			if (basic) {
				fmt::fatalf("'-b' and '-c' are mutually exclusive!");
			};
			count = true;
		case =>
			fmt::fatalf("Invalid option: '-{}'!", opt.0);
		};
	};

	const file = if (file_path == "") {
		yield os::stdin_file;
	} else {
		yield match(os::open(file_path)) {
		case let f: io::file =>
			yield f;
		case let err: fs::error =>
			fmt::fatalf("Unable to open {}: {}",
				file_path, fs::strerror(err));
		};
	};
	defer io::close(file)!;

	const scan = bufio::newscanner(file, types::SIZE_MAX);
	const lexr = lex::init(&scan, file_path);

        // match (parse::shunting_yard(&lexr)) {
	// case let exp: ast::expr =>
	// 	print_expression(exp);
	// case => fmt::println("ERROREO")!;
	// };

	match (parse::decls(&lexr)) {
	case let exp: []ast::decl =>
		// fmt::println("PARSEO ALGO")!;
		// print_decls(exp);
		match (gen::gen(exp)) {
		case let err: gen::error =>
		    fmt::println(err.1)!;
		case => fmt::println("# Exito al generar")!;
		};
	case => fmt::println("ALGO SALIó MAL")!;
	};

};

fn print_decls(decls: []ast::decl) void = {
	for (let decl .. decls) {
		match (decl.decl) {
		case let dec_fn: ast::decl_func =>
			fmt::println(dec_fn.ident[0])!;
		};
	};
};

fn print_expression(tree: ast::expr) void = {
	match (tree.expr) {
	case let ex: ast::binarithm_expr =>
		print_expression(*(ex.lvalue));
		print_expression(*(ex.rvalue));
		switch (ex.op) {
		case ast::binarithm_op::LOR =>
			fmt::println("||")!;
		case ast::binarithm_op::LAND =>
			fmt::println("&&")!;
		case ast::binarithm_op::LEQUAL, ast::binarithm_op::NEQUAL =>
			fmt::println("!=")!;
		case ast::binarithm_op::PLUS =>
			fmt::println("+")!;
		case ast::binarithm_op::MINUS =>
			fmt::println("-")!;
		case ast::binarithm_op::TIMES =>
			fmt::println("*")!;
		case ast::binarithm_op::DIV =>
			fmt::println("/")!;
		case ast::binarithm_op::MODULO =>
			fmt::println("%")!;
		case =>
			fmt::println("lel")!;
		};
	case let ex: ast::number_literal =>
		fmt::println("LIT", ex.value)!;
	case let ex: ast::access_identifier =>
		fmt::println(ex[0])!;
	};
};

fn token_type(tok: lex::ltok) str = {
	return switch(tok) {
	case lex::ltok::COMMA, lex::ltok::LBRACE, lex::ltok::LBRACKET, lex::ltok::LPAREN, lex::ltok::RBRACE, lex::ltok::RBRACKET, lex::ltok::RPAREN, lex::ltok::SEMICOLON =>
		yield "PUNCTUATION";
	case =>
		yield if (tok <= lex::ltok::LAST_KEYWORD) {
			yield "KEYWORD";
		} else if (tok <= lex::ltok::LAST_BTOK) {
			yield "OPERATOR";
		} else if (tok < lex::ltok::LIT_STR) {
			yield "CONSTANT";
		} else if (tok == lex::ltok::LIT_STR) {
			yield "LITERAL";
		} else if (tok == lex::ltok::EOF) {
			yield "END OF FILE";
		} else {
			yield "IDENTIFIER";
		};
	};
};

fn basic_lex(lexr: *lex::lexer) void = {
	for (true) {
		const token = match(lex::lex(lexr)) {
		case let err: lex::error =>
			fmt::fatalf("Could not lex: {}", lex::strerror(err));
		case let tok: lex::token =>
			yield tok;
		};

		if (token.1 is void) {
			fmt::printfln("{}: \t(line {}, col {}) \t{}", token_type(token.0), token.2.line, token.2.col, lex::tokstr(token))!;
		} else {
			fmt::printfln("{}: \t(line {}, col {}) \t{}", token_type(token.0), token.2.line, token.2.col, token.1)!;
		};

		if (token.0 == lex::ltok::EOF) {
			break;
		};
	};
};

fn count_lex(lexr: *lex::lexer) int = {
	let n: int = 0;
	for (true) {
		const token = match(lex::lex(lexr)) {
		case let err: lex::error =>
			fmt::fatalf("Could not lex: {}", lex::strerror(err));
		case let tok: lex::token =>
			yield tok;
		};

		if (token.0 == lex::ltok::EOF) {
			break;
		};

		n += 1;
	};

	return n;
};
