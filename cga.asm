	cpu	8086
	org	100h

	mov	ah,9
	mov	dx,banner
	int	21h

	mov	bh,66h	;test value
	mov	dx,3D4h
	mov	al,0Fh
	out	dx,al
	inc 	dx	;3D5h
	in	al,dx	;get cursor pos
	mov	bl,al	;save

	mov	al,bh	;set cursor pos
	out	dx,al

	push	cx	;wait a bit
	mov	cx,5
.wait:
	loop	.wait
	pop	cx

	in	al,dx	;get cursor pos
	mov	ah,al	

	mov	al,bl   ;restore cursor pos
	out	dx,al

	cmp	ah,bh	;compare test value to cursor pos
	jnz	.nope
	mov	ah,9
	mov	dx,cga
	int	21h
	mov	ax,4C00h	;terminate without error
	int	21h
.nope:
	mov	ah,9
	mov	dx,no_cga
	int	21h
	mov	ax,4C00h	;terminate with error
	int	21h

banner	db	'CGA Detect (C) 2023 Serhii Liubshin',0Dh,0Ah,'$'
cga	db	'Card detected!',0Dh,0Ah,'$'
no_cga	db	'Card not detected!',0Dh,0Ah,'$'

		