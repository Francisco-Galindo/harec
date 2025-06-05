use hare::ast;
use hare::lex;
use hare::lex::{ltok};
use math;
use strings;
use types;
use fmt;

// Checa si es una estructura de control
// Si no, haz shunting yard hasta acabar expresión o llegar a asignación
// Si hay asignación, evaluar el rhs
// Devolver chaval
export fn expr(lexer: *lex::lexer, is_in_parenthesis: bool = false) (ast::expr | error) = {
	let loc = lex::mkloc(lexer);

	const assignment_ops: [_]ltok = [ltok::EQUAL, ltok::DIVEQ, ltok::MINUSEQ, ltok::PLUSEQ, ltok::TIMESEQ];

	let tok = peek(lexer)? as lex::token;
	let expr: ast::expr = switch (tok.0) {
	case ltok::FOR =>
		yield for_expr(lexer)?;
	case ltok::IF =>
		yield if_expr(lexer)?;
	case ltok::RETURN =>
		yield return_expr(lexer)?;
	case ltok::BREAK =>
		yield break_expr(lexer)?;
	case ltok::CONTINUE =>
		yield continue_expr(lexer)?;
	case ltok::LBRACE =>
		yield compound_expr(lexer)?;
	case =>
		let ex = shunting_yard(lexer, is_in_parenthesis)?;
		match (try(lexer, assignment_ops ...)) {
		case let tok: lex::token =>
			let lhs = ex;
			match (ex.expr) {
			case ast::access_identifier =>
				let rhs = shunting_yard(lexer)?;
				ex = ast::expr {
					start = loc,
					end = lex::prevloc(lexer),
					expr = ast::assign_expr {
						op = assignment_op_to_op(tok),
						object = alloc(lhs),
						value = alloc(rhs),
					},
				};

			case =>
				return syntaxerr(lex::mkloc(lexer), "LHS of assignment has to be an identifier");
			};
		case => void;
		};
		yield ex;
	};

	return expr;
};

fn compound_expr(lexer: *lex::lexer) (ast::expr | error) = {
	let loc = lex::mkloc(lexer);
	want(lexer, ltok::LBRACE)?;
	let label: ast::label = "";

	let exprs: []*ast::expr = [];
	for (true) {
		if (peek(lexer, ltok::LET) is lex::token) {
			append(exprs, alloc(binding(lexer)?));
		} else {
			let ex = expr(lexer)?;
			append(exprs, alloc(ex));
		};

		want(lexer, ltok::SEMICOLON)?;

		match (try(lexer, ltok::RBRACE)) {
		case lex::token => break;
		case => void;
		};
	};

	return ast::expr {
		start = loc,
		end = lex::prevloc(lexer),
		expr = ast::compound_expr {
			exprs = exprs,
			label = label,
		},
	};
};

fn if_expr(lexer: *lex::lexer) (ast::expr | error) = {
	let loc = lex::mkloc(lexer);
	want(lexer, ltok::IF)?;
	want(lexer, ltok::LPAREN)?;


	let cond = alloc(expr(lexer, true)?);

	let newloc = lex::mkloc(lexer);
	// want(lexer, ltok::RPAREN)?;
	let tbranch = alloc(expr(lexer)?);
	let fbranch: nullable *ast::expr = if (try(lexer, ltok::ELSE) is lex::token) {
		yield alloc(expr(lexer)?);
	} else null;

	return ast::expr {
		start = loc,
		end = lex::prevloc(lexer),
		expr = ast::if_expr {
			cond = cond,
			tbranch = tbranch,
			fbranch = fbranch,
		},
	};
};

fn for_expr(lexer: *lex::lexer) (ast::expr | error) = {
	let loc = lex::mkloc(lexer);
	let label: ast::label = "";
	want(lexer, ltok::FOR)?;
	want(lexer, ltok::LPAREN)?;

	let bindings: nullable *ast::expr = match (binding(lexer)) {
	case let expr: ast::expr =>
		want(lexer, ltok::SEMICOLON)?;
		yield alloc(expr);
	case =>
		yield null;
	};

	let cond: nullable *ast::expr = match (expr(lexer, true)) {
	case let expr: ast::expr =>
		yield alloc(expr);
	case =>
		yield null;
	};

	let afterthought: nullable *ast::expr = if (try(lexer, ltok::SEMICOLON) is lex::token) {
		yield match (expr(lexer)) {
		case let expr: ast::expr =>
			yield alloc(expr);
		case =>
			yield null;
		};
	} else null;

	let body = alloc(expr(lexer)?);

	return ast::expr {
		start = loc,
		end = lex::prevloc(lexer),
		expr = ast::for_expr {
			kind = ast::for_kind::ACCUMULATOR,
			bindings = bindings,
			cond = cond,
			afterthought = afterthought,
			body = body,
			label = label,
		},
	};
};

fn continue_expr(lexer: *lex::lexer) (ast::expr | error) = {
	let loc = lex::mkloc(lexer);
	want(lexer, ltok::CONTINUE)?;
	let label: ast::continue_expr = "";
	return ast::expr {
		start = loc,
		end = lex::prevloc(lexer),
		expr = label,
	};
};

fn break_expr(lexer: *lex::lexer) (ast::expr | error) = {
	let loc = lex::mkloc(lexer);
	want(lexer, ltok::BREAK)?;
	let label: ast::break_expr = "";

	return ast::expr {
		start = loc,
		end = lex::prevloc(lexer),
		expr = label,
	};
};

fn return_expr(lexer: *lex::lexer) (ast::expr | error) = {
	let loc = lex::mkloc(lexer);
	want(lexer, ltok::RETURN)?;
	let expr: ast::return_expr = match (expr(lexer)) {
	case let ex: ast::expr =>
		yield alloc(ex);
	case =>
		yield null;
	};


	return ast::expr {
		start = loc,
		end = lex::prevloc(lexer),
		expr = expr,
	};

};

export fn shunting_yard(lexer: *lex::lexer, is_in_parenthesis: bool = false) (ast::expr | error) = {
	let loc = lex::mkloc(lexer);
	let ast_queue: []*ast::expr = [];
	let stack: []*ast::expr = [];
	let operator_stack: []lex::token = [];
	let lparen_ctr = 0z;

	for (true) {
		let exp_loc = lex::mkloc(lexer);
		match (want(lexer)) {
		case let tok: lex::token =>

			switch(tok.0) {
			case ltok::RPAREN =>
				for (len(operator_stack) > 0 && operator_stack[0].0 != ltok::LPAREN) {

					let pop = operator_stack[0];
					delete(operator_stack[0]);
					let rvalue = ast_queue[len(ast_queue) - 1];
					delete(ast_queue[len(ast_queue) - 1]);
					let lvalue = ast_queue[len(ast_queue) - 1];
					delete(ast_queue[len(ast_queue) - 1]);
					let expr = alloc(ast::expr {
						start = exp_loc,
						end = lex::prevloc(lexer),
						expr = ast::binarithm_expr {
							op = tok_to_op(pop),
							lvalue = lvalue,
							rvalue = rvalue,
						},
					});
					append(ast_queue, expr);

				};

				if (is_in_parenthesis && len(operator_stack) == 0) {
					break;
				} else if (len(operator_stack) == 0) {
					return syntaxerr(lex::mkloc(lexer), "Closing parenthesis without matching opening one.");
				};


				delete(operator_stack[0]);


			case ltok::LPAREN =>
				lparen_ctr += 1;
				insert(operator_stack[0], tok);
			case ltok::LOR, ltok::LAND, ltok::LEQUAL, ltok::NEQUAL,
					ltok::LESS, ltok::LESSEQ, ltok::GT, ltok::GTEQ,
					ltok::PLUS, ltok::MINUS, ltok::TIMES, ltok::DIV,
					ltok::MODULO =>
				for (true) {
					if (len(operator_stack) == 0) {
						break;
					};
					let o2 = operator_stack[0];
					if (o2.0 == ltok::LPAREN || precedence(o2) < precedence(tok)) {
						break;
					};

					let pop = operator_stack[0];
					delete(operator_stack[0]);

					let rvalue = ast_queue[len(ast_queue) - 1];
					delete(ast_queue[len(ast_queue) - 1]);

					let lvalue = ast_queue[len(ast_queue) - 1];
					delete(ast_queue[len(ast_queue) - 1]);
					let expr = alloc(ast::expr {
						start = exp_loc,
						end = lex::prevloc(lexer),
						expr = ast::binarithm_expr {
							op = tok_to_op(pop),
							lvalue = lvalue,
							rvalue = rvalue,
						},
					});
					append(ast_queue, expr);

				};
				insert(operator_stack[0], tok);
			case ltok::LIT_ICONST, ltok::LIT_INT, ltok::LIT_F64, ltok::LIT_STR, ltok::TRUE, ltok::FALSE =>
				lex::unlex(lexer, tok);
				let lit = alloc(literal(lexer)?);
				append(ast_queue, lit);
			case ltok::NAME =>
				lex::unlex(lexer, tok);
				let id = ident(lexer)?;
				let expr = alloc(ast::expr {
					start = exp_loc,
					end = lex::prevloc(lexer),
					expr = id,
				});

				match (peek(lexer, ltok::LPAREN)) {
				case lex::token =>
					expr = alloc(fn_call(lexer, expr)?);
					append(ast_queue, expr);
				case =>
					append(ast_queue, expr);
				};
			case =>
				lex::unlex(lexer, tok);
				break;
			};
		case => break;
		};
	};

	for (len(operator_stack) > 0) {
		if (operator_stack[0].0 == ltok::LPAREN) {
			return syntaxerr(lex::mkloc(lexer), "Mismatched parenthesis");
		};

		let pop = operator_stack[0];
		delete(operator_stack[0]);

		let rvalue = ast_queue[len(ast_queue) - 1];
		delete(ast_queue[len(ast_queue) - 1]);

		let lvalue = ast_queue[len(ast_queue) - 1];
		delete(ast_queue[len(ast_queue) - 1]);


		let expr = alloc(ast::expr {
			start = pop.2,
			end = lex::prevloc(lexer),
			expr = ast::binarithm_expr {
				op = tok_to_op(pop),
				lvalue = lvalue,
				rvalue = rvalue,
			},
		});
		append(ast_queue, expr);
	};

	if (len(ast_queue) == 0) {
		return syntaxerr(lex::mkloc(lexer), "Expected an expression");
	};

	return *ast_queue[0];
};

fn fn_call(lexer: *lex::lexer, id: *ast::expr) (ast::expr | error) = {
	let loc = lex::mkloc(lexer);
	let exprs: []*ast::expr = [];
	let variadic = false;

	want(lexer, ltok::LPAREN)?;

	for (true) {
		let expr = alloc(expr(lexer, true)?);
		append(exprs, expr);

		match (try(lexer, ltok::COMMA, ltok::ELLIPSIS, ltok::RPAREN)) {
		case let tok: lex::token =>
			switch (tok.0) {
			case ltok::COMMA =>
				if (try(lexer, ltok::RPAREN) is lex::token) {
					break;
				};
			case ltok::ELLIPSIS =>
				variadic = true;
				want(lexer, ltok::RPAREN)?;
				break;
			case ltok::RPAREN =>
				break;
			case => abort(); // unreachable
			};
		case =>
			break;
		};
	};

	return ast::expr {
		start = loc,
		end = lex::prevloc(lexer),
		expr = ast::call_expr {
			lvalue = id,
			variadic = variadic,
			args = exprs,
		},
	};
};

fn assignment_op_to_op(tok: lex::token) (ast::binarithm_op | void) = {
	switch (tok.0) {
	case ltok::DIVEQ =>
		return ast::binarithm_op::DIV;
	case ltok::MINUSEQ =>
		return ast::binarithm_op::MINUS;
	case ltok::PLUSEQ =>
		return ast::binarithm_op::PLUS;
	case ltok::TIMESEQ =>
		return ast::binarithm_op::TIMES;
	case => return;
	};
};

fn tok_to_op(tok: lex::token) ast::binarithm_op = {
	switch (tok.0) {
	case ltok::DIV =>
		return ast::binarithm_op::DIV;
	case ltok::GT =>
		return ast::binarithm_op::GT;
	case ltok::GTEQ =>
		return ast::binarithm_op::GTEQ;
	case ltok::LAND =>
		return ast::binarithm_op::LAND;
	case ltok::LEQUAL =>
		return ast::binarithm_op::LEQUAL;
	case ltok::LESS =>
		return ast::binarithm_op::LESS;
	case ltok::LESSEQ =>
		return ast::binarithm_op::LESSEQ;
	case ltok::LOR =>
		return ast::binarithm_op::LOR;
	case ltok::MINUS =>
		return ast::binarithm_op::MINUS;
	case ltok::MODULO =>
		return ast::binarithm_op::MODULO;
	case ltok::NEQUAL =>
		return ast::binarithm_op::NEQUAL;
	case ltok::PLUS =>
		return ast::binarithm_op::PLUS;
	case ltok::TIMES =>
		return ast::binarithm_op::TIMES;
	case => abort();
	};
};

fn precedence(tok: lex::token) int = {
	switch (tok.0) {
	case ltok::LOR =>
		return 0;
	case ltok::LAND =>
		return 2;
	case ltok::LEQUAL, ltok::NEQUAL =>
		return 3;
	case ltok::LESS, ltok::LESSEQ, ltok::GT, ltok::GTEQ =>
		return 4;
	case ltok::PLUS, ltok::MINUS =>
		return 9;
	case ltok::TIMES, ltok::DIV, ltok::MODULO =>
		return 10;
	case =>
		return -1;
	};
};

// fn struct_literal(lexer: *lex::lexer) (ast::struct_literal | error) = {
// 	let id: []str = [];
// 	if (!(try(lexer, ltok::STRUCT)? is lex::token)) {
// 		id = ident(lexer)?;
// 	};
//
// 	let autofill = false;
//
// 	want(lexer, ltok::LBRACE)?;
//
// 	let fields: [](ast::struct_value | *ast::struct_literal) = [];
// 	for (true) {
// 		let loc = lex::mkloc(lexer);
//
// 		let field = match(try(lexer, ltok::NAME)) {
// 		case let tok: lex::token =>
//
// 			const typ: nullable *ast::_type =
// 				if (try(lexer, ltok::COLON)? is lex::token) {
// 					yield alloc(_type(lexer)?);
// 				} else null;
//
// 			want(lexer, ltok::EQUAL)?;
//
// 			let expr = expr(lexer)?;
//
// 			yield struct_value {
// 				name = tok.1 as str,
// 				_type = typ,
// 				init = expr,
// 			};
// 		case void =>
// 			yield alloc(struct_literal(lexer)?);
// 		};
//
// 		append(fields, field);
//
// 		// if (try(lexer, ltok::EQUAL)? is lex::token) {
// 		// 	parameters[len(parameters) - 1].default_value = expr(lexer)?;
// 		// };
//
// 		match (try(lexer, ltok::COMMA)) {
// 		case let tok: lex::token =>
// 			match (try(lexer, ltok::ELLIPSIS, ltok::RBRACE)) {
// 			case let tok: lex::token =>
// 				switch(tok.0) {
// 				case ltok::ELLIPSIS =>
// 					want(lexer, ltok::RBRACE)?;
// 					autofill = true;
// 					break;
// 				case ltok::RBRACE =>
// 					break;
// 				case => abort(); // unreachable
// 				};
// 			case void => continue;
// 			};
// 		case void =>
// 			want(lexer, ltok::RBRACE)?;
// 			break;
// 		};
// 	};
//
// 	return ast::struct_literal {
// 		autofill = autofill,
// 		alias = id,
// 		fields = fields,
// 	};
// };

fn literal(lexer: *lex::lexer) (ast::expr | error) = {
	const loc = lex::mkloc(lexer);

		// fmt::println("B")!;
	let tok = peek(lexer)? as lex::token;
	let lit: ast::literal_expr = switch (tok.0) {
	case ltok::LIT_ICONST, ltok::LIT_U8, ltok::LIT_U16, ltok::LIT_U32, ltok::LIT_U64,
			ltok::LIT_UINT, ltok::LIT_SIZE =>
		// fmt::println("E")!;
		yield ast::number_literal {
			suff = tok.0,
			value = tok.1 as u64,
			sign = false,
		};
	// case ltok::LIT_I8, ltok::LIT_I16, ltok::LIT_I32, ltok::LIT_I64,
	// 		ltok::LIT_INT, ltok::LIT_ICONST =>
	// 	yield ast::number_literal {
	// 		suff = tok.0,
	// 		value = tok.1 as i64,
	// 		sign = false,
	// 	};
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
	// case ltok::STRUCT =>
	// 	yield struct_literal(lexer)?;
	case =>
		return syntaxerr(lex::mkloc(lexer), "Expected literal expression");
	};

	want(lexer)?;

	return ast::expr {
		start = loc,
		end = lex::prevloc(lexer),
		expr = lit,
	};
};

fn binding(lexer: *lex::lexer) (ast::expr | error) = {
	const loc = lex::mkloc(lexer);

	const tok = want(lexer, ltok::LET)?;
	const kind = switch (tok.0) {
	case ltok::LET =>
		yield ast::binding_kind::LET;
	case => abort(); // unreachable
	};

	let bindings: []ast::binding = [];
	for (true) {
		const (tok, value, _) = want(lexer, ltok::NAME)?;
		const name = switch (tok) {
		case ltok::NAME =>
			yield value as str;
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
			is_static = false,
			kind = kind,
			bindings = bindings,
		},
	};
};
