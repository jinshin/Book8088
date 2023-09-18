	cpu		8086
	org		100h

;We just dump two full segments of BIOS and VideoROM

	xor	cx,cx
	mov	ah,3Ch
	mov	dx,mbios_name
	int	21h
	jc	write_error

	mov	bx,ax

	mov	cx,08000h
	push	ds
	mov	ax,0F000h
	mov	ds,ax
	xor	dx,dx
	mov	ah,40h 
	int	21h
	pop	ds
	jc	write_error

	mov	cx,08000h
	push	ds
	mov	ax,0F800h
	mov	ds,ax
	xor	dx,dx
	mov	ah,40h 
	int	21h
	pop	ds
	jc	write_error

	mov	ah,3Eh
	int	21h

	jmp	write_video_rom

write_error:
	mov	dx,error
	mov	ah,9
	int	21h

	mov	ax,4C01h
	int	21h

write_video_rom:

	xor	cx,cx
	mov	ah,3Ch         
	mov	dx,vbios_name
	int	21h
	jc	write_error

	mov	bx,ax

	mov	cx,08000h
	push	ds
	mov	ax,0C000h
	mov	ds,ax
	xor	dx,dx
	mov	ah,40h 
	int	21h
	pop	ds
	jc	write_error

	mov	cx,08000h
	push	ds
	mov	ax,0C800h
	mov	ds,ax
	xor	dx,dx
	mov	ah,40h 
	int	21h
	pop	ds
	jc	write_error

	mov	ah,3Eh
	int	21h

	mov	dx,done
	mov	ah,9
	int	21h

	mov	ax,4C00h
	int	21h


mbios_name	db	'mbios.bin',0
vbios_name	db	'vbios.bin',0
error		db	'Error',0dh,0ah,'$'
done		db	'Done',0dh,0ah,'$'