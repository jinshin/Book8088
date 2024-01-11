	.model tiny
	.code
        org     100h

begin:  jmp     inst

ctrl    db      0
pal	db	0
busy	db	0

txt	db	05Ah

palmask = 11001111b
cmpmask = 11111011b

P:
P11	db 00110000b ;Bright MCW
P12	db 00000000b ;No Burst

P31	db 00100000b ;Dim MCW 
P32	db 00000000b ;No Burst

P21	db 00010000b ;Bright RGY
P22	db 00000000b ;No Burst

P41	db 00000000b ;Dim RGY
P42     db 00000000b ;No Burst

P51	db 00110000b ;Bright RCW
P52	db 00000100b ;Burst On

P61	db 00000000b ;Dim RCW
P62	db 00000100b ;Burst On


chkkey  proc
        in      al,60h
        cmp     al,1Dh
        jne     not_ctrl_press
        mov     cs:ctrl,1
not_ctrl_press:     
	cmp     al,9Dh
        jne     not_ctrl_depress
        mov     cs:ctrl,0
not_ctrl_depress:    
	cmp     al,29h
        jne     not_hk
        cmp	cs:ctrl,1
not_hk:
	ret	;ZF set - key combo pressed
chkkey	endp


int8    proc
        cli
        push    ds
        push    ax
        xor     ax,ax
        mov     ds,ax
        mov     ax,cs
        cmp     word ptr ds:[26h],ax
        jne     ne8
        jmp     unch
ne8:    mov     ax,ds:[24h]
        mov     word ptr cs:old91,ax
        mov     ax,ds:[26h]
        mov     word ptr cs:old91+2,ax
        mov     ax,offset int91
        mov     word ptr ds:[24h],ax
        mov     ax,cs
        mov     word ptr ds:[26h],ax
unch:   pop     ax
        pop     ds
        db      0EAh
old8    dd      0
int8    endp

mult    proc
        cmp     ax,0FF00h
        jne     em
        xchg    ah,al
        iret
em:     db      0EAh
old2F   dd      0
mult    endp

endint  proc
        in      al,61h
        mov     ah,al
        or      al,80h
        out     61h,al
        xchg    ah,al
        out     61h,al
        mov     al,20h
        out     20h,al
        pop     ax
	sti
	call	palp
	mov	cs:busy,0	
        iret
endint  endp

int9    proc
	cli
        push    ax
	cmp	cs:busy,1
	je	exit9
	call	chkkey
	jnz	exit9
	mov	cs:busy,1
	jmp	endint
exit9:  
	pop     ax
        db      0EAh
old9    dd      0
int9    endp

int91   proc
	cli
        push    ax
	cmp	cs:busy,1
	je	exit91
	call	chkkey
	jnz	exit91
	mov	cs:busy,1	
	jmp	endint
exit91: 
	pop     ax
        db      0EAh
old91   dd      0	
int91   endp

palp    proc
        push    ax bx cx dx si ds

	mov	ax,40h
	mov	ds,ax
	
	mov	al,ds:[65h]

	test	al,1
	jz	go_pal

	xor	ax,ax
	mov	dx,3D4h
	out	dx,ax

	xor	cx,cx
aa:
	push	cx
	mov	cx,5
ab:
	in	al,20h
	loop	ab
	pop	cx
	loop	aa

	mov	ax,7100h
	out	dx,ax

	jmp	exitg

	mov	al,cs:txt
	cmp	al,59h
	je	set_crtc_a
	cmp	al,5Ah
	je	set_crtc_b

go_pal:
        xor	ax,ax
	mov	al,cs:pal
	inc	al
	cmp	al,5
	jbe	go_next
	xor	al,al
go_next:
	mov	cs:pal,al
	mov	si,offset P
	shl	ax,1
	add	si,ax
	mov	bx,cs:[si]
;       bh 3D8, bl 3D9
	mov	cx,ds:[65h]
;	cl 65h, ch 66h
        mov	dx,3D8h
	and	cl,cmpmask
	or	cl,bh
	mov	al,cl
	out	dx,al

	inc	dx ;3D9h
	and	ch,palmask
	or	ch,bl
	mov	al,ch
	out	dx,al

	mov	ds:[65h],cx
	jmp	exitg

set_crtc_a:
	mov	ax,5A02h
set:
	mov	dx,3D4h
	out	dx,ax
	mov	cs:txt,ah
	jmp	exitg

set_crtc_b:
	mov	ax,5902h
	jmp	set

exitg:  

	pop	ds si dx cx bx ax
        ret
palp    endp

inst    proc
        jmp     install
mess    db	0Dh,0Ah
	db      'PALTSR (c) 2023-2024 Serhii Liubshin',0Dh,0Ah
        db      'Alters CGA graphic mode palette',0Dh,0Ah
	db	'Resets 80x25 text mode positioning on Book8088 V1/CGA',0Dh,0Ah
alr:    db      'Press Ctrl + ~ (tilde) to change palette',0Dh,0Ah
	db	'or to reset screen in 80x25 text mode',0Dh,0Ah,0Dh,0Ah,'$'
alred   db      'PALTSR already installed',0Dh,0Ah,'$'

install: 
;;	mov	ax,83h
;;	int	10h

;	xor	ax,ax
;	mov	dx,3D4h
;	out	dx,ax

;;	mov	al,1
;;	mov	dx,3D9h
;;	out	dx,al

;	xor	cx,cx
;a:	
;	push	cx
;	mov	cx,6
;b:
;	in	al,20h
;	loop	b
;	pop	cx
;	loop	a

;;	mov	ax,3
;;	int	10h

;	mov	ax,7100h
;	mov	dx,3D4h
;	out	dx,ax

;;	mov	ax,5902h
;;	mov	dx,3D4h
;;	out	dx,ax

	mov     ax,0FF00h
        int     2Fh
        cmp     ax,00FFh
        jne     ins1
        mov     ah,09h
        mov     dx,offset alred
        int     21h
        mov     dx,offset alr
        int     21h
        ret

ins1:   

	mov     dx,offset mess
        mov     ah,09h
        int     21h
        cld
        cli
        xor     ax,ax
        mov     ds,ax
        push    cs
        pop     es
        mov     si,20h
        mov     di,offset old8
        movsw
        movsw
        mov     di,offset old9
        movsw
        movsw
        mov     si,2Fh*4
        mov     di,offset old2F
        movsw
        movsw
        push    ds
        pop     es
        mov     di,20h
        mov     ax,offset int8
        stosw
        mov     ax,cs
        stosw
        mov     ax,offset int9
        stosw
        mov     ax,cs
        stosw
        mov     di,2Fh*4
        mov     ax,offset mult
        stosw
        mov     ax,cs
        stosw
        sti
        mov     dx,offset inst
        int     27h
inst    endp

        end     begin