#include <mpi.h>
#include <stdio.h>
#include <time.h>

char inmsg[1024 * 1024 * 50];
char outmsg[1024 * 1024 * 50] = {0};

int main(int argc,char *argv[])
{
    MPI_Init(&argc,&argv);

    int rank;
    MPI_Status stat;
    int i;
    int tag = 1;

    MPI_Comm_rank(MPI_COMM_WORLD, &rank);

    float start_time = (float)clock() / CLOCKS_PER_SEC;

    printf("Hello, world from node: %d!\n", rank);

    int count = sizeof(outmsg) / sizeof(char);

    for (i = 0; i < 5; i++) {
        switch (rank) {
            case 0:
            MPI_Send(outmsg, count, MPI_CHAR, 2, tag, MPI_COMM_WORLD);
            break;
            case 1:
            MPI_Send(outmsg, count, MPI_CHAR, 3, tag, MPI_COMM_WORLD);
            break;
            case 2:
            MPI_Recv(inmsg, count, MPI_CHAR, 0, tag, MPI_COMM_WORLD, NULL);
            break;
            case 3:
            MPI_Recv(inmsg, count, MPI_CHAR, 1, tag, MPI_COMM_WORLD, NULL);
            break;
        }
    }
    
    float end_time = (float)clock() / CLOCKS_PER_SEC;
    float elapsed_time = end_time - start_time;

    if (rank == 0) {
        printf("Elapsed time: %f\n", elapsed_time);
    }

    MPI_Finalize();
    return 0;
}
