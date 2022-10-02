.286
.model small

.stack 100h 

.data
    snakelen DW 3
    snakedir DW 01b
    active_page DB 0

SQUARE STRUC
  COORDX DW ?
  COORDY DW ?
SQUARE ENDS

fruit EQU <[bp-4]>

green EQU 10b
magenta EQU 11b
darkblue EQU 01b
black EQU 00b

   
.code
main PROC FAR

    push ds
    push 0

    push bp    ; set stack frame 
    mov bp, sp

    mov ax, @data
    mov ds, ax

    sub sp, 4  ; one local: fruitpos

    mov snakelen, 3
    mov snakedir, 01b ; 01=right, 00=left, 11 = down, 10=up
    mov fruit.COORDX, 89
    mov fruit.COORDY, 42

    mov ah, 0h  ; Enter VGA mode (300x200 pixels)
    mov al, 0Dh
    int 10h

    mov ah, 05h ; switch to page 0
    mov al, active_page
    int 10h

    mov ah, 0bh ; set color palette
    mov bh, 01h
    int 10h

    mov dx, 10

    ; allocate memory for the array that will represent the snake
    mov ah, 48h
    mov bx, 1 ; 43 paragraphs of memory (16 * 43 bytes, 776 bytes)
    int 21h ; that is the maximum amount of memory needed to
    ; store a hypothetical 13*13 length snake (13*13 * 2 * 2) (169 len, 2 coords per               ; square, 2 bytes per coord, assuming max len, where player wins
    ; ax will hereafter contain the segment address of the allocated block
    ; bx will contain the number of free paragraphs remaining, mais on s'en fous

    pushf
    jc exitprox ; program exits immediately if memory allocation fails

    mov es, ax ; es segment register now points to free block seg address.

    mov bx, 0
    mov (es:[bx]).COORDX, 102
    mov (es:[bx]).COORDY, 16

    add bx, 4
    mov (es:[bx]).COORDX, 89
    mov (es:[bx]).COORDY, 16

    add bx, 4
    mov (es:[bx]).COORDX, 76
    mov (es:[bx]).COORDY, 16

    exitprox:
        popf
        jc  exitpr

     game_loop:
        xor active_page, 1
        call ClearScreen
        call DrawGrid

        push green
        push fruit.COORDY
        push fruit.COORDX
        push 12

        call DrawSquare ; there's no invoke call in masm 5.0 you have to
                        ; pass the parameters manually
        add sp, 8
        mov bx, 0

        draw_snake:
            push magenta
            shl bx, 2
            push (es:[bx]).COORDY
            push (es:[bx]).COORDX
            push 12
            shr bx, 2

            call DrawSquare
            add sp, 8  ; clean callstack
            inc bx
            cmp bx, snakelen
            jl draw_snake

        call UpdateSnake
       ; mov cx, 65500
       ; delay:
          ;  nop
         ;   nop
        ;    nop
       ; loop delay

        mov ah, 05h
        mov al, active_page
        int 10h

        dec dx
        jnz game_loop
                
    mov ah, 49h ; free memory pointed by es
    int 21h
    exitpr:
    mov sp, bp
    pop bp

    ret

main ENDP

DrawSquare PROC NEAR ; push color, coordy, coordx and side length in that order

    push bp
    mov bp, sp

    sub sp, 2   ; allocate 2 bytes for a local

    pusha       ; save all registers, restore them after the function ends

    mov al, [bp + 4] ; mov to al the square side length
    mov byte ptr [bp-2], al
    mov byte ptr [bp-1], 0

    mov ah, 0ch ; write pixel call
    mov al, [bp + 10] ; color
    mov bh, active_page ; page number (no idea what this is, i'll look it up later) UPDATE: Now I know what this is.
    
    mov dx, [bp + 8]

    draw_loop_y:

        mov cx, [bp + 6]

        mov bl, [bp + 4]

        draw_loop_x:
            int 10h
            inc cx
            dec bl
            jnz draw_loop_x
       
        inc dx
        dec byte ptr [bp - 2]
    jnz draw_loop_y

    popa
    mov sp, bp
    pop bp ; restore caller bp and return
    retn


DrawSquare ENDP

UpdateSnake PROC NEAR
    push bp
    mov bp, sp

    pusha

    mov bx, snakelen ; holds an index to the nth element
    dec bx

    update_snake:
        mov si, bx ; holds an index to the nth - 1 element
        dec si

        shl bx, 2
        shl si, 2

        mov dx, word ptr (es:[si]).COORDX
        mov word ptr (es:[bx]).COORDX, dx
        mov dx, word ptr (es:[si]).COORDY
        mov word ptr (es:[bx]).COORDY, dx

        shr bx, 2
        dec bx

        jnz update_snake

    mov cx, -13
    push cx
    mov cx, snakedir
    and cx, 1
    mov ax, 26
    mul cx
    pop cx

    add cx, ax ; if snake dir is down or right, we add 26 to -13 = 10 and that
    ; will be added to the X or Y coord. If its left or up we add 0 = -10
    push cx

    mov cx, snakedir
    and cx, 10b ; test the second bit (to see to which coord we are going to modify)
    shr cx, 1 ;

    mov ax, 2
    mul cx  ; either we add 2 or 0 to the base offset (0 coordx, 2 coordy)
    mov bx, ax
    pop cx

    add word ptr es:[bx], cx

    popa
    mov sp, bp
    pop bp
    retn
UpdateSnake ENDP

ClearScreen PROC NEAR ; this procedure... well... clears the screen...
    push bp
    mov bp, sp
    push 170

    pusha

    mov ah, 0ch
    mov al, black
    mov bh, active_page
    mov dx, 15

    mov bl, 170 ; dx counter

    clsy:
        mov cx, 75
        mov bl, 170

        clsx:
            int 10h
            inc cx
            dec bl
            jnz clsx
        inc dx
        dec byte ptr [bp - 2]
        jnz clsy
 
    popa
    mov sp, bp
    pop bp
    retn

ClearScreen ENDP

DrawGrid PROC NEAR ; draw a 0Dh*0Dh grid

  push bp
  mov bp, sp

  push 14

  pusha

  mov ah, 0ch
  mov bh, active_page
  mov al, darkblue

  mov dx, 15

  draw_grid_y: ; horizontal grid

    mov cx, 75
    mov bl, 170

    draw_grid_x:
        int 10h
        inc cx
        dec bl
        jnz draw_grid_x

   add dx, 13 ; it will be a 13*13 grid with each rectangle being 12*12 pixels 
   dec byte ptr [bp - 2]
   jnz draw_grid_y

   mov cx, 75
   add byte ptr [bp - 2], 14

   draw_grid_x_v:
        mov dx, 15
        mov bl, 169
        draw_grid_y_v:
            int 10h
            inc dx
            dec bl
            jnz draw_grid_y_v

       add cx, 13
       dec byte ptr [bp - 2]
       jnz draw_grid_x_v

   popa
   mov sp, bp
   pop bp

   ret

DrawGrid ENDP
END main
