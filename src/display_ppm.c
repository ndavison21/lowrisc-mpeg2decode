#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <fcntl.h>
#include <linux/fb.h>
#include <sys/mman.h>
#include <sys/ioctl.h>

int display_ppm(char filename_in[]) {
    // Framebufer stuff
    int fbfd = 0;
    struct fb_var_screeninfo vinfo;
    struct fb_fix_screeninfo finfo;
    long int screensize = 0;
    char *fbp = 0;
    unsigned int i = 0, j = 0;
    long int location = 0;

    // PPM stuff
    FILE *fp_in;
    char magicnum[3];
    unsigned char r, g, b, byte[4];
    unsigned int height, width, max;

    fp_in = fopen(filename_in,"r");
    fbfd = open("/dev/fb0", O_RDWR);

    if (fp_in == NULL) {
        perror("ERROR: Could not open input file\n");
        goto error;
    }

    if (fbfd == -1) {
        perror("ERROR: Could not open framebuffer device");
        goto error;
    }
    // Get variable screen information
    if (ioctl(fbfd, FBIOGET_VSCREENINFO, &vinfo) == -1) {
        perror("ERROR: Could not read variable framebuffer-information");
        goto error;
    }

    vinfo.bits_per_pixel = 32;
    vinfo.xres = 128;
    vinfo.yres = 128;
    if (ioctl(fbfd, FBIOPUT_VSCREENINFO, &vinfo) == -1) {
        perror("ERROR: Could not set variable framebuffer-information");
        goto error;
    }

    // Get fixed screen information
    if (ioctl(fbfd, FBIOGET_FSCREENINFO, &finfo) == -1) {
        perror("ERROR: Could not read fixed framebuffer-information");
        goto error;
    }
    
    // Figure out the size of the screen in bytes
    screensize = vinfo.xres * vinfo.yres * vinfo.bits_per_pixel / 8;
    printf("Screensize: %d, xRes: %d, yRes: %d, Bits per Pixel: %d\n",
            screensize, vinfo.yres, vinfo.xres, vinfo.bits_per_pixel);

    // Map the device to memory
    fbp = (char *)mmap(0, screensize, PROT_READ | PROT_WRITE, MAP_SHARED,
                        fbfd, 0);

    if ((long)fbp == -1) {
         perror("ERROR: Failed to map framebuffer device to memory");
         goto error;
    }
    printf("The framebuffer device was mapped to memory successfully.\n");

    // Starting to read the PPM file

    fscanf(fp_in, "%s %d %d %d ", magicnum, &width, &height, &max);

    printf("Magic Number: %s\n", magicnum);
    printf("Width x Height: %d x %d\n", width, height);
    printf("Maximum Colour Value: %d\n", max);

    if (strcmp(magicnum, "P6") != 0 || max > 255) {
        perror("ERROR: could not process file: incorrect format.\n");
        goto error;
    }


    // Data starts here
    for (i=0; i < height; ++i) {
        for (j = 0; j < width; ++j) {
            fread(&r, 1, 1, fp_in);
            fread(&g, 1, 1, fp_in);
            fread(&b, 1, 1, fp_in);

            // Writing to framebuffer
            location = (j + vinfo.xoffset) * (vinfo.bits_per_pixel/8) +
                        (i + vinfo.yoffset) * finfo.line_length;

            if (vinfo.bits_per_pixel == 32) {
                byte[3] = g;
                byte[2] = r;
                byte[1] = 255;
                byte[0] = b;
                *(fbp + location + 1) = byte[3];
                *(fbp + location + 2) = byte[2];
                *(fbp + location + 3) = byte[1];
                *(fbp + location + 4) = byte[0];
            } else { // assume 16
                byte[1] = (r & 0b11111000 ) | (g >> 5);
                byte[0] = ((g << 3) & 0b11100000) | (b >> 3);
                *(fbp + location) = byte[1];
                *(fbp + location + 1) = byte[0];
            }

        }
    }

    fclose(fp_in);
    munmap(fbp, screensize);
    close(fbfd);
    return 0;

error: 
    fclose(fp_in);
    munmap(fbp, screensize);
    close(fbfd);
    return -1;
}

int main(int argc, char *argv[]) {
    if (argc != 2) {
        printf("Need 1 filenames\n");
        return 0;
    }
    display_ppm(argv[1]);
    return 0;
}