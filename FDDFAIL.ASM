int_num equ      13h

        .MODEL TINY
        .CODE
        ORG 100h
BEGIN:  jmp      install

newint  proc
        push    ds es si di dx cx bx ax
;this code is meant to be readable not fast
;A:?
        cmp	dl,00
        jz      @skip
;B:?
	cmp	dl,01
	jz	@skip
	jmp	@exit
@skip:
        pop     ax bx cx dx di si es ds
;return fail
	mov	ah,0aah
	stc
        iret
@exit:  pop     ax bx cx dx di si es ds
;it's just a jump to old int 13h vector
        db      0EAh
oldint  dd      0
newint  endp


install proc
        cli
        cld
        push      ds es
        xor       ax,ax
        mov       ds,ax
        mov       si,int_num*4
        mov       di,offset oldint
        movsw
        movsw
        xor       ax,ax
        mov       es,ax
        mov       di,int_num*4
        mov       ax,offset newint
        stosw
        mov       ax,cs
        stosw
        sti
        pop       es ds
	mov	  ah,9
	mov	  dx,offset message
	int	  21h
        mov       dx,offset install
        int       27h
        ret
install endp

message db "Quick fail on FDD access TSR",0Dh,0Ah  
	db "2023 (Yes, 2023) Serhii Liubshin",0Dh,0Ah,"$"

        END BEGIN

