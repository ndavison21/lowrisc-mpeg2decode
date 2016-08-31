/* store.c, picture output routines                                         */

/* Copyright (C) 1996, MPEG Software Simulation Group. All Rights Reserved. */

/*
 * Disclaimer of Warranty
 *
 * These software programs are available to the user without any license fee or
 * royalty on an "as is" basis.  The MPEG Software Simulation Group disclaims
 * any and all warranties, whether express, implied, or statuary, including any
 * implied warranties or merchantability or of fitness for a particular
 * purpose.  In no event shall the copyright-holder be liable for any
 * incidental, punitive, or consequential damages of any kind whatsoever
 * arising from the use of these programs.
 *
 * This disclaimer of warranty extends to the user of these programs and user's
 * customers, employees, agents, transferees, successors, and assigns.
 *
 * The MPEG Software Simulation Group does not represent or warrant that the
 * programs furnished hereunder are free of infringement of any third-party
 * patents.
 *
 * Commercial implementations of MPEG-1 and MPEG-2 video, including shareware,
 * are subject to royalty fees to patent holders.  Many of these patents are
 * general enough such that they are unavoidable regardless of implementation
 * design.
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <linux/fb.h>
#include <sys/mman.h>
#include <sys/ioctl.h>

#include <string.h>
#include <time.h>

#include "config.h"
#include "global.h"

// define aligned_alloc(align, size) malloc(size)
#define COLOR_DEPTH 16

/* private prototypes */
static void store_one _ANSI_ARGS_((char *outname, unsigned char *src[],
                                   int offset, int incr, int height));
static void store_yuv _ANSI_ARGS_((char *outname, unsigned char *src[],
                                   int offset, int incr, int height));
static void store_sif _ANSI_ARGS_((char *outname, unsigned char *src[],
                                   int offset, int incr, int height));
static void store_ppm_tga _ANSI_ARGS_((char *outname, unsigned char *src[],
                                       int offset, int incr, int height, int tgaflag));
static void store_yuv1 _ANSI_ARGS_((char *name, unsigned char *src,
                                    int offset, int incr, int width, int height));
static void display _ANSI_ARGS_((unsigned char *src[], int offset, int incr, int height));
static void putbyte _ANSI_ARGS_((int c));
static void putword _ANSI_ARGS_((int w));
static void conv420to422 _ANSI_ARGS_((unsigned char *src, unsigned char *dst));
static void conv422to444 _ANSI_ARGS_((unsigned char *src, unsigned char *dst));
static void conv420to422_noninterp _ANSI_ARGS_((unsigned char *src, unsigned char *dst));
static void conv422to444_noninterp _ANSI_ARGS_((unsigned char *src, unsigned char *dst));
static void conv422to444_packed _ANSI_ARGS_((unsigned char *src, unsigned char *dst));
static void conv422to444_accelerate _ANSI_ARGS_((unsigned char *src, unsigned char *dst, int size));
static void convPlanar422ToPacked422 _ANSI_ARGS_((unsigned char *src[], unsigned char *dst));
static void convYuvToRgb _ANSI_ARGS_ ((int y, int u, int v, int crv, int cbu, int cgu, int cgv, unsigned char *r, unsigned char  *g, unsigned char  *b));
static void convYuvToRgb_simple _ANSI_ARGS_ ((int y, int u, int v, unsigned char *r, unsigned char  *g, unsigned char  *b));

static void convYuvToRgb_packed(unsigned char *src, unsigned char *dst, int size);
static void convYuvToRgb_accelerate(unsigned char *src, unsigned char *dst, int size);

static void convRgb32to16_accelerate(unsigned char *src, uint8_t *dst, int size);

#define OBFRSIZE 4096

#define PACKED 1

static unsigned char obfr[OBFRSIZE];
static unsigned char *optr;
static int outfile;

struct request {
   void* src;
   void* dest;
   size_t len;
   int opcode;
   int attr;
} acc_req;



/*
 * Debug
*/
struct timespec clock_diff(struct timespec start, struct timespec end) {
   struct timespec temp;
   if ((end.tv_nsec - start.tv_nsec) < 0) {
      temp.tv_sec = end.tv_sec - start.tv_sec - 1;
      temp.tv_nsec = 1000000000 + end.tv_nsec - start.tv_nsec;
   } else {
      temp.tv_sec = end.tv_sec - start.tv_sec;
      temp.tv_nsec = end.tv_nsec - start.tv_nsec;
   }
   return temp;
}



/*
 * store a picture as either one frame or two fields
 */
void Write_Frame(unsigned char *src[], int frame) {
   char outname[FILENAME_LENGTH];

   if (progressive_sequence || progressive_frame || Frame_Store_Flag) {
      /* progressive */
      sprintf(outname, Output_Picture_Filename, frame, 'f');
      store_one(outname, src, 0, Coded_Picture_Width, vertical_size);
   } else {
      /* interlaced */
      sprintf(outname, Output_Picture_Filename, frame, 'a');
      store_one(outname, src, 0, Coded_Picture_Width << 1, vertical_size>>1);

      sprintf(outname, Output_Picture_Filename, frame, 'b');
      store_one(outname, src,
                Coded_Picture_Width, Coded_Picture_Width << 1, vertical_size>>1);
   }
}

/*
 * store one frame or one field
 */
static void store_one(char *outname, unsigned char *src[], int offset, int incr, int height) {
   switch (Output_Type) {
   case T_YUV:
      store_yuv(outname, src, offset, incr, height);
      break;
   case T_SIF:
      store_sif(outname, src, offset, incr, height);
      break;
   case T_TGA:
      store_ppm_tga(outname, src, offset, incr, height, 1);
      break;
   case T_PPM:
      store_ppm_tga(outname, src, offset, incr, height, 0);
      break;
   case DISPLAY_PPM:
      display(src, offset, incr, height);
      break;
#ifdef DISPLAY
   case T_X11:
      dither(src);
      break;
#endif
   default:
      break;
   }
}

static int fb_initialized = 0, acc_initialized = 0;
static int fbfd = -1, accfd = -1;
static struct fb_var_screeninfo vinfo, vinfo_bak;
static struct fb_fix_screeninfo finfo;
static long int screensize = 0;
static char *fbp = 0;

/* function by nd359: Outputting straight to Framebuffer */
static void display(unsigned char *src[], int offset, int incr, int height) {
   struct timespec time1, time2;
   unsigned int i = 0, j = 0;

   int y, u, v, crv, cbu, cgu, cgv;
   unsigned char r, g, b, *py, *pu, *pv;

   static unsigned char *u422, *v422, *u444, *v444;

   unsigned char *yuv422 = NULL, *yuv444 = NULL, *yuv422_planar[3];

   if (!acc_initialized && acc_type) {
      acc_initialized = 1;
      if (accfd == -1) accfd = open("/dev/acc", O_RDWR);

      if (accfd == -1) {
         Error("Couldn't open accelerator\n");
      }
   }

   if (!fb_initialized) {
      fb_initialized = 1;

      /* Framebuffer stuff */
      if (fbfd == -1) fbfd = open("/dev/fb0", O_RDWR);

      if (fbfd == -1) {
         Error("Couldn't open framebuffer\n");
      }

      if (ioctl(fbfd, FBIOGET_VSCREENINFO, &vinfo) == -1) {
         Error("Could not read variable framebuffer-information\n");
      }

      vinfo_bak = vinfo;

      vinfo.bits_per_pixel = COLOR_DEPTH;
      vinfo.xres = horizontal_size;
      vinfo.xres_virtual = horizontal_size;
      vinfo.yres = height;
      vinfo.yres_virtual = height * 2;

      if (ioctl(fbfd, FBIOPUT_VSCREENINFO, &vinfo) == -1) {
         sprintf(Error_Text, "Could not set variable framebuffer-information\n");
         Error(Error_Text);
      }

      if (ioctl(fbfd, FBIOGET_VSCREENINFO, &vinfo) == -1) {
         sprintf(Error_Text, "Could not get variable framebuffer-information\n");
         Error(Error_Text);
      }

      // Get fixed screen information
      if (ioctl(fbfd, FBIOGET_FSCREENINFO, &finfo) == -1) {
         sprintf(Error_Text, "Could not read fixed framebuffer-information\n");
         Error(Error_Text);
      }

      // Figure out the size of the screen in bytes
      screensize = vinfo.yres * finfo.line_length;

      // Map the device to memory
      fbp = (char *)mmap(0, screensize * 2, PROT_READ | PROT_WRITE, MAP_SHARED,
                         fbfd, 0);

      if ((long)fbp == -1) {
         sprintf(Error_Text, "Failed to map framebuffer device to memory\n");
         Error(Error_Text);
      }
   }

   if (!PACKED) {
      if (chroma_format == CHROMA444) {
         u444 = src[1];
         v444 = src[2];
      } else {
         if (!u444) {
            if (chroma_format == CHROMA420) {
               if (!(u422 = (unsigned char *)malloc((Coded_Picture_Width >> 1) * Coded_Picture_Height)))
                  Error("malloc failed");
               if (!(v422 = (unsigned char *)malloc((Coded_Picture_Width >> 1) * Coded_Picture_Height)))
                  Error("malloc failed");
            }
         }

         if (chroma_format == CHROMA420) {
            conv420to422_noninterp(src[1], u422); // U data
            conv420to422_noninterp(src[2], v422); // V data
         } else {
            conv422to444_noninterp(src[1], u444);
            conv422to444_noninterp(src[2], v444);
         }
      }
   } else {
      if (!(u422 = (unsigned char *)malloc((Coded_Picture_Width >> 1) * Coded_Picture_Height)))
         Error("malloc failed");
      if (!(v422 = (unsigned char *)malloc((Coded_Picture_Width >> 1) * Coded_Picture_Height)))
         Error("malloc failed");

      if (chroma_format == CHROMA420) {
         clock_gettime(CLOCK_REALTIME, &time1);
         conv420to422_noninterp(src[1], u422); // U data
         conv420to422_noninterp(src[2], v422); // V data
         clock_gettime(CLOCK_REALTIME, &time2);
         printf("420->422: %dns\n", clock_diff(time1, time2).tv_nsec);

         yuv422_planar[0] = src[0];
         yuv422_planar[1] = u422;
         yuv422_planar[2] = v422;

         if (!(yuv422 = (unsigned char *)aligned_alloc(64, 4 * (Coded_Picture_Width >> 1) * Coded_Picture_Height)))
            Error("malloc failed");
         clock_gettime(CLOCK_REALTIME, &time1);
         convPlanar422ToPacked422(yuv422_planar, yuv422);
         clock_gettime(CLOCK_REALTIME, &time2);
         printf("Packing: %dns\n", clock_diff(time1, time2).tv_nsec);

         if (!(yuv444 = (unsigned char *)aligned_alloc(64, 4 * Coded_Picture_Width * Coded_Picture_Height)))
            Error("malloc failed");

         clock_gettime(CLOCK_REALTIME, &time1);
         if (acc_type & ACC_YUV422TO444) {
            conv422to444_accelerate(yuv422, yuv444, 4 * (Coded_Picture_Width >> 1) * Coded_Picture_Height);
         } else {
            conv422to444_packed(yuv422, yuv444);
         }
         clock_gettime(CLOCK_REALTIME, &time2);
         printf("422->444: %dns\n", clock_diff(time1, time2).tv_nsec);
      } else {
         exit(1);
      }
   }


   // Set up for double buffering
   if (vinfo.yoffset == vinfo.yres)
      vinfo.yoffset = 0;
   else
      vinfo.yoffset = vinfo.yres;


   optr = obfr;

   if (!PACKED) {
      unsigned char* yuv444_working = yuv444;
      for (i = 0; i < height; i++) {
         py = src[0] + offset + incr * i;
         pu = u444 + offset + incr * i;
         pv = v444 + offset + incr * i;

         for (j = 0; j < horizontal_size; j++) {

            u = *pu++;
            v = *pv++;
            y = *py++;
            convYuvToRgb_simple(y, u, v, &r, &g, &b);

            // Writing to framebuffer
            long int location = (j + vinfo.xoffset) * (vinfo.bits_per_pixel / 8) +
                       (i + vinfo.yoffset) * finfo.line_length;

            if (vinfo.bits_per_pixel == 32) {
               *(fbp + location + 0) = b;
               *(fbp + location + 1) = g;
               *(fbp + location + 2) = r;
               *(fbp + location + 3) = 255;
            } else { // assume 16
               *(fbp + location + 0) = ((g << 3) & 0b11100000) | (b >> 3);
               *(fbp + location + 1) = (r & 0b11111000 ) | (g >> 5);
            }
         }
      }
   } else {
      unsigned char* rgb = aligned_alloc(64, 4 * Coded_Picture_Width * Coded_Picture_Height);
      if (rgb == NULL)
         Error("malloc failed");

      clock_gettime(CLOCK_REALTIME, &time1);
      if (acc_type & ACC_YUV444TORGB) {
         convYuvToRgb_accelerate(yuv444, rgb, 4 * Coded_Picture_Width * Coded_Picture_Height);
      } else {
         convYuvToRgb_packed(yuv444, rgb, 4 * Coded_Picture_Width * Coded_Picture_Height);
      }
      clock_gettime(CLOCK_REALTIME, &time2);
      printf("444->RGB: %dns\n", clock_diff(time1, time2).tv_nsec);

      int k = 0;

      if (vinfo.bits_per_pixel != 32 && (acc_type & ACC_RGB32TO16)) {
         uint8_t* rgb16 = aligned_alloc(64, 2 * Coded_Picture_Width * Coded_Picture_Height);
         convRgb32to16_accelerate(rgb, rgb16, 4 * Coded_Picture_Width * Coded_Picture_Height);

         for (i = 0; i < height; i++) {
            memcpy(fbp + i * finfo.line_length, rgb16 + i * finfo.line_length, 2 * horizontal_size);
         }
      } else {
         for (i = 0; i < height; i++) {
            for (j = 0; j < horizontal_size; j++) {
               // Writing to framebuffer
               long int location = (j + vinfo.xoffset) * (vinfo.bits_per_pixel / 8) +
                                   (i + vinfo.yoffset) * finfo.line_length;

               b = rgb[k++];
               g = rgb[k++];
               r = rgb[k++];
               k++;

               if (vinfo.bits_per_pixel == 32) {
                  *(fbp + location + 0) = b;
                  *(fbp + location + 1) = g;
                  *(fbp + location + 2) = r;
                  *(fbp + location + 3) = 255;
               } else { // assume 16
                  *(fbp + location + 0) = ((g << 3) & 0b11100000) | (b >> 3);
                  *(fbp + location + 1) = (r & 0b11111000 ) | (g >> 5);
               }
            }
         }

         free(rgb);
      }
   }

   if (ioctl (fbfd, FBIOPAN_DISPLAY, &vinfo) == -1) {
      sprintf(Error_Text, "Could not set offset in framebuffer-information\n");
      Error(Error_Text);
   }

   if (PACKED) {
      free(yuv422);
      free(yuv444);
   }

   // if (ioctl(fbfd, FBIOPUT_VSCREENINFO, &vinfo_bak) == -1) {
   //   sprintf(Error_Text,"Could not reset variable framebuffer-information");
   //   Error(Error_Text);
   // }
}

static void convRgb32to16_accelerate(unsigned char *src, uint8_t *dst, int size) {
   struct request acc_req = {
      .src    = src,
      .dest   = dst,
      .len    = size,
      .opcode = 3,
      .attr   = 0
   };

   if (ioctl(accfd, 1, &acc_req) == -1) {
      Error("Unable to issue instruction to RGB32TO16 accelerator\n");
   }

   int status = 1;

   while (status) {
      if (ioctl(accfd, 0, &status) == -1) {
         Error("Unable to query status of accelerator\n");
      }
   }
}


/*
 * Function by nd359: Converting from planar YUV444 to RGB
 * - Using method from existing implementation
*/
static void convYuvToRgb(y, u, v, crv, cbu, cgu, cgv, r, g, b)
int y, u, v, crv, cbu, cgu, cgv;
unsigned char *r, *g, *b;
{
   *r = Clip[(y + crv * v + 32768) >> 16];
   *g = Clip[(y - cgu * u - cgv * v + 32768) >> 16];
   *b = Clip[(y + cbu * u + 32786) >> 16];
}

/*
* Function by nd359: Converting from planar YUV444 to RGB
* - Using method from existing implementation
*/
static void convYuvToRgb_simple(y, u, v, r, g, b)
int y, u, v;
unsigned char *r, *g, *b;
{
   int c, d, e;
   c = 298 * (y - 16);
   d = u - 128;
   e = v - 128;

   *r = Clip[(c + 409 * e + 128) >> 8];
   *g = Clip[(c - 100 * d - 208 * e + 128) >> 8];
   *b = Clip[(c + 516 * d + 128) >> 8];
}

__attribute__((always_inline))
static unsigned char clamp(int v) {
   if (v > 255) return 255;
   if (v < 0)return 0;
   return v;
}


/*
 * Function by nd359: Converting from packed YUV444 to RGB
 * - Using method from wikipedia
*/
static void convYuvToRgb_packed(unsigned char *src, unsigned char *dst, int size) {
   int i;
   for (i = 0; i < size; i += 4) {
      unsigned char v = src[i + 0];
      unsigned char u = src[i + 1];
      unsigned char y = src[i + 2];

      int c = 298 * (y - 16);
      int d = u - 128;
      int e = v - 128;

      dst[i + 2] = clamp((c + 409 * (e) + 128) >> 8);
      dst[i + 1] = clamp((c - 100 * (d) - 208 * (e) + 128) >> 8);
      dst[i + 0] = clamp((c + 516 * (d) + 128) >> 8);
   }

}


static void convYuvToRgb_accelerate(unsigned char *src, unsigned char *dst, int size) {
   struct request acc_req = {
      .src    = src,
      .dest   = dst,
      .len    = size,
      .opcode = 2,
      .attr   = 0
   };

   if (ioctl(accfd, 1, &acc_req) == -1) {
      Error("Unable to issue instruction to YUV444toRGB accelerator\n");
   }

   int status = 1;

   while (status) {
      if (ioctl(accfd, 0, &status) == -1) {
         Error("Unable to query status of accelerator\n");
      }
   }
}


/* separate headerless files for y, u and v */
static void store_yuv(outname, src, offset, incr, height)
char *outname;
unsigned char *src[];
int offset, incr, height;
{
   int hsize;
   char tmpname[FILENAME_LENGTH];

   hsize = horizontal_size;

   sprintf(tmpname, "%s.Y", outname);
   store_yuv1(tmpname, src[0], offset, incr, hsize, height);

   if (chroma_format != CHROMA444) {
      offset >>= 1; incr >>= 1; hsize >>= 1;
   }

   if (chroma_format == CHROMA420) {
      height >>= 1;
   }

   sprintf(tmpname, "%s.U", outname);
   store_yuv1(tmpname, src[1], offset, incr, hsize, height);

   sprintf(tmpname, "%s.V", outname);
   store_yuv1(tmpname, src[2], offset, incr, hsize, height);
}

/* auxiliary routine */
static void store_yuv1(name, src, offset, incr, width, height)
char *name;
unsigned char *src;
int offset, incr, width, height;
{
   int i, j;
   unsigned char *p;

   if (!Quiet_Flag)
      fprintf(stderr, "saving %s\n", name);

   if ((outfile = open(name, O_CREAT | O_TRUNC | O_WRONLY | O_BINARY, 0666)) == -1) {
      sprintf(Error_Text, "Couldn't create %s\n", name);
      Error(Error_Text);
   }

   optr = obfr;

   for (i = 0; i < height; i++) {
      p = src + offset + incr * i;
      for (j = 0; j < width; j++)
         putbyte(*p++);
   }

   if (optr != obfr)
      write(outfile, obfr, optr - obfr);

   close(outfile);
}

/*
 * store as headerless file in U,Y,V,Y format
 */
static void store_sif (outname, src, offset, incr, height)
char *outname;
unsigned char *src[];
int offset, incr, height;
{
   int i, j;
   unsigned char *py, *pu, *pv;
   static unsigned char *u422, *v422;

   if (chroma_format == CHROMA444)
      Error("4:4:4 not supported for SIF format");

   if (chroma_format == CHROMA422) {
      u422 = src[1];
      v422 = src[2];
   } else {
      if (!u422) {
         if (!(u422 = (unsigned char *)malloc((Coded_Picture_Width >> 1)
                                              * Coded_Picture_Height)))
            Error("malloc failed");
         if (!(v422 = (unsigned char *)malloc((Coded_Picture_Width >> 1)
                                              * Coded_Picture_Height)))
            Error("malloc failed");
      }

      conv420to422_noninterp(src[1], u422);
      conv420to422_noninterp(src[2], v422);
   }

   strcat(outname, ".SIF");

   if (!Quiet_Flag)
      fprintf(stderr, "saving %s\n", outname);

   if ((outfile = open(outname, O_CREAT | O_TRUNC | O_WRONLY | O_BINARY, 0666)) == -1) {
      sprintf(Error_Text, "Couldn't create %s\n", outname);
      Error(Error_Text);
   }

   optr = obfr;

   for (i = 0; i < height; i++) {
      py = src[0] + offset + incr * i;
      pu = u422 + (offset >> 1) + (incr >> 1) * i;
      pv = v422 + (offset >> 1) + (incr >> 1) * i;

      for (j = 0; j < horizontal_size; j += 2) {
         putbyte(*pu++);
         putbyte(*py++);
         putbyte(*pv++);
         putbyte(*py++);
      }
   }

   if (optr != obfr)
      write(outfile, obfr, optr - obfr);

   close(outfile);
}

/*
 * store as PPM (PBMPLUS) or uncompressed Truevision TGA ('Targa') file
*/
static void store_ppm_tga(outname, src, offset, incr, height, tgaflag)
char *outname;
unsigned char *src[];
int offset, incr, height;
int tgaflag;
{
   int i, j;
   int y, u, v, r, g, b;
   int crv, cbu, cgu, cgv;
   unsigned char *py, *pu, *pv;
   static unsigned char tga24[14] = {0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 24, 32};
   char header[FILENAME_LENGTH];
   static unsigned char *u422, *v422, *u444, *v444;

   if (chroma_format == CHROMA444) {
      u444 = src[1];
      v444 = src[2];
   } else {
      if (!u444) {
         if (chroma_format == CHROMA420) {
            if (!(u422 = (unsigned char *)malloc((Coded_Picture_Width >> 1)
                                                 * Coded_Picture_Height)))
               Error("malloc failed");
            if (!(v422 = (unsigned char *)malloc((Coded_Picture_Width >> 1)
                                                 * Coded_Picture_Height)))
               Error("malloc failed");
         }

         if (!(u444 = (unsigned char *)malloc(Coded_Picture_Width
                                              * Coded_Picture_Height)))
            Error("malloc failed");

         if (!(v444 = (unsigned char *)malloc(Coded_Picture_Width
                                              * Coded_Picture_Height)))
            Error("malloc failed");
      }

      if (chroma_format == CHROMA420) {
         conv420to422_noninterp(src[1], u422);
         conv420to422_noninterp(src[2], v422);
         conv422to444_noninterp(u422, u444);
         conv422to444_noninterp(v422, v444);
      } else {
         conv422to444_noninterp(src[1], u444);
         conv422to444_noninterp(src[2], v444);
      }
   }

   strcat(outname, tgaflag ? ".tga" : ".ppm");

   if (!Quiet_Flag)
      fprintf(stderr, "saving %s\n", outname);

   if ((outfile = open(outname, O_CREAT | O_TRUNC | O_WRONLY | O_BINARY, 0666)) == -1) {
      sprintf(Error_Text, "Couldn't create %s\n", outname);
      Error(Error_Text);
   }

   optr = obfr;

   if (tgaflag) {
      /* TGA header */
      for (i = 0; i < 12; i++)
         putbyte(tga24[i]);

      putword(horizontal_size); putword(height);
      putbyte(tga24[12]); putbyte(tga24[13]);
   } else {
      /* PPM header */
      sprintf(header, "P6\n%d %d\n255\n", horizontal_size, height);

      for (i = 0; header[i] != 0; i++)
         putbyte(header[i]);
   }

   /* matrix coefficients */
   crv = Inverse_Table_6_9[matrix_coefficients][0];
   cbu = Inverse_Table_6_9[matrix_coefficients][1];
   cgu = Inverse_Table_6_9[matrix_coefficients][2];
   cgv = Inverse_Table_6_9[matrix_coefficients][3];

   for (i = 0; i < height; i++) {
      py = src[0] + offset + incr * i;
      pu = u444 + offset + incr * i;
      pv = v444 + offset + incr * i;

      for (j = 0; j < horizontal_size; j++) {
         u = *pu++ - 128;
         v = *pv++ - 128;
         y = 76309 * (*py++ - 16); /* (255/219)*65536 */
         r = Clip[(y + crv * v + 32768) >> 16];
         g = Clip[(y - cgu * u - cgv * v + 32768) >> 16];
         b = Clip[(y + cbu * u + 32786) >> 16];

         if (tgaflag) {
            putbyte(b); putbyte(g); putbyte(r);
         } else {
            putbyte(r); putbyte(g); putbyte(b);
         }
      }
   }

   if (optr != obfr)
      write(outfile, obfr, optr - obfr);

   close(outfile);
}

static void putbyte(c)
int c;
{
   *optr++ = c;

   if (optr == obfr + OBFRSIZE) {
      write(outfile, obfr, OBFRSIZE);
      optr = obfr;
   }
}

static void putword(w)
int w;
{
   putbyte(w); putbyte(w >> 8);
}

static void conv422to444_noninterp(src, dst)
unsigned char *src, *dst;
{
   int i, i2, w, j;
   w = Coded_Picture_Width >> 1;

   for (j = 0; j < Coded_Picture_Height; j++) {
      for (i = 0; i < w; i++) {
         i2 = i * 2;
         dst[i2] = src[i];

         /* odd samples (21 -52 159 159 -52 21) */
         dst[i2 + 1] = src[i];
      }
      src += w;
      dst += Coded_Picture_Width;
   }
}

static void conv422to444_accelerate(unsigned char *src, unsigned char *dst, int size) {
   struct request acc_req = {
      .src    = src,
      .dest   = dst,
      .len    = size,
      .opcode = 1,
      .attr   = 0
   };

   if (ioctl(accfd, 1, &acc_req) == -1) {
      Error("Unable to issue instruction to YUV422to444 accelerator");
   }

   int status = 1;

   while (status) {
      if (ioctl(accfd, 0, &status) == -1) {
         Error("Unable to query status of accelerator");
      }
   }
}

static void conv422to444_packed(src, dst)
unsigned char *src, *dst;
{
   int i = 0;
   while (i < 4 * Coded_Picture_Height * Coded_Picture_Width) {
      dst[i++] = src[3]; // V
      dst[i++] = src[1]; // U
      dst[i++] = src[0]; // Y0
      dst[i++] = 0;

      dst[i++] = src[3]; // V
      dst[i++] = src[1]; // U
      dst[i++] = src[2]; // Y1
      dst[i++] = 0;

      src += 4;
   }
}


/*
 * Planar format has all 2n Y's, followed by all n U's, followed by all n V's.
 * This is more compressable, but not useful for stream processing in hardware.
 * Therefore we convert to packed format, which has n groups of Y0, U, Y1, V.
 * (nicely fits in 32 bits as well, which means we can send groups 2 at a time
 *  to the stream processor).
*/
static void convPlanar422ToPacked422(src, dst)
unsigned char *src[], *dst;
{
   int y = 0, u = 0, v = 0, k = 0;

   while (k < 4 * Coded_Picture_Height * (Coded_Picture_Width >> 1)) {
      dst[k++] = src[0][y++]; // Y0
      dst[k++] = src[1][u++]; // U
      dst[k++] = src[0][y++]; // Y1
      dst[k++] = src[2][v++]; // V
   }
}

/* horizontal 1:2 interpolation filter */
static void conv422to444(src, dst)
unsigned char *src, *dst;
{
   int i, i2, w, j, im3, im2, im1, ip1, ip2, ip3;

   w = Coded_Picture_Width >> 1;

   if (base.MPEG2_Flag) {
      for (j = 0; j < Coded_Picture_Height; j++) {
         for (i = 0; i < w; i++) {
            i2 = i << 1;
            im2 = (i < 2) ? 0 : i - 2;
            im1 = (i < 1) ? 0 : i - 1;
            ip1 = (i < w - 1) ? i + 1 : w - 1;
            ip2 = (i < w - 2) ? i + 2 : w - 1;
            ip3 = (i < w - 3) ? i + 3 : w - 1;

            /* FIR filter coefficients (*256): 21 0 -52 0 159 256 159 0 -52 0 21 */
            /* even samples (0 0 256 0 0) */
            dst[i2] = src[i];

            /* odd samples (21 -52 159 159 -52 21) */
            dst[i2 + 1] = Clip[(int)(21 * (src[im2] + src[ip3])
                                     - 52 * (src[im1] + src[ip2])
                                     + 159 * (src[i] + src[ip1]) + 128) >> 8];
         }
         src += w;
         dst += Coded_Picture_Width;
      }
   } else {
      for (j = 0; j < Coded_Picture_Height; j++) {
         for (i = 0; i < w; i++) {

            i2 = i << 1;
            im3 = (i < 3) ? 0 : i - 3;
            im2 = (i < 2) ? 0 : i - 2;
            im1 = (i < 1) ? 0 : i - 1;
            ip1 = (i < w - 1) ? i + 1 : w - 1;
            ip2 = (i < w - 2) ? i + 2 : w - 1;
            ip3 = (i < w - 3) ? i + 3 : w - 1;

            /* FIR filter coefficients (*256): 5 -21 70 228 -37 11 */
            dst[i2] =   Clip[(int)(  5 * src[im3]
                                     - 21 * src[im2]
                                     + 70 * src[im1]
                                     + 228 * src[i]
                                     - 37 * src[ip1]
                                     + 11 * src[ip2] + 128) >> 8];

            dst[i2 + 1] = Clip[(int)(  5 * src[ip3]
                                       - 21 * src[ip2]
                                       + 70 * src[ip1]
                                       + 228 * src[i]
                                       - 37 * src[im1]
                                       + 11 * src[im2] + 128) >> 8];
         }
         src += w;
         dst += Coded_Picture_Width;
      }
   }
}

/* vertical 1:2 interpolation filter */
static void conv420to422(src, dst)
unsigned char *src, *dst;
{
   int w, h, i, j, j2;
   int jm6, jm5, jm4, jm3, jm2, jm1, jp1, jp2, jp3, jp4, jp5, jp6, jp7;

   w = Coded_Picture_Width >> 1;
   h = Coded_Picture_Height >> 1;


   if (progressive_frame) {
      /* intra frame */
      for (i = 0; i < w; i++) {
         for (j = 0; j < h; j++) {
            j2 = j << 1;
            jm3 = (j < 3) ? 0 : j - 3;
            jm2 = (j < 2) ? 0 : j - 2;
            jm1 = (j < 1) ? 0 : j - 1;
            jp1 = (j < h - 1) ? j + 1 : h - 1;
            jp2 = (j < h - 2) ? j + 2 : h - 1;
            jp3 = (j < h - 3) ? j + 3 : h - 1;

            /* FIR filter coefficients (*256): 5 -21 70 228 -37 11 */
            /* New FIR filter coefficients (*256): 3 -16 67 227 -32 7 */
            dst[w * j2] =     Clip[(int)(  3 * src[w * jm3]
                                           - 16 * src[w * jm2]
                                           + 67 * src[w * jm1]
                                           + 227 * src[w * j]
                                           - 32 * src[w * jp1]
                                           + 7 * src[w * jp2] + 128) >> 8];

            dst[w * (j2 + 1)] = Clip[(int)(  3 * src[w * jp3]
                                             - 16 * src[w * jp2]
                                             + 67 * src[w * jp1]
                                             + 227 * src[w * j]
                                             - 32 * src[w * jm1]
                                             + 7 * src[w * jm2] + 128) >> 8];
         }
         src++;
         dst++;
      }
   } else {
      /* intra field */
      for (i = 0; i < w; i++) {
         for (j = 0; j < h; j += 2) {
            j2 = j << 1;

            /* top field */
            jm6 = (j < 6) ? 0 : j - 6;
            jm4 = (j < 4) ? 0 : j - 4;
            jm2 = (j < 2) ? 0 : j - 2;
            jp2 = (j < h - 2) ? j + 2 : h - 2;
            jp4 = (j < h - 4) ? j + 4 : h - 2;
            jp6 = (j < h - 6) ? j + 6 : h - 2;

            /* Polyphase FIR filter coefficients (*256): 2 -10 35 242 -18 5 */
            /* New polyphase FIR filter coefficients (*256): 1 -7 30 248 -21 5 */
            dst[w * j2] = Clip[(int)(  1 * src[w * jm6]
                                       - 7 * src[w * jm4]
                                       + 30 * src[w * jm2]
                                       + 248 * src[w * j]
                                       - 21 * src[w * jp2]
                                       + 5 * src[w * jp4] + 128) >> 8];

            /* Polyphase FIR filter coefficients (*256): 11 -38 192 113 -30 8 */
            /* New polyphase FIR filter coefficients (*256):7 -35 194 110 -24 4 */
            dst[w * (j2 + 2)] = Clip[(int)( 7 * src[w * jm4]
                                            - 35 * src[w * jm2]
                                            + 194 * src[w * j]
                                            + 110 * src[w * jp2]
                                            - 24 * src[w * jp4]
                                            + 4 * src[w * jp6] + 128) >> 8];

            /* bottom field */
            jm5 = (j < 5) ? 1 : j - 5;
            jm3 = (j < 3) ? 1 : j - 3;
            jm1 = (j < 1) ? 1 : j - 1;
            jp1 = (j < h - 1) ? j + 1 : h - 1;
            jp3 = (j < h - 3) ? j + 3 : h - 1;
            jp5 = (j < h - 5) ? j + 5 : h - 1;
            jp7 = (j < h - 7) ? j + 7 : h - 1;

            /* Polyphase FIR filter coefficients (*256): 11 -38 192 113 -30 8 */
            /* New polyphase FIR filter coefficients (*256):7 -35 194 110 -24 4 */
            dst[w * (j2 + 1)] = Clip[(int)( 7 * src[w * jp5]
                                            - 35 * src[w * jp3]
                                            + 194 * src[w * jp1]
                                            + 110 * src[w * jm1]
                                            - 24 * src[w * jm3]
                                            + 4 * src[w * jm5] + 128) >> 8];

            dst[w * (j2 + 3)] = Clip[(int)(  1 * src[w * jp7]
                                             - 7 * src[w * jp5]
                                             + 30 * src[w * jp3]
                                             + 248 * src[w * jp1]
                                             - 21 * src[w * jm1]
                                             + 5 * src[w * jm3] + 128) >> 8];
         }
         src++;
         dst++;
      }
   }
}

/*
 * Planar to planar
*/
static void conv420to422_noninterp(unsigned char *src, unsigned char *dst) {
   int w = Coded_Picture_Width >> 1;
   int h = Coded_Picture_Height >> 1;

   for (int y = 0; y < h; y++) {
      int y2 = y << 1;
      memcpy(&dst[w * y2], &src[w * y], w);
      memcpy(&dst[w * (y2 + 1)], &src[w * y], w);
   }
}
