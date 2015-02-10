/***************************************************************************//**
 * \file grayscaleImage.S
 *
 * \brief This is an assembly program that grayscales ppm images. This code is
 *        based on C code that Dr. Pyeatt provided us. It was rewritten in
 *        assembly to speed up the image processing function of grayscale.
 *
 * \author Colton Fuhrmann
 * The struct to an image (commented at beginning of grayscaleImage) passed in
 * to this function. The magic number is checked first. If 2 or 5, go through
 * the gray image and return the min and max values in the image. If magic
 * number 1 or 4, print an error message and exit.

 * If the magic # is valid, the rows, and columns are loaded from the address
 * of the struct. Then, bl to malloc_temp which uses the C function malloc to
 * allocate the space to store the new grayscaled image.
 *
 * After the allocation of space for the new image, the main loop starts, which
 * traverses through every pixel of the image, ( but loads a word at a time )
 * and then R G B are masked out and the graying algorithm is done.
 * The colors are then orred together to create a new pixel value, and this is
 * stored in the new image memory at the corresponding location of the original
 * image. The min and max val of this grayimage are also kept track during the
 * algorithm.
 *
 * The min and max values of the gray image are returned at the end of the
 * function.
 * \date Fri May 2, 2014
 *
 *
 * It should be compiled and linked as follows:
 *   make
 * gcc will call the assembler and linker, telling the linker to include
 * the C standard library.
 ******************************************************************************/


.data
minMax_vals: .space 8

mag_num_err: .asciz "Cannot convert bitmap to grayscale\n"
	     .align 2

mem_err:     .asciz "Unable to allocate memory for graymap\n"
	     .align 2
	.text
	.global grayscaleImage
grayscaleImage:	
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


        mov r2, #255            // move min into r2
        mov r3, #0              // move max into r3
	ldr r1, =minMax_vals	// load address of min max vals struct
        str r2, [r1]            // store minval into struct
        str r3, [r1, #4]        // store maxval into struct

	
	mov r8, r0		// move struct pointer to r0

	ldr r0, [r0]		// load magic number
	sub r0, r0, #48		// subtract '48' from magic number

        // if(( magicNumber = '2') || (magicNumber = '5' ))
	cmp r0, #2		// compare magic number to #2 and branch if eq
	beq magic_num_5_or_2	// branch to find min and max
	cmp r0, #5		// compare magic num to #5 and branch if eq
	beq magic_num_5_or_2	// branch to find min and max


	// check for magic number == 4 or 1, exit(1) if so
	cmp r0, #1		// compare magic num to #1 and exit if equal
	bne secnd_mn_cmp	// branch to the second magic number compare
	ldr r0, =stderr		
	ldr r1, =mag_num_err	// load address of error message
	bl fprintf		// call printf for message
	mov r0, #1		// move exit value of #1 into r0 to return
	bl exit			// call exit
	ldmfd sp!,{r4,r5,r6,r7,r8,r9,r10,r11,r12,lr}
	mov pc, lr
secnd_mn_cmp:
	cmp r0, #4		// compare magic num to #4 and exit if equal
	bne next		// branch to next code if mag num not == 4
	ldr r0, =stderr
        ldr r1, =mag_num_err  	// load address of error message
        bl fprintf             	// call printf for message
	mov r0, #1		// move exit value of #1 into r0 to return
	bl exit			// call exit
        ldmfd sp!,{r4,r5,r6,r7,r8,r9,r10,r11,r12,lr}
        mov pc, lr

next:
///////////////////////////////////////////////////////////////////////////////

        //get rows, shift 12 bytes from base address (which is netImage struct)
        ldr r4, [r8, #12]

        //get columns, shift 16 bytes from base address (netImage struct)
        ldr r2, [r8, #16]

	//check if image->grayimage == NULL
	ldr r0, [r8, #24]
	cmp r0, #0	
	bleq gray_malloc		//branch to code to allocate the image


        //get columns, shift 16 bytes from base address (netImage struct)
        ldr r2, [r8, #16]

	//multiply columns by 3 
	//This will be the number of times we need to 
	//load 4color-pixel during an iteration of one row
	//from the image
	add r12, r2, r2, lsl #1		// add cols + (cols*2)

	mov r5, #0		//use r5 as rows loop counter, set to 0
	
	// multiply rows by 4 because we will be using a rows counter that
	// is incremented by 4 each pass through the loop so that finding 
	// the address of a row is easier
	lsl r4, #2		// multiply rows by 4 be
	
	
gray_rows_loop:
	cmp r5, r4		//compare counter to rows(r4)*4
	bge end			//if counter > rows, go to end of function
	mov r6, #0		// set columns counter by 3 to 0
	mov r9, #0		// set columns counter by 1 to 0

	ldr r7, [r8, #20]  	//load base address of rows array
	
	//load address of actual row.  add base address + offset
	ldr r7, [r7, r5]

// r4 = rows * 4
// r5 = rows counter
// r6 = col_counter * 4
// r7 = address of row  (row base address + offset)
// r8 = struct pointer
// r9 = count by 1 for column
// r10 = current 4color-pixel
// r11 = new 4color-pixel that is stored back to image
// r12 = (cols)*3

// for r6 < cols
columns_loop:
	cmp r6, r12		//compare column counter to #columns * 3
	addge r5, r5, #4	// increment rows counter
	bge gray_rows_loop		//if r6 > cols, branch to gray_rows_loop

	ldr r10, [r7, r6]	//load baseaddress + offset to get next pixel

	mov r2, #255		// move 255 mask into r2
	// get blue part of pixel  ( in r0 )
        and r0, r2, r10, lsr#16           // masks out last 8 bits (pixel)

	// get green part of pixel and multiply by 6  ( result in r1 )
	and r1, r2, r10, lsr #8	 // mask out next 8 bits
  	add r1, r1, r1, lsl #1		 // green * 3 = r1
	mov r3, #0
	add r1, r3, r1, lsl #1		 // 2 * (green*3) = r1	

	// get red part of pixel & multiply by 3 ( result in r2 )
        and r2, r2, r10, lsr #24         // mask out next 8 bits
	add r2, r2, r2, lsl #1		 // red * 3 = r2

	add r3, r0, r1			// r3 = (blue) + (green * 3)
	add r3, r3, r2			//  add red to r3
	mov r0, #5
	add r3, r3, r0			// add 5 to (3*r) + (6*g) + (1*b)

	// divide r3 by 10 to get correct grayimage pixel value
	add r0, r3, r3, lsl#6		// r0 = r3 * 65
	add r0, r0, r3, lsl#5		// r0 = (r3 * 65) + (r3*32) = r3*97
	add r2, r3, r3, lsl#2		// r2 = r3 * 5
	add r0, r0, r2			// r0 = r3*97 + r3*5
	lsr r0, #10			// shift r3 * 102 10 bits
	bl crop				// crop the gray value

	mov r3, r0			// move cropped gray val into r3
	// load minMax struct and compare current value to min & max
	// and update if needed
        ldr r0, =minMax_vals            // load address to minMax_vals struct
        ldr r1, [r0]                    // store minval into struct
        ldr r2, [r0, #4]                // store maxval into struct
        cmp r3, r1                       // compare r3 to min val
        movlt r1, r3                     // if r3 is less than r1, mov it to r1
        cmp r3, r2                       // compare r3 to max val
        movgt r2, r3                     // if r3 greater than r2, mov it to r2
        str r1, [r0]                    // store minval into struct
        str r2, [r0, #4]                // store maxval into struct


	// store at grayscale image location
	ldr r1, [r8, #24]	// get address of grayscale image** 
	ldr r1, [r1, r5]	// get address of grayscale iamge + rows offset
	strb r3, [r1, r9]	// store graypixel at r1 + column counter

	add r6, r6, #3		//increment column load counter
	add r9, r9, #1		//increment column load counter by 1
	b columns_loop		//branch to beginning of columns_loop

end:	

	ldr r0, [r8]		// load base address of struct
	sub r0, r0, #1		// decrement magic number
	str r0, [r8]		// store magic number back

	ldr r3, =minMax_vals	// load address to minMax vals struct
	ldr r0, [r3]		// load min to r0
	ldr r1, [r3, #4]	// load max to r1
	
	ldmfd	sp!,{r4,r5,r6,r7,r8,r9,r10,r11,r12,lr}
	mov	pc,lr

///////////////////////////////////////////////////////////////////////////////



// r1 = rows
// r2 = cols
find_min_max:
        stmfd   sp!,{r4 - r12,lr}

	ldr r3, [r8, #24]	// load pointer to grayimage[][]

	mov r5, #0		//use r5 as rows loop counter, set to 0
	
	// multiply rows by 4 because we will be using a rows counter that
	// is incremented by 4 each pass through the loop so that finding 
	// the address of a row is easier
	lsl r1, #2		// multiply rows by 4
	
	mov r2, #255		// move min into r2
	mov r3, #0		// move max into r3
	
// for r5 < rows
minmax_rows_loop:
	cmp r5, r1		//compare counter to rows(r1)*4
	bge min_max_end		//if counter > rows, go to end of function
	mov r6, #0		// set columns counter to 0

	ldr r7, [r8, #24]  	//load base address of gray rows array
	
	//load address of actual row.  add base address + offset
	ldr r7, [r7, r5]

	add r5, r5, #4        //increment row counter by 4 (1 byte)


// for r6 < cols
minmax_columns_loop:
	cmp r6, r2		//compare column counter to # of columns
	bge minmax_rows_loop		//if r6 > cols, branch to rows_loop

	ldr r10, [r7, r6]	//load baseaddress + offset to get next pixel

	mov r4,	#255			// mask of 8 1's

        and r0, r4, r10                  // masks out last 8 bits (pixel)
	b min_max_cmp
	and r0, r4, r10, lsr #8		 // mask out next 8 bits
	b min_max_cmp
        and r0, r4, r10, lsr #16         // mask out next 8 bits
	b min_max_cmp
        and r0, r4, r10, lsr #24         //mask out last 8 bits
	b min_max_cmp

	add r6, r6, #4			//increment column load counter
	b minmax_columns_loop		//branch to beginning of columns_loop
	

min_max_cmp:
        cmp r0, r2                       // compare r0 to min val
        movlt r2, r0                     // move r2 into min_val if lt curr_min
        cmp r0, r3                       // compare r0 to max val
        movgt r3, r0                     // move r2 into max_val if gt curr_min 

	mov pc, lr


// return minMax struct	
min_max_end:
	
	ldr r0, =minMax_vals		// load address to minMax_vals struct
	str r2, [r0]			// store minval into struct
	str r3, [r0, #4]		// store maxval into struct

        ldmfd   sp!,{r4 - r12,lr}
	mov pc, lr



////////////////////// allocate space for the gray image //////////////////////
gray_malloc:
	stmfd   sp!,{r4,r5,r6,r7,r8,r9,lr}

	// r4 = rows
	// r5 = cols
	// r6 = rows counter
	// r7 = col counter
	// r8 = image struct 
	// r9 = address of rows array

        lsl r4, #2                      // multiply rows by 4
	mov r5, r2			// mov cols into r5

	// allocate gray image rows
	// pointer to rows will be in r0 after this block
	mov r0, r4			// move rows into r0 for malloc call
	bl malloc			// call malloc to allocate rows array
	cmp r0, #0			// compare point to memory to NULL
	bne good_image			// branch if not pointing to NULL
        ldr r0, =mem_err  		// load address of error message
        bl perror             		// call perror for message
	ldmfd	sp!,{r4,r5,r6,r7,r8,r9,lr}
	mov r0, #1			// move exit value into r0
	mov pc, lr			// if mem_err, mov lr into pc

good_image:
	// store pointer to gray rows array in correct spot in struct
	str r0, [r8, #24]

	mov r6, #0			// set r6 to 0 for rows counter

        ldr r9, [r8, #24]       	//load base address of rows array


malloc_rows_loop:
	cmp r6, r4              //compare counter to rows(r4)*4
        bge end_malloc          //if counter > rows, go to end of function

	mov r0, r5			//move # of columns into r0
	bl malloc			//call malloc to create a row
	cmp r0, #0                      // compare point to memory to NULL
        bne end_rows_loop               // branch if not pointing to NULL

        ldr r0, =mem_err                // load address of error message
        bl perror                       // call perror for message
        ldmfd   sp!,{r4,r5,r6,r7,r8,r9,lr}
        mov r0, #1                      // move exit value into r0
	bl exit
        mov pc, lr                      // if mem_err, mov lr into pc
	
end_rows_loop:
	// store the row of length column(r5) to rows array	
	str r0, [r9, r6]		

        //load address of actual row.  add base address + offset
        add r6, r6, #4          //increment row counter by 4 (1 byte)

	b malloc_rows_loop		// branch to top of loop	
					
end_malloc:
	ldmfd   sp!,{r4,r5,r6,r7,r8,r9,lr}
        mov     pc,lr

//////////////////////////// end of allocate gray image ///////////////////////


magic_num_5_or_2:

        bl find_min_max          // branch to find min and max of gray image
///  bl ^ ?
        ldr r2, =minMax_vals    // load address to minMax vals struct
	ldr r0, [r2]		// load min in r0
	ldr r1, [r2, #4]	// load max in r1
        ldmfd   sp!,{r4,r5,r6,r7,r8,r9,r10,r11,r12,lr}
        mov     pc,lr

