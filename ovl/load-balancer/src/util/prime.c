#include <stdio.h>
#include <math.h>
#include <stdlib.h>


//static unsigned const nprimes = 167;
static unsigned const primes[] = {
  3,
  5,
  7,
  11,
  13,
  17,
  19,
  23,
  29,
  31,
  37,
  41,
  43,
  47,
  53,
  59,
  61,
  67,
  71,
  73,
  79,
  83,
  89,
  97,
  101,
  103,
  107,
  109,
  113,
  127,
  131,
  137,
  139,
  149,
  151,
  157,
  163,
  167,
  173,
  179,
  181,
  191,
  193,
  197,
  199,
  211,
  223,
  227,
  229,
  233,
  239,
  241,
  251,
  257,
  263,
  269,
  271,
  277,
  281,
  283,
  293,
  307,
  311,
  313,
  317,
  331,
  337,
  347,
  349,
  353,
  359,
  367,
  373,
  379,
  383,
  389,
  397,
  401,
  409,
  419,
  421,
  431,
  433,
  439,
  443,
  449,
  457,
  461,
  463,
  467,
  479,
  487,
  491,
  499,
  503,
  509,
  521,
  523,
  541,
  547,
  557,
  563,
  569,
  571,
  577,
  587,
  593,
  599,
  601,
  607,
  613,
  617,
  619,
  631,
  641,
  643,
  647,
  653,
  659,
  661,
  673,
  677,
  683,
  691,
  701,
  709,
  719,
  727,
  733,
  739,
  743,
  751,
  757,
  761,
  769,
  773,
  787,
  797,
  809,
  811,
  821,
  823,
  827,
  829,
  839,
  853,
  857,
  859,
  863,
  877,
  881,
  883,
  887,
  907,
  911,
  919,
  929,
  937,
  941,
  947,
  953,
  967,
  971,
  977,
  983,
  991,
  997,
  0};


#define Dx(x) x
#define D(x)

int isPrime(unsigned n)
{
	if (n == 2) return 1;
	if (n == 1 || (n & 1) == 0) return 0;
	unsigned m = (unsigned)(sqrt((double)n)) + 1;
	D(printf("Maxtry (%u)\n", m));
	unsigned int try = 1;
	for (unsigned const* p = primes; *p != 0; p++) {
		try = *p;
		if (try > m) {
			D(printf("Hit on pre-stored\n"));
			return 1;
		}
		if ((n % try) == 0) {
			D(printf("Miss on pre-stored\n"));
			return 0;
		}
	}
	// Pre-stored exausted
	try += 2;
	while (try <= m) {
		if ((n % try) == 0)
			return 0;
		try += 2;
	}
	return 1;
}


unsigned primeBelow(unsigned n)
{
	if (n < 4) return n;
	if ((n & 1) == 0)
		n--;
	while (!isPrime(n)) {
		n -= 2;
	}
	return n;
}

#if 0
void findprimes(unsigned h)
{
	for (unsigned i = 3; i <= h; i += 2) {
		if (isPrime(i)) {
			if (nprimes >= MAX)
				return;
			primes[nprimes++] = i;
		}
	}
}

void printPrimes(void)
{
	printf("static unsigned const nprimes = %u;\n", nprimes);
	printf("static unsigned const primes[] = {\n");
	for (unsigned i = 0; i < nprimes; i++) {
		printf("  %u,\n", primes[i]);
	}
	printf("  0}\n");
}

int
main(int argc, char* argv[])
{
	if (argc < 2)
		return 0;
	printf("%d\n", primeAround(atoi(argv[1])));
}
#endif
