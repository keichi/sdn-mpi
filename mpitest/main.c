#include <mpi.h>
#include <stdio.h>
#include <time.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <netinet/in.h>

#define MESSAGE_SIZE    (1024 * 1024 * 32)
#define MESSAGE_COUNT   (32)
#define RUN_COUNT       (3)
#define CONTROLLER_ADDRESS  "/tmp/sdn-mpi.sock"
#define CONTROLLER_RECV_BUF_SIZE    (1024)

char inmsg[MESSAGE_SIZE];
char outmsg[MESSAGE_SIZE] = {0};

void notify_controller(const char* format, ...)
{
    int sock, len;
    struct sockaddr_un sa;
    char buf[CONTROLLER_RECV_BUF_SIZE];
    va_list arg;

    va_start(arg, format);
    vsprintf(buf, format, arg);
    va_end(arg);

    if ((sock = socket(AF_UNIX, SOCK_STREAM, 0)) < 0) {
        printf("Failed to open UNIX socket.\n");
        exit(EXIT_FAILURE);
    }

    sa.sun_family = AF_UNIX;
    strcpy(sa.sun_path, CONTROLLER_ADDRESS);
    len = sizeof(sa.sun_family) + strlen(sa.sun_path);

    if ((connect(sock, (struct sockaddr *)&sa, len)) < 0) {
        printf("Failed to connect to SDN MPI controller\n");
        exit(EXIT_FAILURE);
    }

    write(sock, buf, strlen(buf) + 1);
    read(sock, buf, CONTROLLER_RECV_BUF_SIZE);

    close(sock);
}

int SDN_MPI_Send(void *buf, int count, MPI_Datatype datatype, int dest, int tag, MPI_Comm comm)
{
    int rank;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);

    notify_controller("begin_mpi_send %d %d\n", rank, dest);

    MPI_Send(buf, count, datatype, dest, tag, comm);

    notify_controller("end_mpi_send\n");
}

int SDN_MPI_Init(int *argc, char ***argv)
{
    MPI_Init(argc, argv);

    int rank;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);

    struct ifaddrs *ifa_list, *ifa;
    char addrstr[256];

    if (getifaddrs(&ifa_list) < 0) {
        printf("Could not get interface addresses.\n");
        exit(EXIT_FAILURE);
    }

    for (ifa = ifa_list; ifa != NULL; ifa = ifa->ifa_next) {
        if (ifa->ifa_addr == NULL) {
            continue;
        }
        if (!(ifa->ifa_flags & IFF_UP) || (ifa->ifa_flags & IFF_LOOPBACK)) {
            continue;
        }

        if (ifa->ifa_addr->sa_family == AF_INET) {
            inet_ntop(
                AF_INET,
                &((struct sockaddr_in *)ifa->ifa_addr)->sin_addr,
                addrstr,
                sizeof(addrstr)
            );
            notify_controller("mpi_init %d %s\n", rank, addrstr);
        }
    }

    freeifaddrs(ifa_list);
}

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
        for (i = 0; i < MESSAGE_COUNT; i++) SDN_MPI_Send(outmsg, count, MPI_CHAR, 2, tag, MPI_COMM_WORLD);
        break;
        case 1:
        for (i = 0; i < MESSAGE_COUNT; i++) SDN_MPI_Send(outmsg, count, MPI_CHAR, 3, tag, MPI_COMM_WORLD);
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

    SDN_MPI_Init(&argc,&argv);
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
