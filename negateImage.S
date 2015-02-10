/***************************************************************************//**
 * \file negateImage.S
 *
 * \brief This is an assembly program that negates ppm images. This code is
 *        based on C code that Dr. Pyeatt provided us. It was rewritten in
 *        assembly to speed up the image processing function of negate.
 *
 * \author Colton Fuhrmann
 * The struct to an image (commented at beginning of negateImage) is passed in
 * to this function. Then, the rows and columns are loaded
 * from the structure. Rows is multiplied by 4 and columns by 4. This is done
 * so we can loop through the image using counters that increment by 4 to
 * directly use these to offset the memory address of the rows & columns.
 *
 * When a 4-color-word is ldr'ed, it is subtracted from a mask of all 1's.
 * What this does is subtract each color from 255, in one line. This is what
 * speeds up the assembly code versus the C code. This word is then stored
 * back in the same location it came from. This is done for the whole image
 * and then the image passed in is negated.
 * 
 * \date Fri May 2, 2014
 *
 * It should be compiled and linked as follows:
 *   make
 * gcc will call the assembler and linker, telling the linker to include
 * the C standard library.
 ******************************************************************************/

	.data
	.text
	.global negateImage
negateImage:	
	stmfd	sp!,{r4,r5,r6,r7,r8,lr}

	// ( netImage *image ) is being passed in
	// this is a struct
        //{
  	//char  magicNumber;      // 0
  	//char * comment;         // 4
  	//int bpp;                // 8
  	//int rows;               // 12
  	//int cols;               // 16
  	//rgbpixel **image;	  // 20
  	//unsigned char **grayimage;  // 24
	//}netImage;


	//get rows, shift 12 bytes from base address (which is netImage struct)
	ldr r1, [r0, #12]

	//get columns, shift 16 bytes from base address (netImage struct)
	ldr r2, [r0, #16]

	//multiply columns by 3
	//This will be the number of times we need to 
	//load 4color-pixel during an iteration of one row
	//from the image
	add r2, r2, r2, lsl #1		// add cols + (cols*2)

        // create mask of 255|255|255|255 into one register
        // the word (4color-pixel) will each be subtracted from 255
        mov r4, #255
        orr r4, r4, lsl #8
        orr r4, r4, lsl #16

	mov r5, #0		//use r5 as rows loop counter, set to 0
	
	// multiply rows by 4 because we will be using a rows counter that
	// is incremented by 4 each pass through the loop so that finding 
	// the address of a row is easier
	lsl r1, #2		// multiply rows by 4 be
	
// for r5 < rows
rows_loop:
	cmp r5, r1		//compare counter to rows(r1)*4
	bge end			//if counter > rows, go to end of function
	mov r6, #0		// set columns counter to 0

	ldr r7, [r0, #20]  	//load base address of rows array
	
	//load address of actual row.  add base address + offset
	ldr r7, [r7, r5]

	add r5, r5, #4        //increment row counter by 4 (1 byte)


// for r6 < cols
// r2 = (4*cols)/3
// r3 = 255 mask - 4color-pixel
// r4 = 255 mask
// r6 = col_counter * 4
// r7 = address of row  (row base address + offset)
// r8 = 4color-pixel
columns_loop:
	cmp r6, r2		//compare column counter to # of 4color loads
	bge rows_loop		//if r6 > cols, branch to rows_loop

	mov r8, #0
	ldr r8, [r7, r6]	//load baseaddress + offset to get next pixel

	// subtract 4color-pixel from 255 mask
	mov r3, #0
        sub r3, r4, r8		// r3 = r4(255 mask) - r8(4color-pixel)	

	// write new 4color-pixel to location it came from
	str r3, [r7, r6]	//store new 4pixel into r8(base addrs + offset)

	add r6, r6, #4		//increment column load counter
	b columns_loop		//branch to beginning of columns_loop

end:	

	ldmfd	sp!,{r4,r5,r6,r7,r8,lr}
	mov	pc,lr
