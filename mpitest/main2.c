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

#define MESSAGE_SIZE    (1024 * 1024 * 64)
#define RUN_COUNT       (10)
#define CONTROLLER_ADDRESS          "192.168.10.30"
#define CONTROLLER_RECV_BUF_SIZE    (1024)

int inmsg[MESSAGE_SIZE];
int outmsg[MESSAGE_SIZE] = {0};

unsigned int nlpo2(register unsigned int x)
{
    x |= (x >> 1);
    x |= (x >> 2);
    x |= (x >> 4);
    x |= (x >> 8);
    x |= (x >> 16);
    return  x+1;
}

int connect_controller()
{
    int sock;
    struct sockaddr_in sa;

    if ((sock = socket(AF_INET, SOCK_STREAM, 0)) < 0) {
        printf("Failed to open TCP socket.\n");
        exit(EXIT_FAILURE);
    }

    memset(&sa, 0, sizeof(sa));
    sa.sin_family = AF_INET;
    sa.sin_port = htons(2345);
    sa.sin_addr.s_addr = inet_addr(CONTROLLER_ADDRESS);

    if ((connect(sock, (struct sockaddr *)&sa, sizeof(struct sockaddr))) < 0) {
        printf("Failed to connect to SDN MPI controller\n");
        exit(EXIT_FAILURE);
    }

    return sock;
}

void close_controller(int sock)
{
    close(sock);
}

void notify_controller(int sock, const char* format, ...)
{
    char buf[CONTROLLER_RECV_BUF_SIZE];
    va_list arg;

    va_start(arg, format);
    vsprintf(buf, format, arg);
    va_end(arg);

    write(sock, buf, strlen(buf));
    read(sock, buf, CONTROLLER_RECV_BUF_SIZE);

}

void install_allreduce_rules(int sock, int size, int begin)
{
    int i, distance, remote;
    int rank_map[32];
    int adjsize = nlpo2(size) >> 1;
    int extra_ranks = size - adjsize;
    char *cmd = begin ? "begin_mpi_send" : "end_mpi_send";

    for (i = 0; i < size; i++) {
        if (i < (2 * extra_ranks)) {
            if (0 == (i % 2)) {
                notify_controller(sock, "%s %d %d\n", cmd, i, i + 1);
            } else {
                rank_map[i >> 1] = i;
            }
        } else {
            rank_map[i - extra_ranks] = i;
        }
    }

    for (distance = 1; distance < adjsize; distance <<= 1) {
        for (i = 0; i < adjsize; i++) {
            remote = i ^ distance;

            if (rank_map[i] < rank_map[remote]) {
                notify_controller(sock, "%s %d %d\n", cmd, rank_map[i], rank_map[remote]);
            }
        }
    }
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
            int sock = connect_controller();
            notify_controller(sock, "mpi_init %d %s\n", rank, addrstr);
            close_controller(sock);
        }
    }

    freeifaddrs(ifa_list);
}

int SDN_MPI_Allreduce(void *sendbuf, void *recvbuf, int count, MPI_Datatype datatype, MPI_Op op, MPI_Comm comm)
{
    int rank, size, i, remote, distance, sock;
    MPI_Comm_rank(comm, &rank);
    MPI_Comm_size(comm, &size);

    if (rank == 0) {
        sock = connect_controller();

        install_allreduce_rules(sock, size, 1);
    }

    MPI_Allreduce(sendbuf, recvbuf, count, datatype, op, comm);

    if (rank == 0) {
        install_allreduce_rules(sock, size, 0);

        close_controller(sock);
    }
}

void run_allreduce()
{
    int rank;
    int i;
    int tag = 1;
    int count = sizeof(outmsg) / sizeof(int);
    MPI_Status stat;

    MPI_Comm_rank(MPI_COMM_WORLD, &rank);

    memset(inmsg, 0, MESSAGE_SIZE);
    memset(outmsg, 0, MESSAGE_SIZE);

    SDN_MPI_Allreduce(inmsg, outmsg, count, MPI_INT, MPI_SUM, MPI_COMM_WORLD);
}

int main(int argc,char *argv[])
{
    int i;
    int rank;

    SDN_MPI_Init(&argc,&argv);
    MPI_Barrier(MPI_COMM_WORLD);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);

    float start_time = (float)clock() / CLOCKS_PER_SEC;
    
    for (i = 0; i < RUN_COUNT; i++) {
        run_allreduce();
    }

    float end_time = (float)clock() / CLOCKS_PER_SEC;
    float elapsed_time = end_time - start_time;

    if (rank == 0) {
        printf("Runned %d times, average: %f[s]\n", RUN_COUNT, elapsed_time / RUN_COUNT);
    }

    MPI_Finalize();
    return 0;
}
