/***************************************************************************//**
 * \file brightenImage.S
 *
 * \brief This is an assembly program that brightens ppm images. This code is
 *        based on C code that Dr. Pyeatt provided us. It was rewritten in
 *        assembly to speed up the image processing function of brighten.
 *
 * \author Colton Fuhrmann
 * The struct to an image (commented at beginning of brigthenImage) is passed
 * to this function. First, the brighten value passed in the function is
 * converted to an integer using atoi. Then, the rows and columns are loaded
 * from the structure. Rows is multiplied by 4 and columns by 4. This is done
 * so we can loop through the image using counters that increment by 4 to
 * directly use these to offset the memory address of the rows & columns.
 *
 * When a 4-color-word is ldr'ed, a mask of 1's is used to AND out each of
 * the four colors. After each color byte is masked out, the brighten val
 * is added to the color value. These 4 color values are then ORRED back in to
 * an empty register to create the new brightened 4-color-word. This brightened
 * word is then stored back in the same spot the unbrightened word came from.
 * 
 * \date Fri May 2, 2014
 *
 * It should be compiled and linked as follows:
 *   make
 * gcc will call the assembler and linker, telling the linker to include
 * the C standard library.
 ******************************************************************************/

	.data
msg:	.asciz "brightenImage has not been implemented\n"
	
	.text
.data
	.text
	.global brightenImage
brightenImage:	
	stmfd	sp!,{r4,r5,r6,r7,r8,r9,r10,r11,r12,lr}

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

	
	mov r8, r0		// move struct pointer in r0

	mov r0, r1		// move the brighten val passed in to r0
	bl atoi			// call atoi to convert arg to integer

        // move the brighten value into r9
	mov r9, r0

	//get rows, shift 12 bytes from base address (which is netImage struct)
	ldr r1, [r8, #12]

	//get columns, shift 16 bytes from base address (netImage struct)
	ldr r2, [r8, #16]

	//multiply columns by 3 and then divide by 4.
	//This will be the number of times we need to 
	//load 4color-pixel during an iteration of one row
	//from the image
	add r12, r2, r2, lsl #1		// add cols + (cols*2)

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

	ldr r7, [r8, #20]  	//load base address of rows array
	
	//load address of actual row.  add base address + offset
	ldr r7, [r7, r5]

	add r5, r5, #4        //increment row counter by 4 (1 byte)


// r4 = 255 (mask of 8 1's)
// r5 = rows counter
// r6 = col_counter * 4
// r7 = address of row  (row base address + offset)
// r8 = struct pointer
// r9 = brighten factor mask
// r10 = current 4color-pixel
// r11 = new 4color-pixel that is stored back to image
// r12 = (cols)/3

// for r6 < cols
columns_loop:
	cmp r6, r12		//compare column counter to # of 4color loads
	bge rows_loop		//if r6 > cols, branch to rows_loop

	ldr r10, [r7, r6]	//load baseaddress + offset to get next pixel

	mov r4,	#255			// mask of 8 1's
	mov r11, #0			// mask of all 0's	

        and r0, r4, r10                  // masks out last 8 bits (pixel)
	add r0, r0, r9			 // add brightenval to 8bits
        bl crop                          // crop the value if needed
	orr r11, r11, r0		 // put first 8bits into r12

	and r0, r4, r10, lsr #8		 // mask out next 8 bits
	add r0, r0, r9			 // add brigthenval to next 8bits
	bl crop			 	 // crop the value if needed
	orr r11, r11, r0, lsl #8	 // put next 8bits into r12 

        and r0, r4, r10, lsr #16         // mask out next 8 bits
        add r0, r0, r9                   // add brigthenval to next 8bits
        bl crop                          // crop the value if needed
        orr r11, r11, r0, lsl #16        // put next 8bits into r12 

        and r0, r4, r10, lsr #24         //mask out last 8 bits
        add r0, r0, r9                   // add brigthenval to next 8bits
        bl crop                          // crop the value if needed
        orr r11, r11, r0, lsl #24        // put last 8bits into r12  

	// write new 4color-pixel to location it came from
        str r11, [r7, r6]

	add r6, r6, #4		//increment column load counter
	b columns_loop		//branch to beginning of columns_loop

end:	

	ldmfd	sp!,{r4,r5,r6,r7,r8,r9,r10,r11,r12,lr}
	mov	pc,lr
