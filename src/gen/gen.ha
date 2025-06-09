use fmt;
use hare::lex;
use hare::lex::{ltok};
use hare::ast;
use hash;
use hash::fnv;
use parse;
use io;
use memio;
use strings;

export type error = !(lex::location, str);

type var_map = struct {
	buckets: [64][]variable,
};

type variable = struct {
	hash: u32,
	name: str,
	offs: int,
};

let stack_depth: int = 0;
let base_depth: int = 0;
let if_cntr: int = 0;
let for_cntr: int = 0;
let branch_returned: bool = false;
let is_main: bool = false;

const word_size: int  = 4;

fn name_hash(name: str) u32 = {
	let hash = hash::fnv::string32(name);
	return hash;
};

fn insert_to_map(map: *var_map, ident: ast::ident, offs: int = 0) void = {
	let hash = name_hash(ident[0]);
	let bucket = &map.buckets[hash % len(map.buckets)];
	for (let i = 0z; i < len(*bucket); i += 1) {
		if (bucket[i].hash == hash) {
			return;
		};
	};

	let new = variable {
		hash = hash,
		name = ident[0],
		offs = offs,
	};

	append(bucket, new);
};

fn search_in_map(map: var_map, ident: ast::ident) (variable | void) = {
	let hash = name_hash(ident[0]);
	let bucket = map.buckets[hash % len(map.buckets)];
	for (let i = 0z; i < len(bucket); i += 1) {
		if (bucket[i].hash == hash) {
			return bucket[i];
		};
	};

};

fn copy_map(map: *var_map) (*var_map | error) = {
	let new_buckets: [64][]variable = [[]...];
	let new_map = var_map {buckets = new_buckets};

	for (let i = 0z; i < len(map.buckets); i += 1) {
		for (let variable .. map.buckets[i]) {
			let new_variable = alloc(variable);
			append(new_map.buckets[i], *new_variable);
		};
	};

	return alloc(new_map);
};

export fn gen(decls: []ast::decl) (bool | error) = {
	let buckets: [64][]variable = [[]...];
	let scope = alloc(var_map {buckets = buckets});

	for (let decl .. decls) {
		match (decl.decl) {
		case let dec_fn: ast::decl_func =>
			gen_fn(dec_fn, scope)?;
		case => void;
		};
	};

	return true;
};

fn gen_fn(decl: ast::decl_func, scope: *var_map) (bool | error) = {
	let name = decl.ident[0];

	is_main = false;

	if (name == "main") {
		is_main = true;
		fmt::printfln(".global _start\n_start:")!;
	} else {
		fmt::printfln(".global _{}\n_{}:", name, name)!;
	};

	fmt::printfln("\taddi sp, sp, -{}", word_size)!;
	fmt::println("\tsw ra, 0(sp)")!;

	let inner_scope = copy_map(scope)?;
	base_depth = stack_depth;

	let i: int = 0;
	// For now, only really handle one parameter :/
	for (let param .. (decl.prototype.repr as ast::func_type).params) {
		let ident: []str = [param.name];
		if (search_in_map(*scope, ident) is variable) {
			abort("Variable already defined in this scope");
		};

		stack_depth -= word_size;
		insert_to_map(inner_scope, ident, stack_depth);

		fmt::printfln("\taddi sp, sp, -{}", word_size)!;
		fmt::printfln("\tsw a{}, 0(sp)", i)!;
		i += 1;
	};


	if (decl.body != null) {
		gen_expr(*(decl.body as *ast::expr), inner_scope)?;
	};


	return true;
};

fn gen_expr(expr: ast::expr, scope: *var_map) (bool | error) = {
	match (expr.expr) {
	case let ex: ast::compound_expr =>
		gen_compound_expr(ex, scope)?;
	case let ex: ast::return_expr =>
		gen_return_expr(ex, scope)?;
	case let ex: ast::number_literal =>
		gen_number_literal(ex)?;
	case let ex: ast::binarithm_expr =>
		gen_binarithm_expr(ex, scope)?;
	case let ex: ast::binding_expr =>
		gen_binding_expr(ex, scope)?;
	case let ex: ast::assign_expr =>
		gen_assign_expr(ex, scope)?;
	case let ex: ast::if_expr =>
		gen_if_expr(ex, scope)?;
	case let ex: ast::for_expr =>
		gen_for_expr(ex, scope)?;
	case let ex: ast::access_identifier =>
		gen_access_identifier(ex, scope)?;
	case let ex: ast::access_identifier =>
		gen_access_identifier(ex, scope)?;
	case let ex: ast::call_expr =>
		gen_call_expr(ex, scope)?;
	case => return (expr.start, "Expression type not implemented");
	};

	return true;
};

fn gen_call_expr(ex: ast::call_expr, scope: *var_map) (bool | error) = {
	for (let i = 0z; i < len(ex.args); i += 1) {
		gen_expr(*ex.args[i], scope)?;
		fmt::printfln("\tmv a{}, t0", i)!;
	};

	match (ex.lvalue.expr) {
	case let id: ast::access_identifier =>
		fmt::printfln("\tjal _{}", id[0])!;
		fmt::printfln("\tmv t0, a0")!;
	case => return (ex.lvalue.start, "Error while generating code for function_call");
	};

	return true;
};

fn gen_for_expr(ex: ast::for_expr, scope: *var_map) (bool | error) = {
	let old_depth = stack_depth;
	let inner_scope = copy_map(scope)?;
	let old_cntr = for_cntr;

	if (ex.bindings != null) {
		gen_expr(*(ex.bindings as *ast::expr), inner_scope)?;
	};

	fmt::printfln("for_cond_{}:", old_cntr)!;

	if (ex.cond != null) {
		gen_expr(*(ex.cond as *ast::expr), inner_scope)?;
		fmt::println("\n\tli t2, 1")!;
		fmt::printfln("\tblt t0, t2, for_end_{}\n", old_cntr)!;
	};

	gen_expr(*ex.body, inner_scope)?;
	fmt::println("")!;


	if (ex.afterthought != null) {
		gen_expr(*(ex.afterthought as *ast::expr), inner_scope)?;
	};

	fmt::printfln("\tj for_cond_{}", old_cntr)!;

	fmt::printfln("for_end_{}:", old_cntr)!;

	fmt::printfln("\taddi sp, sp, {}", old_depth - stack_depth)!;
	stack_depth = old_depth;

	for_cntr += 1;
	return true;
};

fn gen_if_expr(ex: ast::if_expr, scope: *var_map) (bool | error) = {
	let old_cntr = if_cntr;

	gen_expr(*ex.cond, scope)?;
	let old_depth = stack_depth;
	fmt::printfln("\tli t2, 1 # STACK =========== {}", stack_depth)!;
	fmt::printfln("\tblt t0, t2, fbranch_{}", old_cntr)!;

	// Handle tbranch
	gen_expr(*ex.tbranch, scope)?;

	if (ex.fbranch != null) {
	    fmt::printfln("\tj tbranch_end_{}", old_cntr)!;
	};


	stack_depth = old_depth;
	fmt::printfln("fbranch_{}:\n\t# stack ================ {}", old_cntr, stack_depth)!;
	if (ex.fbranch != null) {
		old_depth = stack_depth;
		gen_expr(*(ex.fbranch as *ast::expr), scope)?;
		fmt::printfln("tbranch_end_{}:\n\t# stack =================== {}", old_cntr, stack_depth)!;
		stack_depth = old_depth;
	};

	if_cntr += 1;

	return true;
};

fn gen_assign_expr(ex: ast::assign_expr, scope: *var_map) (bool | error) = {
	match (ex.object.expr) {
	case let lhs: ast::access_identifier =>

		match (search_in_map(*scope, lhs)) {
		case let v: variable => 
			match (ex.op) {
			case ast::binarithm_op =>
				let val = alloc(ast::binarithm_expr {
					op = ex.op as ast::binarithm_op,
					lvalue = ex.object,
					rvalue = ex.value,
				});
				gen_binarithm_expr(*val, scope)?;
			case void =>
				gen_expr(*ex.value, scope)?;
			};


			fmt::printfln("\tsw t0, {}(sp) # storing in {}\n", v.offs - stack_depth, lhs[0])!;
		
		case void => 
			abort("Variable undefined in this scope");
		};
	};

	return true;
};

fn gen_access_identifier(ex: ast::access_identifier, scope: *var_map) (bool | error) = {
	match (search_in_map(*scope, ex)) {
	case let v: variable => 
		fmt::printfln("\tlw t0, {}(sp) # access {}", v.offs - stack_depth, ex[0])!;
	case void => 
		abort("Variable undefined in this scope");
	};

	return true;
};

fn gen_binding_expr(expr: ast::binding_expr, scope: *var_map) (bool | error) = {
	for (let binding .. expr.bindings) {
		gen_binding(binding, scope)?;
	};

	return true;
};

fn gen_binding(binding: ast::binding, scope: *var_map) (bool | error) = {
	let ident: []str = [binding.name as str];
	if (search_in_map(*scope, ident) is variable) {
		abort("Variable already defined in this scope");
	};

	gen_expr(*binding.init, scope)?;

	stack_depth -= word_size;
	insert_to_map(scope, ident, stack_depth);

	fmt::printfln("\taddi sp, sp, -{}", word_size)!;
	fmt::println("\tsw t0, 0(sp)\n")!;

	return true;
};

fn gen_compound_expr(expr: ast::compound_expr, scope: *var_map) (bool | error) = {
	let old_depth = stack_depth;
	let inner_scope = copy_map(scope)?;
	for (let ex .. expr.exprs) {
		gen_expr(*ex, inner_scope)?;
	};

	if (!branch_returned) {
		fmt::printfln("\taddi sp, sp, {} # Finishing compound expr", old_depth - stack_depth)!;
		stack_depth = old_depth;
	};
	branch_returned = false;

	return true;
};

fn gen_return_expr(expr: ast::return_expr, scope: *var_map) (bool | error) = {
	match (expr) {
	case let ex: *ast::expr =>
		gen_expr(*ex, scope)?;
		fmt::printfln("\taddi sp, sp, {} # FINISHING RETURN", base_depth - stack_depth)!;
		stack_depth = base_depth;

		fmt::println("\tmv a0, t0 # HOLA A TODOS")!;
	case => void;
	};

	fmt::println("\tsw ra, 0(sp)")!;
	fmt::printfln("\taddi sp, sp, {}", word_size)!;

	if (is_main) {
	    fmt::println("\n\taddi a7, x0, 93\n\tecall")!;
	} else {
	    fmt::println("\tret")!;
	};

	branch_returned = true;
	return true;
};

fn gen_number_literal(expr: ast::number_literal) (bool | error) = {
	fmt::printfln("\tli t0, {}", expr.value)!;
	return true;
};

fn gen_binarithm_expr(expr: ast::binarithm_expr, scope: *var_map) (bool | error) = {
	switch (expr.op) {
	case ast::binarithm_op::PLUS =>
		gen_sum_expr(expr, scope)?;
	case ast::binarithm_op::MINUS =>
		gen_sub_expr(expr, scope)?;
	case ast::binarithm_op::TIMES =>
		gen_mul_expr(expr, scope)?;
	case ast::binarithm_op::LEQUAL =>
		gen_equal_expr(expr, scope)?;
	case ast::binarithm_op::LESS =>
		gen_less_expr(expr, scope)?;
	case ast::binarithm_op::LESSEQ =>
		gen_lesseq_expr(expr, scope)?;
	case ast::binarithm_op::GT =>
		gen_gt_expr(expr, scope)?;
	case ast::binarithm_op::GTEQ =>
		gen_gteq_expr(expr, scope)?;
	case ast::binarithm_op::NEQUAL =>
		gen_nequal_expr(expr, scope)?;
	case ast::binarithm_op::LAND =>
		gen_land_expr(expr, scope)?;
	case ast::binarithm_op::LOR =>
		gen_lor_expr(expr, scope)?;
	case => abort("Operator no implemented");
	};

	return true;
};

fn gen_lor_expr(expr: ast::binarithm_expr, scope: *var_map) (bool | error) = {
	gen_expr(*(expr.lvalue), scope)?;

	// push to stack
	fmt::println("\taddi sp, sp, -4")!;
	fmt::println("\tsw t0, 0(sp)")!;
	stack_depth -= word_size;

	gen_expr(*(expr.rvalue), scope)?;

	// pop from stack
	fmt::println("\tlw t1, 0(sp)")!;
	fmt::println("\taddi sp, sp, 4")!;
	stack_depth += word_size;

	fmt::printfln("\tor t0, t0, t1")!;

	return true;
};

fn gen_land_expr(expr: ast::binarithm_expr, scope: *var_map) (bool | error) = {
	gen_expr(*(expr.lvalue), scope)?;

	// push to stack
	fmt::println("\taddi sp, sp, -4")!;
	fmt::println("\tsw t0, 0(sp)")!;
	stack_depth -= word_size;

	gen_expr(*(expr.rvalue), scope)?;

	// pop from stack
	fmt::println("\tlw t1, 0(sp)")!;
	fmt::println("\taddi sp, sp, 4")!;
	stack_depth += word_size;

	fmt::printfln("\tand t0, t0, t1")!;

	return true;
};

fn gen_nequal_expr(expr: ast::binarithm_expr, scope: *var_map) (bool | error) = {
	gen_equal_expr(expr, scope)?;
	fmt::println("\tslti t0, t0, 1")!;

	return true;
};

fn gen_gteq_expr(expr: ast::binarithm_expr, scope: *var_map) (bool | error) = {
	gen_expr(*(expr.lvalue), scope)?;

	// push to stack
	fmt::println("\taddi sp, sp, -4")!;
	fmt::println("\tsw t0, 0(sp)")!;
	stack_depth -= word_size;

	gen_expr(*(expr.rvalue), scope)?;

	// pop from stack
	fmt::println("\tlw t1, 0(sp)")!;
	fmt::println("\taddi sp, sp, 4")!;
	stack_depth += word_size;

	fmt::println("\taddi t1, t1, 1")!;
	fmt::printfln("\tslt t0, t0, t1")!;

	return true;
};

fn gen_gt_expr(expr: ast::binarithm_expr, scope: *var_map) (bool | error) = {
	gen_expr(*(expr.lvalue), scope)?;

	// push to stack
	fmt::println("\taddi sp, sp, -4")!;
	fmt::println("\tsw t0, 0(sp)")!;
	stack_depth -= word_size;

	gen_expr(*(expr.rvalue), scope)?;

	// pop from stack
	fmt::println("\tlw t1, 0(sp)")!;
	fmt::println("\taddi sp, sp, 4")!;
	stack_depth += word_size;

	fmt::printfln("\tslt t0, t0, t1")!;

	return true;
};

fn gen_lesseq_expr(expr: ast::binarithm_expr, scope: *var_map) (bool | error) = {
	gen_expr(*(expr.lvalue), scope)?;

	// push to stack
	fmt::println("\taddi sp, sp, -4")!;
	fmt::println("\tsw t0, 0(sp)")!;
	stack_depth -= word_size;

	gen_expr(*(expr.rvalue), scope)?;

	// pop from stack
	fmt::println("\tlw t1, 0(sp)")!;
	fmt::println("\taddi sp, sp, 4")!;
	stack_depth += word_size;

	fmt::println("\taddi t0, t0, 1")!;
	fmt::printfln("\tslt t0, t1, t0")!;

	return true;
};

fn gen_less_expr(expr: ast::binarithm_expr, scope: *var_map) (bool | error) = {
	gen_expr(*(expr.lvalue), scope)?;

	// push to stack
	fmt::println("\taddi sp, sp, -4")!;
	fmt::println("\tsw t0, 0(sp)")!;
	stack_depth -= word_size;

	gen_expr(*(expr.rvalue), scope)?;

	// pop from stack
	fmt::println("\tlw t1, 0(sp)")!;
	fmt::println("\taddi sp, sp, 4")!;
	stack_depth += word_size;

	fmt::printfln("\tslt t0, t1, t0")!;

	return true;
};

fn gen_equal_expr(expr: ast::binarithm_expr, scope: *var_map) (bool | error) = {
	gen_expr(*(expr.lvalue), scope)?;

	// push to stack
	fmt::println("\taddi sp, sp, -4")!;
	fmt::println("\tsw t0, 0(sp)")!;
	stack_depth -= word_size;

	gen_expr(*(expr.rvalue), scope)?;

	// pop from stack
	fmt::println("\tlw t1, 0(sp)")!;
	fmt::println("\taddi sp, sp, 4")!;
	stack_depth += word_size;

	fmt::printfln("\tsub t1, t1, t0")!;
	fmt::printfln("\tseqz t0, t1")!;

	return true;
};

fn gen_sum_expr(expr: ast::binarithm_expr, scope: *var_map) (bool | error) = {
	gen_expr(*(expr.lvalue), scope)?;

	// push to stack
	fmt::println("\taddi sp, sp, -4")!;
	fmt::println("\tsw t0, 0(sp)")!;
	stack_depth -= word_size;

	gen_expr(*(expr.rvalue), scope)?;

	// pop from stack
	fmt::println("\tlw t1, 0(sp)")!;
	fmt::println("\taddi sp, sp, 4")!;
	stack_depth += word_size;

	fmt::printfln("\tadd t0, t1, t0")!;

	return true;
};

fn gen_sub_expr(expr: ast::binarithm_expr, scope: *var_map) (bool | error) = {
	gen_expr(*(expr.lvalue), scope)?;

	// push to stack
	fmt::println("\taddi sp, sp, -4")!;
	fmt::println("\tsw t0, 0(sp)")!;
	stack_depth -= word_size;

	gen_expr(*(expr.rvalue), scope)?;

	// pop from stack
	fmt::println("\tlw t1, 0(sp)")!;
	fmt::println("\taddi sp, sp, 4")!;
	stack_depth += word_size;

	// t0 = t1 - t0
	fmt::printfln("\tsub t0, t1, t0")!;

	return true;
};

fn gen_mul_expr(expr: ast::binarithm_expr, scope: *var_map) (bool | error) = {
	gen_expr(*(expr.lvalue), scope)?;

	// push to stack
	fmt::println("\taddi sp, sp, -4")!;
	fmt::println("\tsw t0, 0(sp)")!;
	stack_depth -= word_size;

	gen_expr(*(expr.rvalue), scope)?;

	// pop from stack
	fmt::println("\tlw t1, 0(sp)")!;
	fmt::println("\taddi sp, sp, 4")!;
	stack_depth += word_size;

	// t0 = t1 * t0
	fmt::printfln("\tmul t0, t1, t0")!;

	return true;
};
