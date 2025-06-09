fn foo(x: int, y: int) int = {
	let iter = 0;
	if (x < 10) {
		iter = 10;
	} else {
		iter = 5;
	};

	let acum = 0;
	for (let i = 1; i <= iter; i += 1) {
		acum += i;
	};

	return acum - y;
};

fn main() int = {
	let x = foo(4, 50);
	return x;
};

