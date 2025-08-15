.PHONY: all run build clean

TARGET = target/release/libtambanokano.so
GREEN = "$(shell tput setaf 40)"
SGR = "$(shell tput sgr0)"

all: run

build: $(TARGET)

$(TARGET):
	@echo "building Rust library..."
	cargo build --release
	@echo $(GREEN)"Rust library built successfully at $(shell pwd)/$@"$(SGR)
	@ls -la $@

run: build
	@echo "Launching LÖVE2D application..."
	love .

case-study: build
	@echo "Running case study..."
	love . --case-study

clean:
	@cargo clean

help:
	@echo "Usage:"
	@echo "  make run    		build the Rust library and launch the game"
	@echo "  make build  		build only the Rust library"
	@echo "  make clean  		remove all build artifacts"
