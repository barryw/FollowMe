KICK=kickass

followme.prg: followme.asm
	$(KICK) followme.asm -vicesymbols -bytedump -debugdump

run: clean followme.prg
	x64sc followme.prg

clean:
	rm -f followme.prg
