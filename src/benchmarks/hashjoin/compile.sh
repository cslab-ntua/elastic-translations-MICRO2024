gcc -O3 -fopenmp -c murmurhash.c
gcc -O3 -fopenmp -c hashjoin.c
gcc -fopenmp hashjoin.o  murmurhash.o -o hashjoin
rm *.o
