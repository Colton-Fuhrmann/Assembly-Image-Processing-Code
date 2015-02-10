/***************************************************************************//**
 * \file smoothImage.S
 *
 * \brief This is an assembly program that smooths ppm images. This code is
 *	  based on C code that Dr. Pyeatt provided us. It was rewritten in
 *	  assembly to speed up the image processing function of smooth.
 *
 * \author Colton Fuhrmann
 * The struct to an image (commented at beginning of smoothImage) is passed in
 * to this function. First, the rows, and columns are loaded from the address
 * of the struct. Then, bl to malloc_temp which uses the C function malloc to
 * allocate the space to store the new smoothed image.
 *
 * After the allocation of space for the new image, the main loop starts, which
 * traverses through every pixel of the image, ( but loads a word at a time )
 * and calls the process_color function which does the smoothing algorithm for
 * a color ( R G or B ), and returns that value back in r0. The colors are then
 * orred together to create a new pixel value, and this is stored in the
 * new image memory at the corresponding location of the original image.
 *
 * After all the smoothing is done, the old image is freed up using the C
 * function free. Then, a function is called to fix the borders and corners
 * of the new image.
 * Then, the pointer to the new rows array is stored in the
 * location of the struct where the original image was. Then, the function
 * returns.
 * \date Fri May 2, 2014
 *
 *
 * It should be compiled and linked as follows:
 *   make
 * gcc will call the assembler and linker, telling the linker to include
 * the C standard library.
 ******************************************************************************/

	.data
mem_err:     .asciz "Unable to allocate space for temporary image\n"
	     .align 2

temp_img:      .word 0	// tmp image to store new smoothed pixels

rows_loop_limit: .word 0
	.text
	.global smoothImage
smoothImage:	
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

	mov r8, r0		// move struct pointer to r0

        //get rows, shift 12 bytes from base address (which is netImage struct)
        ldr r4, [r8, #12]

        //get columns, shift 16 bytes from base address (netImage struct)
        ldr r5, [r8, #16]

	bl malloc_temp		//branch to code to allocate the temp image
	mov r11, r0		//put address of temp_img rows arr in r11

	//multiply columns by 3 
	//This will be the number of times we need to 
	//load 4color-pixel during an iteration of one row
	//from the image
	mov r2, r5			// move cols into r2
	add r12, r2, r2, lsl #1		// add cols + (cols*2)

	// multiply rows by 4 because we will be using a rows counter that
	// is incremented by 4 each pass through the loop so that finding 
	// the address of a row is easier
	lsl r4, #2		// multiply rows by 4

        mov r5, #4              //use r5 as rows loop counter, set to 0
	
        sub r4, r4, #4          // subtract 4 from rows so we dont overstep
                                // boundary while smoothing image
	ldr r0, =rows_loop_limit
	str r4, [r0]
	mov r4 ,r11

        sub r12, r12, #3        // subtact 3 from cols so no overstep boundary
	
rows_loop:
	ldr r0, =rows_loop_limit
	ldr r0, [r0]
	cmp r5, r0		//compare counter to rows * 4
	bge end			//if counter > rows, go to end of function
	mov r6, #3		//start col ctr at 3 to not overstep image

	ldr r7, [r8, #20]  	//load base address of rows array
	//load address of actual row.  add base address + offset
	ldr r7, [r7, r5]

// r4 = rows * 4
// r5 = rows counter
// r6 = col_counter * 3
// r7 = address of row  (row base address + offset)
// r8 = struct pointer
// r9 = used in process_color 
// r10 = used in process_color
// r11 = new smoothed pixel
// r12 = (cols)*3

// for r6 < cols*3
columns_loop:
	cmp r6, r12		//compare column counter to #columns * 3
	addge r5, r5, #4	// increment rows counter
	bge rows_loop		//if r6 > cols, branch to rows_loop

        mov r11, #0             // initialize new smooth pixel to 0

        mov r0, #24             // move shift of 24 into r0
        bl process_color        // process red
        orr r11, r11, r0        // put red part of pixel in right spot

        mov r0, #16                // move shift of 16 into r0
        bl process_color           // process green
        orr r11, r11, r0, lsl#16   // put green part of pixel in right spot

        mov r0, #8                 // move shift of 8 into r0
        bl process_color           // process blue
        orr r11, r11, r0, lsl#8    // put blue part of pixel in right spot
	
        ldr r1, [r4, r5]        // get address of image + rows offset
        str r11, [r1, r6]       // store new smoothed pixel at r1 + col offset

	add r6, r6, #3		//increment column load counter
	b columns_loop		//branch to beginning of columns_loop

end:	
	bl free_old_image	// free up old image
	bl fix_edges		// create border around image
	str r4, [r8, #20]       // store temp img to struct
	
	ldmfd	sp!,{r4,r5,r6,r7,r8,r9,r10,r11,r12,lr}
	mov	pc,lr

///////////////////////////////////////////////////////////////////////////////




////////////////////// allocate space for the temp image //////////////////////
malloc_temp:
	stmfd   sp!,{r4,r5,r6,r7,r8,r9,r10,lr}

	// r4 = rows
	// r5 = cols
	// r6 = rows counter
	// r7 = col counter
	// r8 = image struct 
	// r9 = address of rows array

        lsl r4, #2                      // multiply rows by 4
	add r5, r5, r5, lsl#1		// multiply cols by 3

	// allocate image rows
	// pointer to rows will be in r0 after this block
	mov r0, r4			// move rows into r0 for malloc call
	bl malloc			// call malloc to allocate rows array
	cmp r0, #0			// compare point to memory to NULL
	bne good_image			// branch if not pointing to NULL
	ldr r0, =stderr			// load address to stderr
        ldr r1, =mem_err  		// load address of error message
	bl fprintf			// call fprintf for error msg
        mov r0, #1                      // move exit value into r0
        bl exit             		// call exit 
	ldmfd	sp!,{r4,r5,r6,r7,r8,r9,lr}
	mov pc, lr			// if mem_err, mov lr into pc

good_image:
	mov r10, r0			// move address from malloc to r10
	ldr r1, =temp_img		
	str r0, [r1]			// store address to temp_img
        mov r6, #0                      // set r6 to 0 for rows counter

malloc_rows_loop:
	cmp r6, r4              //compare counter to rows(r4)*4
        bge end_malloc          //if counter > rows, go to end of function

	mov r0, r5			//move # of columns into r0
	bl malloc			//call malloc to create a row
	cmp r0, #0                      // compare point to memory to NULL
        bne end_rows_loop               // branch if not pointing to NULL
	ldr r0, =stderr			// load address to stderr
        ldr r1, =mem_err                // load address of error message
        bl fprintf                       // call fprintf for error message
	mov r0, #1                      // move exit value into r0
	bl exit				// call exit	
        ldmfd   sp!,{r4,r5,r6,r7,r8,r9,lr}
        mov pc, lr                      // if mem_err, mov lr into pc
	
end_rows_loop:
	// store the row of length column(r5) to rows array	
	str r0, [r10, r6]		

        //load address of actual row.  add base address + offset
        add r6, r6, #4          	//increment row counter by 4 (1 byte)

	b malloc_rows_loop		// branch to top of loop	
					
end_malloc:

	mov r0, r10			// move address of temp_img to r0
	
	ldmfd   sp!,{r4,r5,r6,r7,r8,r9,r10,lr}
        mov     pc,lr
//////////////////////////// end of allocate image ////////////////////////////



////////////////////////// start of processing a color ////////////////////////
// this function takes a color ( R , G , or B ) from a pixel value and sums the
// neighboring values of the that same color up. Then, using a series of shifts
// and multiplies, a multiplication by constant and division by constant are
// done to perform the smooth operation.
process_color:
	stmfd	sp!,{r4-r10,lr}
	// r0: how many bits to shift (24 = red, 16 = green, 8 = blue )
	// r5: row counter ( incremented by 4 ) i
	// r6: column counter ( incremented by 3 ) j
	// r7: base address of rows array offset by r5(i)
	// r8: image struct
	// r9: (j + n)   and  mask
	// r10: word (4 color pixel)
	mov r3, #0			// set sum = 0
	mov r1, #-4			// set m = -4
	mov r2, #-3			// set n = -3

	ldr r7, [r8, #20]		//load address to rows arr ptr

for_m_lt_5:
	cmp r1, #5			// compare m to 5
	bge end_process_color		// go to end of process_color func
        mov r4, r7                      // move base address of rows arr to r4
	mov r2, #-3			// set n to -3

for_n_lt_4:
        mov r4, r7                      // move base address of rows arr to r4

	cmp r2, #4			// compare n to 4
	addge r1, r1, #4		// increment m by 4
	bge for_m_lt_5			// go to m for loop if (n >= 2 )

	cmp r1, #-4			// cmp m to see if first run thru loop
	subeq r4, #4			// subtract 3 from r4 if 1st time thru
	addne r4, r7, r1		// if not, add r1 offset ( 0 or 4 )
	ldr r4, [r4, r5]		// load actual row

	cmp r2, #-3			// cmp n to see if 1st run thru loop
	subeq r4, #3
	ldreq r10, [r4,r6]		// load r4 + r6 (column offset)
	addne r9, r6, r2		// add (j + n)
	ldrne r10, [r4,r9]		// load pixel at image[i+m][j+n]
	
	mov r9, #255			// move mask into r11
	and r9, r9, r10, lsr r0       	// masks out 8 bits (r0 is 8,16, or 24)
	add r3, r3, r9			// increment sum

	add r2, r2, #3			// increment n by 3
	b for_n_lt_4			// loop to top of n loop

// this block of code does the smooth function equation
// temp[i][j] = crop( (int)(sum/9.0 + 0.5)) 
end_process_color:

	// do equation
	add r1, r3, r3, lsl#3		// multiply sum by 9, store in r1
	add r1, r1, r3			// sum*9 +  sum = sum *10

	add r1, r1, #45			// add 45 to sum * 10	

	// divid by constant (91) (shift right 13, 8 bit precision)
	add r0, r1, r1, lsl#6		// r0 = r1 * 65
	add r0, r0, r1, lsl#4		// r0 = (r1*65) + (r1*16) = r1*81
	add r0, r0, r1, lsl#3		// r0 = r1 * 89
	add r0, r0, r1, lsl#1		// r0 = r1 * 91
	lsr r0, #13			// shift r0 right by 13

	bl crop				// crop r0
	ldmfd   sp!,{r4-r10,lr}
	mov pc, lr
///////////////////////////// end of processing a color pixel /////////////////


// this block of code simply calls free to deallocate the memory of the old
// image.
//////////////////////////// START of freeing old image ///////////////////////
free_old_image:
	stmfd	sp!,{r4-r6,lr}

	ldr r4, [r8, #20]		// load address of rows array old img
	ldr r5, [r8, #12]		// load rows into r5
	lsl r5, #2			// multiply rows by 4
	mov r6, #0			// set i to 0
	
for_i_lt_rows:
	cmp r6, r5			// check if i < rows*4
	bge end_free			// if i > rows*4, go to end

	ldr r0, [r4,r6]			// load rows array + offset
	bl free				// branch to free memory
	
	add r6, r6, #4			// increment i by 4
	b for_i_lt_rows			// branch to top of loop, continue free

end_free:
	ldr r0, [r8, #20] 
	bl free

	ldmfd	sp!, {r4-r6,lr}
	mov pc, lr
/////////////////////////// END of freeing old image //////////////////////////




/////////////////////////// START of fixing up edges //////////////////////////
fix_edges:
	stmfd sp!, {r4-r12,lr}

	ldr r9, [r8, #12]	// get rows
	lsl r9, #2		// rows *4
	ldr r10, [r8, #16]	// get cols
	add r10, r10, r10, lsl#1	// cols * 3

	mov r5, #0		// set row ctr to 0

fix_rows_loop:
	cmp r5, r9
	bge end_fix		//if counter > rows, go to end of function
	mov r6, #0		//set col ctr to 0	

fix_columns_loop:
	add r1, r10, #3
	cmp r6, r1		//compare column counter to #columns * 3 + 3
	addge r5, r5, #4	// increment rows counter
	bge fix_rows_loop		//if r6 > cols, branch to rows_loop

	cmp r5, #0		// special case for first row
	beq border1
after_border1:
	cmp r5, r9		// special case for last row
	beq border2
after_border2:
	cmp r6, #0		//cmp col ctr to 0
	beq border3
after_border3:
	cmp r6, r10		// cmp col ctr to col * 3
	beq border4

end_traverse:
	add r6, r6, #3		//increment column load counter
	b fix_columns_loop		//branch to beginning of columns_loop

border1:
	cmp r6, #0
	beq top_left_corner
	cmp r6, r10		// compare col ctr to cols*3
	beq top_right_corner

border1_cont:
	add r2, r5, #4
	ldr r2, [r4,r2]		// load next row into r2	
	ldr r2, [r2,r6]		// get pixel value from row below		

	mov r1, #0
	ldr r1, [r4,r5]		// load first row
	str r2, [r1,r6]		// store pixel value from below into this spot
	b after_border1
	
top_left_corner:
	add r2, r5, #4		// increment row
	add r3, r6, #3		// increment col
        ldr r2, [r4,r2]         // load next row into r2        
        ldr r2, [r2,r3]         // get pixel value from row below               

	mov r1, #0
        ldr r1, [r4,r5]         // load first row
        str r2, [r1,r6]         // store pixel value from below into this spot
        b border1_cont

top_right_corner:
        add r2, r5, #4          // increment row
        sub r3, r6, #3          // decrement col
        ldr r2, [r4,r2]         // load next row into r2        
        ldr r2, [r2,r3]         // get pixel value from row below               

	mov r1, #0
        ldr r1, [r4,r5]         // load first row
        str r2, [r1,r6]         // store pixel value from below into this spot
        b border1_cont

border2:
	cmp r6, #0		// see if first col in last row
	beq bottom_left_corner
	cmp r6, r10		// see if last col in last row
	beq bottom_right_corner

border2_cont:
        sub r2, r5, #4
        ldr r2, [r4,r2]         // load next row into r2        
        ldr r2, [r2,r6]         // get pixel value from row above               

	mov r1, #0
        ldr r1, [r4,r5]         // load first row
        str r2, [r1,r6]         // store pixel value from above into this spot
        b after_border2

bottom_left_corner:
        sub r2, r5, #4		// subtract a row up
	add r3, r6, #3		// add a col over
        ldr r2, [r4,r2]         // load next row into r2        
        ldr r2, [r2,r3]         // get pixel value from row above               

	mov r1, #0
        ldr r1, [r4,r5]         // load first row
        str r2, [r1,r6]         // store pixel value from above into this spot
        b border2_cont

bottom_right_corner:
        sub r2, r5, #4          // subtract a row up
        sub r3, r6, #3          // subtract a col over
        ldr r2, [r4,r2]         // load next row into r2        
        ldr r2, [r2,r3]         // get pixel value from row above               

	mov r1, #0
        ldr r1, [r4,r5]         // load first row
        str r2, [r1,r6]         // store pixel value from above into this spot
        b border2_cont

border3:
        add r3, r6, #3
        ldr r2, [r4,r5]         // load next row into r2        
        ldr r2, [r2,r3]         // get pixel value from row above               

	mov r1, #0
        ldr r1, [r4,r5]         // load first row
        str r2, [r1,r6]         // store pixel value from above into this spot
        b after_border3

border4:
        sub r3, r6, #3
        ldr r2, [r4,r5]         // load row into r2
        ldr r2, [r2,r3]         // get pixel value from one col to left              

	mov r1, #0
        ldr r1, [r4,r5]         // load first row
        str r2, [r1,r6]         // store pixel value from above into this spot
        b end_traverse

end_fix:
        ldmfd sp!, {r4-r12,lr}
	mov pc, lr

///////////////////////////// END of fixing up edges //////////////////////////
