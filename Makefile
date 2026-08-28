ROM = build/lunarlander.gb
SRC = src/main.asm

.PHONY: all clean run

all: $(ROM)

$(ROM): $(SRC) src/hardware.inc
	rgbasm -I src -o build/main.o $(SRC)
	rgblink -o $(ROM) build/main.o
	rgbfix -v -p 0xFF -t "LUNARLANDER" $(ROM)

run: $(ROM)
	open -a "SameBoy" $(ROM)

clean:
	rm -f build/*.o $(ROM)
