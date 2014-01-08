#include <mpi.h>
#include <stdio.h>
#include <time.h>
#include <unistd.h>

#define MESSAGE_SIZE    (1024 * 1024 * 32)
#define MESSAGE_COUNT   (32)
#define RUN_COUNT       (3)

char inmsg[MESSAGE_SIZE];
char outmsg[MESSAGE_SIZE] = {0};

void run_send_recv()
{
    int rank;
    int i;
    int tag = 1;
    int count = sizeof(outmsg) / sizeof(char);
    MPI_Status stat;

    MPI_Comm_rank(MPI_COMM_WORLD, &rank);

    switch (rank) {
        case 0:
        for (i = 0; i < MESSAGE_COUNT; i++) MPI_Send(outmsg, count, MPI_CHAR, 2, tag, MPI_COMM_WORLD);
        break;
        case 1:
        for (i = 0; i < MESSAGE_COUNT; i++) MPI_Send(outmsg, count, MPI_CHAR, 3, tag, MPI_COMM_WORLD);
        break;
        case 2:
        for (i = 0; i < MESSAGE_COUNT; i++) MPI_Recv(inmsg, count, MPI_CHAR, 0, tag, MPI_COMM_WORLD, NULL);
        break;
        case 3:
        for (i = 0; i < MESSAGE_COUNT; i++) MPI_Recv(inmsg, count, MPI_CHAR, 1, tag, MPI_COMM_WORLD, NULL);
        break;
    }

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
        run_send_recv();
    }

    float end_time = (float)clock() / CLOCKS_PER_SEC;
    float elapsed_time = end_time - start_time;

    if (rank == 0) {
        printf("Runned %d times, average: %f[s]\n", RUN_COUNT, elapsed_time / RUN_COUNT);
    }

    MPI_Finalize();
    return 0;
}
