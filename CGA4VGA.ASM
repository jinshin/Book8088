	.model tiny
	.code
	jumps
        org     100h

begin:  jmp     inst

;Default colors
COLORS:

;Green Red Yellow Low Intensity
;GRYL	db	08,1Fh,08,  1Fh,08,08,   12h,12h,08
;	db	30,30,30,   20,20,20,   40,40,40
GRYL	db	00,42,00,  42,00,00,  42,21,00

;Cyan Magenta White Low 
;CMWL	db	08,1Fh,1Fh, 1Fh,08h,18h, 1Fh,1Fh,1Fh
;	db	38,38,38,   28,28,28,   48,48,48
CMWL	db	00,42,42,  42,00,42,  42,42,42

;Cyan Red White Low (Mode 5)
;CRWL	db	08,1Fh,1Fh, 1Fh,08h,18h, 1Fh,1Fh,1Fh
;	db	38,38,38,   28,28,28,   48,48,48
CRWL	db	00,42,42,  42,00,00,  42,42,42

;Green Red Yellow High
;GRYH	db	10,2Fh,10,  2Fh,10,10,   20h,20h,10
;	db	40,40,40,   30,30,30,   50,50,50
GRYH	db	21,63,21,  63,21,21,  63,63,15

;Cyan Magenta White High
;CMWH	db	10,2Fh,2Fh, 2Fh,10,20h,  2Fh,2Fh,2Fh
;	db	48,48,48,   38,38,38,   58,58,58
CMWH	db	15,63,63,  63,21,63,  63,63,63

;Cyan Red White High (Mode 5)
;CRWH	db	08,1Fh,1Fh, 1Fh,08h,18h, 1Fh,1Fh,1Fh
;	db	38,38,38,   28,28,28,   48,48,48
CRWH	db	21,63,63,   63,21,21,  63,63,63

func	dw	0

MAXV	equ	54
         
int10	proc
	mov	cs:[func],ax
	pushf
	db	09Ah
old10	dd	0
	push	dx ax ds si
	cld
	push	cs
	pop	ds
	mov	ax,[func]
	cmp	ax,4
	je	load_mode4
	cmp	ax,5
	je	load_mode5
	jmp	exit_int

load_mode4:
	mov 	dx,3C8h
	mov	si,offset GRYL
	mov 	al,2
	call	setcol
	mov	al,4
	call	setcol
	mov	al,6
	call	setcol	

	mov	si,offset CMWL
	mov 	al,3
	call	setcol
	mov	al,5
	call	setcol
	mov	al,7
	call	setcol

	mov	si,offset GRYH
	mov 	al,18
	call	setcol
	mov	al,20
	call	setcol
	mov	al,22
	call	setcol

	mov	si,offset CMWH
	mov 	al,19
	call	setcol
	mov	al,21
	call	setcol
	mov	al,23
	call	setcol

	jmp	exit_int

load_mode5:
	mov 	dx,3C8h
	mov	si,offset CRWL
	mov 	al,2
	call	setcol
	mov	al,4
	call	setcol
	mov	al,6
	call	setcol	

	mov	si,offset CRWL
	mov 	al,3
	call	setcol
	mov	al,5
	call	setcol
	mov	al,7
	call	setcol

	mov	si,offset CRWH
	mov 	al,18
	call	setcol
	mov	al,20
	call	setcol
	mov	al,22
	call	setcol

	mov	si,offset CRWH
	mov 	al,19
	call	setcol
	mov	al,21
	call	setcol
	mov	al,23
	call	setcol

	jmp	exit_int

exit_int:
	pop	si ds ax dx
        iret
int10	endp

setcol:
	out 	dx,al
	inc	dx
	lodsb
	out	dx,al
	lodsb	
	out	dx,al
	lodsb	
	out	dx,al
	dec	dx
	ret

mult    proc
        cmp     ax,0FE01h
        jne     em
	push	es di ax
	cld
	push	cs
	pop	es
	mov	di,offset COLORS
	;Quick sanity check
	;We have same offsets, just diff segments
	cmp	di,si	
	jne	exit_mult
	mov	cx,MAXV
	rep	movsb
exit_mult:
	pop	ax di es
        xchg    ah,al
        iret
em:     db      0EAh
old2F   dd      0
mult    endp


;================================================================================

inst    proc

	;Banner
	mov     dx,offset mess
        mov     ah,09h
        int     21h

        jmp     install
mess    db	0Dh,0Ah
	db      'CGA4VGA (c) 2024 Serhii Liubshin',0Dh,0Ah
        db      'Sets colors for CGA modes 4 and 5 on VGA videocard',0Dh,0Ah
	db	0Dh,0Ah,'$'
alred   db      'CGA4VGA already installed. TSR colors updated',0Dh,0Ah,'$'
load_msg	db 'Error loading file', 0dh,0ah,'$'
unrec_msg	db 'Invalid delimiter in file', 0dh,0ah,'$'
number_msg	db 'Invalid color value in file', 0dh,0ah,'$'
incorr_msg	db 'Incorrect number of values in file, must be exactly 54 or 9', 0dh,0ah,'$'
good_msg	db 'Color values loaded', 0dh,0ah,'$'
tsr_msg	db 'Installed. Run w/o parameters to reset colors to defaults',0Dh,0Ah 
	db 'or specify configuration file to update color values from',0Dh,0Ah,'$'

skip_spaces	macro
local	@@skipb
@@skipb:
	lodsb
	sub	bp,1
	js	end_cmd_process
	cmp	al,20h ;' '
	jz	@@skipb
	cmp	al,0Dh
	jz	end_cmd_process
endm

put_chars macro
local	@@next, @@fin
	mov	cx,64
@@next:
	stosb
	lodsb
	sub	bp,1	
	js	@@fin
	cmp	al,20h
	jz	@@fin
	cmp	al,0Dh
	jz	@@fin
	loop	@@next
@@fin:  
	xor	al,al
	stosb	
endm

install: 
	cld
	mov	si,80h
	xor	ax,ax
	lodsb
	mov	bp,ax
	test	bp,bp
	jz	no_parameter

	xor	ax,ax
	mov	es:[infile],al
	mov	di,offset infile
	skip_spaces	
	put_chars

end_cmd_process:

	mov	al,es:[infile]
	cmp	al,0
	jz	no_parameter

;Load file

	mov	ah,3Dh         ; Function 3Dh - Open file
	mov	al,0           ; Open for reading
	mov	dx,offset infile ; Pointer to filename
	int	21h
	jc	load_error

	mov	bx,ax ; BX holds the file handle

	mov	dx,offset buf
	mov	ah,3Fh         ; Function 3Fh - Read file
	mov	cx,1024
	int	21h

	jnc	load_ok                                                 

load_error:
	mov	dx,offset load_msg
	mov	ah,9
	int	21h

	mov	ax,4C01h
	int	21h

load_ok:
	mov	[inlen],ax
	mov	ah,3Eh         ; Function 3Eh - Close file
	int	21h

	mov	si, offset buf
	mov	di, offset COLORS
	mov	bp,[inlen]
	inc	bp

	xor	ax,ax
	xor	cx,cx

next_val:
	xor	bx,bx
	dec	bx
next_num:
	lodsb
	dec	bp
	jnz	next_one	;if we have a number, push it
	test	bx,bx
	js	no_pend
	mov	al,bl
	cmp	al,3Fh
	ja	too_big
	inc	cx
	cmp	cx,MAXV
	ja	incorr
	stosb
no_pend:
	jmp	end_process
next_one:
	cmp	al,30h
	jb	not_digit
	cmp	al,39h
	ja	not_digit

	sub	al,30h
	test	bx,bx		;are we processing number?
	jns	next_digit	
	xor	bx,bx
	mov	bx,ax
	jmp	next_num
	
next_digit:
	add	bx,bx
	mov	dx,bx
	add	bx,bx
	add	bx,bx
	add	bx,dx
	add	bx,ax
	jmp	next_num	

not_digit:
	test	bx,bx
	js	no_number
;Push number	
	mov	al,bl
	cmp	al,3Fh
	ja	too_big
	inc	cx
	cmp	cx,MAXV
	ja	incorr
	stosb
	jmp	next_val

no_number:
	cmp	al,'#'
	je	skip_comment
	cmp	al,';'
	je	skip_comment
;Delimiters
	cmp	al,' '
	je	next_val	
	cmp	al,','
	je      next_val
	cmp	al,08
	je	next_val	
	cmp	al,0Dh
	je	next_val
	cmp	al,0Ah
	je	next_val

	mov	dx,offset unrec_msg
	mov	ah,9
	int	21h
	jmp	exii

too_big:
	mov	dx,offset number_msg
	mov	ah,9
	int	21h
	jmp	exii

incorr:
	mov	dx,offset incorr_msg
	mov	ah,9
	int	21h
	jmp	exii

exii:
	mov	ax,4C01h
	int	21h	
	
skip_comment:
	lodsb
	dec	bp
	jz	end_process	
	cmp	al,0Ah
	jne	skip_comment
	jmp	next_val	

end_process:	
	;How many color values we got?
	cmp	cx,MAXV
	je	go_go
	cmp	cx,9
	jne	incorr

	;Copy first palette to all other
	mov	si,offset colors
	mov	di,offset CMWL
	mov	cx,9
	rep	movsb
	mov	cx,9
	rep	movsb
	mov	cx,9
	rep	movsb
	mov	cx,9
	rep	movsb
	mov	cx,9
	rep	movsb
	
go_go:
	mov	dx,offset good_msg
	mov	ah,9
	int	21h

;Check if we already resident and update colors
no_parameter:
	mov	si,offset COLORS
	mov     ax,0FE01h
        int     2Fh
        cmp     ax,01FEh
        jne     ins1

        mov     ah,09h
        mov     dx,offset alred
        int     21h
        ret

ins1:   

        cld
        cli
        xor     ax,ax
        mov     ds,ax
        push    cs
        pop     es

        mov     si,10h*4
        mov     di,offset old10
        movsw
        movsw

        mov     si,2Fh*4
        mov     di,offset old2F
        movsw
        movsw
        push    ds
        pop     es

        mov     di,10h*4
        mov     ax,offset int10
        stosw
        mov     ax,cs
        stosw

        mov     di,2Fh*4
        mov     ax,offset mult
        stosw
        mov     ax,cs
        stosw
	sti

	push	cs
	pop	ds
	mov	dx,offset tsr_msg
	mov	ah,9
	int	21h	

        mov     dx,offset inst
        int     27h
inst    endp

inlen	dw	?
infile	db	64 dup (?)
buf	db	1024 dup (?)

        end     begin