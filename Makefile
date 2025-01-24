snake: snake.o
	ld -platform_version macos 10.15.0 11.0 -L/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib -L/usr/local/lib -lSystem -Z -no_pie -o snake snake.o
	strip snake
	wc -c snake

snake.o: snake.asm
	nasm -f macho64 snake.asm -o snake.o
