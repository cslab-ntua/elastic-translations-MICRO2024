
all: gups gups-st
gups: gups.c
	gcc -O3 -fopenmp -o $@ $<

gups-st: gups.c
	gcc -O3 -o $@ $<

clean:
	rm -f *.o *.a

