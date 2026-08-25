#include <stdio.h>

extern int asm_bot_main(char **envp);
extern int secure_transport_init(void);
extern void secure_gateway_close(void);

int main(int argc, char **argv, char **envp) {
    (void)argc;
    (void)argv;
    if (secure_transport_init() != 0) {
        fputs("caine-asm: secure transport initialization failed\n", stderr);
        return 70;
    }
    int result = asm_bot_main(envp);
    secure_gateway_close();
    return result;
}
