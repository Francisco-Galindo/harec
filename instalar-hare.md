 Instalando `hare`

Ejecuta los siguientes comandos para instalar el *toolchain* de `hare` en tu computadora con linux. Aqui se asume que se está utilizando un sistema Linux basado en Debian (como Ubuntu, Linux Mint, etc.).

Instala los paquetes necesarios para compilar todos los programas:
```sh
sudo apt update && sudo apt install wget git build-essential
```

Crea alguna carpeta donde guardar las cosas que vamos a clonar ahorita (puede borrarse cuando terminemos con la instalación):

```sh
# Esto es un ejemplo! Crea el directorio que tú quieras
mkdir /hola/soy/una/ruta/instalando-hare
```

Instala `qbe`

```sh
wget https://c9x.me/compile/release/qbe-1.2.tar.xz
tar -xf qbe-1.2.tar.xz
cd qbe-1.2
make
sudo make install
```

Prueba `qbe` con este comando:

```sh
qbe -h
```

Instala `scdoc`

```sh
# O el que tú hayas creado
cd /hola/soy/una/ruta/instalando-hare
git clone https://git.sr.ht/~sircmpwn/scdoc
cd scdoc/
make
sudo make install
```

Prueba `scdoc` con el comando`scdoc -h` y verás algo similar a esto:

```
$ scdoc -h
Usage: scdoc < input.scd > output.roff
```

Instala `harec`, el compilador de `hare`. Es buena idea reinstalar si ya estaba instalado antes:

```sh
# O el que tú hayas creado
cd /hola/soy/una/ruta/instalando-hare
git clone https://git.sr.ht/~sircmpwn/harec && cd harec
git checkout remotes/origin/v0.24.2
cp configs/linux.mk config.mk
make
make check
sudo make install
```

```
$ harec -v
harec
```

Instala `hare` y `haredoc`.  Es buena idea reinstalar si ya estaba instalado antes:

```sh
# O el que tú hayas creado
cd /hola/soy/una/ruta/instalando-hare
git clone https://git.sr.ht/~sircmpwn/hare && cd hare
git checkout remotes/origin/v0.24.2
cp configs/linux.mk config.mk
make
make check
sudo make install
```

Prueba `haredoc` y `hare`:

```
$ haredoc -h
haredoc: reads and formats Hare documentation

Usage: haredoc [-hat] [-F <format>] [-T <tagset>] [identifier|path]

...
```

```
$ hare version
hare
```

# Probando todo

Escribe este programa en un archivo llamado `main.ha`

```hare
use fmt;

export fn main() void = {
	const greetings = [
		"Hello, world!",
		"¡Hola Mundo!",
		"Γειά σου Κόσμε!",
		"Привіт, світе!",
		"こんにちは世界！",
	];
	for (let greeting .. greetings) {
		fmt::println(greeting)!;
	};
};
```

Ahora ejecuta

```sh
hare run main.ha
```

Y verás

```
Hello, world!
¡Hola Mundo!
Γειά σου Κόσμε!
Привіт, світе!
こんにちは世界！
```


# Instalando la toolchain para RISC-V 32

```sh
sudo apt install gcc-riscv64-linux-gnu
```

Para poder ejecutar los programas hechos para RISC-V en una computadora con otra arquitectura, puede utilizarse QEMU.

Así, el proceso de compilación se basa en ejecutar:

```
cd src/
hare run compile.ha -f <path al programa> > ../program.s
cd ..
make
qemu-riscv32 program
echo $?
```

