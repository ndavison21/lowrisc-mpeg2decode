#include <stdio.h>
#include <string.h>

int ppm2raw(char filename_in[], char filename_out[]) {
    FILE *fp_in, *fp_out;
    char magicnum[3];
    unsigned char r, g, b, byte[2];
    unsigned int height, width, max;

    fp_in = fopen(filename_in,"r+");
    fp_out = fopen(filename_out,"w");

    if (fp_in == NULL) {
        perror("ERROR: Could not open input file\n");
        goto error;
    }

    if (fp_out == NULL) {
        perror("ERROR: Could not open output file\n");
        goto error;
    }

    fscanf(fp_in, "%s %d %d %d ", magicnum, &width, &height, &max);

    printf("Magic Number: %s\n", magicnum);
    printf("Width x Height: %d x %d\n", width, height);
    printf("Maximum Colour Value: %d\n", max);

    if (strcmp(magicnum, "P6") != 0 || max > 255) {
        perror("ERROR: could not process file: incorrect format.\n");
        goto error;
    }

    // Data starts here
    unsigned int i, j;
    for (i=0; i < height; ++i) {
        for (j = 0; j < width; ++j) {
            fread(&r, 1, 1, fp_in);
            fread(&g, 1, 1, fp_in);
            fread(&b, 1, 1, fp_in);

            byte[1] = (r & 0b11111000 ) | (g >> 5);
            byte[0] = ((g << 3) & 0b11100000) | (b >> 3);

            // printf("r: %u, g: %u, b: %u\n", r, g, b);
            // printf("byte 0: %u, byte 1: %u\n", byte[0], byte[1]);

            fwrite(byte, 1, 2, fp_out);
        }
    }

    fclose(fp_in);
    fclose(fp_out);

    return 0;

error: 
    fclose(fp_in);
    fclose(fp_out);
    return -1;
}

int main(int argc, char *argv[]) {
    if (argc != 3) {
        printf("Need 2 filenames\n");
        return 0;
    }
    ppm2raw(argv[1], argv[2]);
    return 0;
}