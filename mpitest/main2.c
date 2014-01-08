#include <mpi.h>
#include <stdio.h>
#include <time.h>
#include <unistd.h>
#include <string.h>

#define MESSAGE_SIZE    (1024 * 1024 * 32)
#define RUN_COUNT       (3)

int inmsg[MESSAGE_SIZE];
int outmsg[MESSAGE_SIZE] = {0};

void run_reduce()
{
    int rank;
    int i;
    int tag = 1;
    int count = sizeof(outmsg) / sizeof(int);
    MPI_Status stat;

    MPI_Comm_rank(MPI_COMM_WORLD, &rank);

    memset(inmsg, 0, MESSAGE_SIZE);
    memset(outmsg, 0, MESSAGE_SIZE);

    MPI_Reduce(inmsg, outmsg, count, MPI_INT, MPI_SUM, 0, MPI_COMM_WORLD);

    MPI_Barrier(MPI_COMM_WORLD);
}

int main(int argc,char *argv[])
{
    int i;
    int rank;

    MPI_Init(&argc,&argv);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);

    float start_time = (float)clock() / CLOCKS_PER_SEC;
    
    for (i = 0; i < RUN_COUNT; i++) {
        run_reduce();
    }

    float end_time = (float)clock() / CLOCKS_PER_SEC;
    float elapsed_time = end_time - start_time;

    if (rank == 0) {
        printf("Runned %d times, average: %f[s]\n", RUN_COUNT, elapsed_time / RUN_COUNT);
    }

    MPI_Finalize();
    return 0;
}
