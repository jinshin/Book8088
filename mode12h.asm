; Mode 12H test program
; (c) 2024 Serhii Liubshin
; 
	.model tiny
	.code
	org	100h
begin:
	mov	ax,0F00h
	int	10h
	push	ax
	mov	ax,0012h
	int	10h
	mov	cx,79
a:
	push	cx
	mov	ah,9
	mov	dx,offset message
	int	21h
	pop	cx
	loop	a
	xor	ax,ax
	inc	ax
	int	16h
	pop	ax
	xor	ah,ah
	int	10h
	ret	

message	db	"Mode 12h 640x480x16 set!        ","$"
	end	begin