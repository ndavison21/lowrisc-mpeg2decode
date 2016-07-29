#include <stdio.h>

unsigned int clamp255(unsigned int in);

int yuv2rgb(char yfilename[], char ufilename[], char vfilename[]) {
    FILE *yfp, *ufp, *vfp, *fp;

    unsigned char byte1, byte2;
 
    yfp = fopen(yfilename,"r"); // read mode
    ufp = fopen(ufilename,"r"); // read mode
    vfp = fopen(vfilename,"r"); // read mode

    fp = fopen("rgbframe.raw", "w"); //write mode
 
    if (yfp == NULL) {
        perror("Error while opening the Y file.\n");
        return -1;
    }
    if (ufp == NULL) {
        perror("Error while opening the U file.\n");
        return -1;
    }
    if (vfp == NULL) {
        perror("Error while opening the V file.\n");
        return -1;
    }
 
    printf("The contents of %s, %s, and %s file are :\n", yfilename, ufilename, vfilename);
 
    unsigned int c, d, e, r, g, b;
    unsigned int y = fgetc(yfp);
    unsigned int u = fgetc(ufp);
    unsigned int v = fgetc(vfp);

    while ((y != EOF) && (u != EOF) && (v != EOF)) {
        printf("y: %u,  u: %u, v: %u\n", y, u, v);

        c = y - 16;
        d = u - 128;
        e = v - 128;

        r = clamp255(( 298 * c           + 409 * e + 128) >> 8);
        g = clamp255(( 298 * c - 100 * d - 208 * e + 128) >> 8);
        b = clamp255(( 298 * c + 516 * d           + 128) >> 8);

        printf("r: %u,  g: %u, b: %u\n", r, g, b);

        byte1 = (r & 0b11111000) | (g >> 5);
        byte2 = ((5 << 3) & 0b11100000) | (b >> 3);

        // fprintf(fp, "%u%u", byte1, byte2);

        fwrite(&r, 1, 1, fp);
        fwrite(&g, 1, 1, fp);
        fwrite(&b, 1, 1, fp);

        y = fgetc(yfp);
        u = fgetc(ufp);
        v = fgetc(vfp);

    }
 

    fclose(fp);
    fclose(yfp);
    fclose(ufp);
    fclose(vfp);
    return 0;
}

unsigned int clamp255(unsigned int in) {
    if (in > 255)
        return 255;
    else
        return in;
    return 0;
}

int main(int argc, char *argv[]) {
    yuv2rgb(argv[1], argv[2], argv[3]);
    return 0;
}