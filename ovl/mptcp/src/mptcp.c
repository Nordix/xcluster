#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <stdlib.h>
#include <netinet/in.h>
#include <unistd.h>
#include <netdb.h>
#include <time.h>

// Until defined
//#define IPPROTO_MPTCP 262

static void die(char const* msg)
{
	fprintf(stderr, "FATAL: %s\n", msg);
	exit(EXIT_FAILURE);
}

static void errquit(char const* msg)
{
	perror(msg);
	exit(EXIT_FAILURE);
}

static char const* timestamp(void)
{
	static char buff[32];
	time_t timer = time(NULL);
	struct tm* tm_info;
	tm_info = localtime(&timer);
	strftime(buff, sizeof(buff), "%H:%M:%S", tm_info);
	return buff;
}

static int write_all(int socket, char const* buffer, size_t length)
{
	char const* ptr = buffer;
	while (length > 0) {
		int i = write(socket, ptr, length);
		if (i < 1) return ptr - buffer;
		ptr += i;
		length -= i;
	}
	return ptr - buffer;
}

static void handle_client(int c)
{
	printf("%s: Client connected\n", timestamp());
	char buff[2048];
	int count = read(c, buff, sizeof(buff));
	while (count > 0) {
		if (write_all(c, buff, count) != count) errquit("write");
		count = read(c, buff, sizeof(buff));
	}
	close(c);
	printf("%s: Client disconnected\n", timestamp());
}

static int
mptcp_client(int argc, char* argv[])
{
	if (argc < 3) die("Address + port must be specified");
	int count=100000;
	if (argc > 3) count=atoi(argv[3]);
	struct addrinfo* addrs;
	int rc = getaddrinfo(argv[1], argv[2], NULL, &addrs);
	if (rc != 0) die(gai_strerror(rc));
	int sd = socket(addrs->ai_family, addrs->ai_socktype, IPPROTO_MPTCP);
	if (sd < 0) errquit("socket");
	if (connect(sd, addrs->ai_addr, addrs->ai_addrlen) != 0) errquit("connect");
	char buff[1024], rbuff[2048];
	memset(buff, 'X', sizeof(buff));
	while (count-- > 0) {
		if (write_all(sd, buff, sizeof(buff)) != sizeof(buff)) errquit("write");
		rc = read(sd, rbuff, sizeof(rbuff));
		if (rc < 0) errquit("read");
		if (rc == 0) die("Closed by server");
		printf("%s: Client write/read %zu/%d bytes...\n", timestamp(), sizeof(buff), rc);
		usleep(500000);
	}
	return 0;
}

int
mptcp_server(int argc, char* argv[])
{
	short int port = 7000;
	if (argc > 1) port = atoi(argv[1]);
	int sd = socket(AF_INET6, SOCK_STREAM, IPPROTO_MPTCP);
	if (sd < 0) errquit("socket");
	struct sockaddr_in6 sa;
	memset(&sa, 0, sizeof(sa));
	sa.sin6_family = AF_INET6;
	sa.sin6_port = htons(port);
	if (bind(sd, (struct sockaddr*)&sa, sizeof(sa)) < 0) errquit("bind");
	if (listen(sd, 64) != 0) errquit("listen");
	for (;;) {
		int c = accept(sd, NULL, NULL);
		if (c < 0) errquit("accept");
		handle_client(c);
	}
	return 0;
}

int
main(int argc, char* argv[])
{
	if (argc < 2) die("Syntax: mptcp server|client ...\n");
	char const* op = argv[1];
	argc -= 1;
	argv += 1;
	if (strcmp(op, "client") == 0) {
		return mptcp_client(argc, argv);
	}
	if (strcmp(op, "server") == 0) {
		return mptcp_server(argc, argv);
	}
	fprintf(stderr, "Unknown operation [%s]\n", op);
	return 1;
}
