# King's Valley (RC727, MSX)

This repository contains the fully annotated disassembly of the original King's Valley game, released by Konami for [MSX](https://en.wikipedia.org/wiki/MSX) in 1985 with code RC727. I hope you will find the code comments useful to understand how the game works.


## How to assemble

Use [Sjasm 0.39](https://github.com/Konamiman/Sjasm) or a compatible assembler:

    sjasm kvalley.asm kvalley.rom


## Version 1 vs Version 2

It is possible to build both versions by setting the `VERSION2` constant to 1 or 0 in the `kvalley.asm` file.
Version 2 fixes few bugs from the first version.



## Legal notice

This repository is provided "as is" for education purposes only. Any non-educational use of this repository might be illegal if you do not own an original copy of the game.

Also, the repository will be removed if Konami or their legal representatives ask me to do so.
