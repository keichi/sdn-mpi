/*\
 *  pingpong.c -- hcc pingpong.c -o pingpong [-lmpi]
 *
 *  this program does just as the name suggests -- pingpongs a message
 *  between two MPI nodes. 
 *
 * Written by Pete Rijks <prijks@nd.edu> for LAM performance testing
 *
\*/

#include <stdlib.h>
#include <stdio.h>
#include "mpi.h"
#include <sys/time.h>

/* max message size to test */
#define MAXCOUNT (1048576 * 8)

/* number of tests per message size */
#define NUMTESTS 50

/* number of initial test per message size to discard results from */
#define IGNORE 10

typedef unsigned long long int pptimer_t;

#ifdef __GNUC__
__inline__
#endif
pptimer_t rdtsc();

int
main(int argc, char **argv)
{
  int i, j, rank, size;
  int to, from, tag;
  int count;
  pptimer_t total, timer_begin, timer_end, timer_diff, avg;
  pptimer_t *avgs;
  char *message;
  MPI_Status status;

  MPI_Init(&argc,&argv);
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);
  MPI_Comm_size(MPI_COMM_WORLD, &size);

  avgs = (pptimer_t*) malloc (24 * sizeof(pptimer_t));
  message = (char*) malloc (MAXCOUNT * sizeof(char));

  from = 1 - rank;
  to = 1 - rank;
  tag = 666;

  if (rank == 0) {
    for (count = 1, j = 0; count <= MAXCOUNT; count*=2, j++) {
      fprintf(stderr,"%10d",count);
      MPI_Barrier(MPI_COMM_WORLD);
      total = 0;
      for (i = 0; i < NUMTESTS; i++) {
	fprintf(stderr,".");
	timer_begin = rdtsc();
	MPI_Send(message, count, MPI_CHAR, to, tag, MPI_COMM_WORLD);
	MPI_Recv(message, count, MPI_CHAR, from, tag, MPI_COMM_WORLD, &status);
	timer_end = rdtsc();
	timer_diff = timer_end - timer_begin;
	if (i > IGNORE)
	  total += timer_diff;
      }
      fprintf(stderr,"\n");
      avg = total / (NUMTESTS - IGNORE);
      avgs[j] = avg;
    }

    /* output is matlab-friendly */
    printf("x = [ ");
    for (count = 1; count <= MAXCOUNT; count*=2)
      printf("%d ",count);
    printf("]; \ncycles = [ ");
    for (i = 0; i < j; i++) {

      /* grr... why can't long long ints print out the same everywhere? */
#ifdef __GNUC__
      printf("%Ld ",avgs[i]);
#else
      printf("%lld ",avgs[i]);
#endif

    }
    printf("];\n");
    printf("loglog(x,cycles,'x-');\n");
  } else if (rank == 1) {
    for (count = 1; count <= MAXCOUNT; count*=2) {
      MPI_Barrier(MPI_COMM_WORLD);
      for (i = 0; i < NUMTESTS; i++) {
	MPI_Recv(message, count, MPI_CHAR, from, tag, MPI_COMM_WORLD, &status);
	MPI_Send(message, count, MPI_CHAR, to, tag, MPI_COMM_WORLD);
      }
    }
  } else {
    /* no point in running this on more than two nodes... */
    fprintf(stderr,"notice: pingpong requires only two nodes to run on.\n");
    /* but if somebody does run it on more than two -- it'll hang *
     * if the other nodes don't participate in MPI_Barrier's...   */
    for (count = 1; count <= MAXCOUNT; count*=2)
      MPI_Barrier(MPI_COMM_WORLD);
  }


  /* clean up */
  fflush(stdout);

  free(avgs);
  free(message);

  MPI_Finalize();
  return 0;
}


/* hi-res timing -- the asm below returns the number of instructions executed 
 * since system boot up. Pretty hi-res if you ask me. x86-only, tho.
 * on suns we use gethrtime (get high resolution time) instead...
 */
#ifdef __GNUC__
__inline__ 
#endif
pptimer_t rdtsc()
{
  pptimer_t x;
#ifdef __GNUC__
  __asm__ volatile (".byte 0x0f, 0x31" : "=A" (x));
#else
  x = gethrtime();
#endif
  return x;
}
