# include <stdio.h>

int main(int argc, char* argv[], char** env) {
    printf("# include <stdio.h>\n\nint main(int argc, char* argv[], char** env) {\n\tprintf(\"Hello World!\\n\");\n\treturn 0;\n}");
    printf("\n\n>>> gcc -O2 -s -flto -static -o HelloWorld.exe HelloWorld.c");
    printf("\n>>> upx -9 --force HelloWorld.exe");
    printf("\n>>> ./HelloWorld.exe");
    printf("\n>>> Hello World!");
    printf("\n\nPress enter to exit...\n");
    getchar();
    return 0;
}