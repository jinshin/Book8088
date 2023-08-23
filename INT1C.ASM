	.model tiny
	.code
        org     100h

begin:  jmp     inst


int8    proc
        cli
        push    ds
        push    ax
        xor     ax,ax
        mov     ds,ax
        mov     ax,cs
        cmp     word ptr ds:[1Ch*4+2],ax
        jne     ne8
        jmp     unch
ne8:    mov     ax,ds:[1Ch*4]
        mov     word ptr cs:old1c2,ax
        mov     ax,ds:[1Ch*4+2]
        mov     word ptr cs:old1c2+2,ax
        mov     ax,offset int1c2
        mov     word ptr ds:[1Ch*4],ax
        mov     ax,cs
        mov     word ptr ds:[1Ch*4+2],ax
unch:   pop     ax
        pop     ds
        db      0EAh
old8    dd      0
int8    endp

int1c   proc
	push	ax bx cx dx si di es ds
	pushf
        db      09Ah
old1c   dd      0
	pop	ds es di si dx cx bx ax
	iret	
int1c   endp


int1c2  proc
	push	ax bx cx dx si di es ds
	pushf
        db      09Ah
old1c2  dd      0
	pop	ds es di si dx cx bx ax
	iret	
int1c2  endp


inst    proc
        jmp     instal
mess    db      'INT 1Ch test',0Dh,0Ah,'$'

instal: 

ins1:   mov     dx,offset mess
        mov     ah,09h
        int     21h
        cld
        cli

        xor     ax,ax
        mov     ds,ax
        push    cs
        pop     es

        mov     si,08h*4
        mov     di,offset old8
        movsw
        movsw

	mov	si,1Ch*4
        mov     di,offset old1c
        movsw
        movsw

        push    ds
        pop     es
        mov     di,08h*4
        mov     ax,offset int8
        stosw
        mov     ax,cs
        stosw

	mov	di,1Ch*4
        mov     ax,offset int1c
        stosw
        mov     ax,cs
        stosw

        sti
        mov     dx,offset inst
        int     27h
inst    endp

        end     begin