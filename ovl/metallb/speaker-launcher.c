#include <unistd.h>

int main(int argc, char* argv[])
{
	char hostname[64];
	gethostname(hostname, sizeof(hostname));	
	return execl(
		"/bin/speaker", "/bin/speaker", "--node-name", hostname, (char*)0);
}
