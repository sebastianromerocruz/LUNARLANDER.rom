<h1 align=center>Lunar Lander</h1>

<h3 align=center><em>A CS3113 Assignment Ported to Real Game Boy Hardware</em></h3>

<p align=center>
    <a href="https://gbdev.io/gb-asm-tutorial/part1/assembly.html"><img src="https://img.shields.io/badge/Language-gbZ80-494786"></img></a>
    <a href="https://rgbds.gbdev.io/"><img src="https://img.shields.io/badge/Toolchain-RGBDS-8bac0f"></img></a>
    <a href="https://sameboy.github.io/"><img src="https://img.shields.io/badge/Emulator-SameBoy-306230"></img></a>
    <a href="https://zed.dev/"><img src="https://img.shields.io/badge/IDE-Zed-084CCF"></img></a>
</p>

A Game Boy ROM, hand-written in SM83 assembly (RGBDS), recreating the **CS-UY 3113: Intro to Game Programming** (NYU Tandon) Lunar Lander assignment—normally built in C++/raylib—on real hardware constraints instead: no floats, no engine, fixed-point physics, and manual sprite/collision code.

---

### _Sections_

1. [**Project Structure**](#project-structure)
2. [**Requirements**](#requirements)
3. [**Building**](#building)
4. [**Controls**](#controls)
5. [**Resources**](#resources)

---

### _Project Structure_

```
src/
├── hardware.inc ; standard RGBDS hardware register/constant definitions
└── main.asm     ; entry point, interrupt vectors, physics, game logic
```

<br>

### _Requirements_

- Player falls under a constant gravity acceleration.
- Left/right input changes acceleration, not velocity directly, so the ship drifts before coming to a stop.
- Touching an unsafe part of the terrain ends the game with a "mission failed" message.
- Touching a landing pad ends the game with a "mission accomplished" message.

<br>

### _Building_

Requires [**RGBDS**](https://rgbds.gbdev.io/).

```bash
make        # assemble build/lunarlander.gb
make run    # build and open in SameBoy
make clean  # remove build artifacts
```

<br>

### _Controls_

| Button | Action        |
|--------|---------------|
| Left   | Accelerate left  |
| Right  | Accelerate right |

<br>

### _Resources_

- [**gb-asm-tutorial**](https://gbdev.io/gb-asm-tutorial/): primary source for RGBDS/SM83 basics
- [**Pan Docs**](https://gbdev.io/pandocs/): the Game Boy hardware bible
- [**RGBDS Documentation**](https://rgbds.gbdev.io/docs/)
- [**SameBoy**](https://sameboy.github.io/): emulator/debugger used throughout development
