
Tambanokano
-----------

Tambanokano is a simple cross-language fractal viewer where a Rust library computes the Mandelbrot set and a LÖVE2D Lua frontend renders it interactively, with zooming, panning, and smooth animation.

The name [Tambanokano](https://www.aswangproject.com/tambanokano-tambanakaua/) comes from Mandaya folklore, referring to a giant crab known for swallowing its mother, the moon.

Installation
------------

## Install the dependecies

### On Arch Linux

```bash
sudo pacman -S rust love lua
```
### On Ubuntu/Debian

```bash
sudo apt install rustc cargo
sudo apt install lua5.4
sudo apt install love 
```

## Install Rust Dependencies

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup update
cargo install --force cbindgen
```

Usage
-----

After installing the dependencies, just run the `build` and `run` scripts

```bash
./build
./run
```

or

```bash
cargo build --release && love .
```

Repository Structure
--------------------

```
tambanokano/
├── Cargo.toml                 # Rust project config
├── src/
│   └── lib.rs                 # Rust fractal engine
├── main.lua                   # LÖVE2D main file
├── build                      # Build script
├── run                        # Run script  
├── README.md                  # Project documentation
└── .gitignore                 # Git ignore file
```
