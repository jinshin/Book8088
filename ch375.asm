; CH375 Testing 

cpu	8086
org	100h

cmd_port	equ	261h
data_port	equ	260h

%define	cmd_get_status	22h
%define	cmd_disk_unlock	23h
%define cmd_disk_init	51h
%define	cmd_disk_size	53h
%define	cmd_disk_ready	59h
%define	cmd_read_disk	54h
%define	cmd_read_cont	55h
%define	cmd_write_disk	56h
%define	cmd_write_cont	57h

%define	cmd_disk_sense	5Ah
%define cmd_disk_inquiry 58h 

%define	cmd_read_buffer	28h
%define	cmd_write_buffer 2Bh		

%define	cmd_set_mode	15h
%define	cmd_abort_nak	17h

;Status
%define usb_success	14h
%define usb_connect	15h
%define usb_disconnect	16h
%define	usb_ready	18h
%define	read_ok		1Dh
%define	write_ok	1Eh

jmp	begin

fd_sectors	db	0
fd_heads	db	0

E1	db	'Mode set error',0Dh,0Ah,'$'
E2	db	'Disk init error',0Dh,0Ah,'$'
E3	db	'Disk size error',0Dh,0Ah,'$'
E4	db	'Disk ready error',0Dh,0Ah,'$'

O1	db	'Disk initialized',0Dh,0Ah,'$'

E5	db	'Read command error',0Dh,0Ah,'$'
E6	db	'Read buffer error',0Dh,0Ah,'$'

O2	db	'Boot sector read OK',0Dh,0Ah,'$'

O3	db	'Boot sector validated',0Dh,0Ah,'$'
E7	db	'Boot sector data invalid',0Dh,0Ah,'$'

E8	db	'Boot sector read error',0Dh,0Ah,'$'

outfile	db	'boot_sec',0

write_cmd:
	push	dx
	mov	dx,cmd_port
	out	dx,al
	call	short_delay
	pop	dx
	ret

write_data:
	push	dx
	mov	dx,data_port
	out	dx,al
	call	short_delay
	pop	dx
	ret

read_data:
	push	dx
	mov	dx,data_port
	in	al,dx
	pop	dx
	ret

short_delay:
	nop
	nop
	ret

long_delay:
	push	ax
	push	cx
	mov	cx,250
.loopa:	
	in	al,20h
	loop	.loopa
	pop	ax
	pop	cx
	ret

wait_interrupt:
	push	dx
	push	cx
	xor	cx,cx
	mov	dx,cmd_port
.waitmore:
	inc	cx
	cmp	cx,0FFFFh
	je	.wait_end
	in	al,dx
	test	al,80h
	jnz	.waitmore
.wait_end:
	pop	cx
	pop	dx
	ret

wait_status:
	call	wait_interrupt
	mov	al,cmd_get_status
	call	write_cmd
	call	read_data
	ret

get_status:
	mov	al,cmd_get_status
	call	write_cmd
	call	read_data
	ret

begin:

reset_controller:
	mov	al,cmd_set_mode
	call	write_cmd
	mov	al,6
	call	write_data
	call	wait_status
	cmp	al,usb_connect
	je	.next1

	mov	dx,E1
	mov	ah,9
	int	21h	

	ret

.next1:
	call	long_delay
	mov	al,cmd_disk_init
	call	write_cmd
	call	wait_status
	cmp	al,usb_success
	je	.next2

	mov	dx,E2
	mov	ah,9
	int	21h	

	stc
	ret
	
.next2:
;You need to do that, or init is not considered complete by CH375
	mov	cx,5
.rep1:
	mov	al,cmd_disk_size
	call	write_cmd
	call	wait_status
	cmp	al,usb_success
	je	.next3
	mov	al,cmd_disk_sense
	call	write_cmd
	call	long_delay
	loop	.rep1

	mov	dx,E3
	mov	ah,9
	int	21h	

	stc
	ret
.next3:
;You need to do that, or init is not considered complete by CH375
	mov	cx,5
.rep2:
	mov	al,cmd_disk_ready
	call	write_cmd
	call	wait_status
	cmp	al,usb_success
	je	.next4
	mov	al,cmd_disk_sense
	call	write_cmd
	call	long_delay
	loop	.rep2

	mov	dx,E4
	mov	ah,9
	int	21h	


	stc
	ret
.next4:

	mov	dx,O1
	mov	ah,9
	int	21h	



	mov	al,cmd_read_disk
	call	write_cmd
;Read one boot sector and extract media info
	xor	al,al
	call	write_data
	call	write_data
	call	write_data
	call	write_data
;1 sector
	mov	al,1
	call	write_data

	mov	dx,data_port
	xor	ax,ax

	call	wait_status
	cmp	al,read_ok
	je	.readbuffer

	mov	dx,E5
	mov	ah,9
	int	21h	

	stc
	ret
.readbuffer:
	mov	al,cmd_read_buffer
	call	write_cmd
	call	read_data
;buffer should be 64
	cmp	al,40h
	je	.transfer

	mov	dx,E6
	mov	ah,9
	int	21h	

	stc
	ret
.transfer:
	mov	cx,13h
;skip to number of total sectors
.skip1:
	in	al,dx
	loop	.skip1
;get that
	in	al,dx
	mov	ah,al
	in	al,dx
	xchg	al,ah

;	mov	[fd_totalsectors],ax

;skip to sectors per track/head
	in	al,dx
	in	al,dx
	in	al,dx
;get sectors
	in	al,dx
	mov	[fd_sectors],al
;skip high part
	in	al,dx
;get heads
	in	al,dx
	mov	[fd_heads],al

;that's dumb, but you need to 'continue read' until usb_success
;i coudn't find a better way

	mov	cx,8
dumbloop:	
	mov	al,cmd_read_cont
	call	write_cmd
	call	wait_status
	cmp	al,usb_success
	je	exit_dumb
	loop	dumbloop

exit_dumb:

	mov	dx,O2
	mov	ah,9
	int	21h	

;quick sanity check
	mov	al,[fd_heads]
	cmp	al,0
	je	bad_exit
	cmp	al,2
	ja	bad_exit
	
	mov	al,[fd_sectors]
	cmp	al,8
	jb	bad_exit
	cmp	al,36
	ja	bad_exit

	mov	dx,O3
	mov	ah,9
	int	21h	

	jmp	save_boot

bad_exit:

	mov	dx,E7
	mov	ah,9
	int	21h

save_boot:

	cld	;!
	mov	di,buf

;convert 512b sectors to 64b chunks
	xor	cx,cx	;one sector
	inc	cx

	xor	bx,bx	;LBA 0

	push	cx
	shl	cx,1
	shl	cx,1
	shl	cx,1	
;start
	mov	al,cmd_read_disk
	call	write_cmd
;65535 sectors are our maximum
	mov	al,bl
	call	write_data
	mov	al,bh
	call	write_data
	xor	al,al
	call	write_data
	call	write_data
;sectors
	pop	ax ;cx->ax
	call	write_data

	mov	dx,data_port
	xor	ax,ax

.main:	
	call	wait_status
	cmp	al,read_ok
	je	.readbuffer
	stc
	jmp	.exit
.readbuffer:
	mov	al,cmd_read_buffer
	call	write_cmd
	call	read_data
;buffer should be 64
	cmp	al,40h
	je	.transfer

	mov	dx,E8
	mov	ah,9
	int	21h

	stc
	jmp	.exit
.transfer:
        push	cx
	mov	cx,ax
.readl:
	in	al,dx
	stosb
	loop	.readl
	pop	cx
;continue
	mov	al,cmd_read_cont
	call	write_cmd
	loop	.main
	clc
	test	cx,cx
	jz	.exit
	stc
.exit:		

;Write file
	mov	ah,3Ch         
	mov	dx,outfile ; Pointer to filename
	int	21h
	jc	.write_error

	mov	bx,ax ; BX holds the file handle

	mov	cx,512
	mov	dx,buf

	mov	ah,40h 
	int	21h
	jc	.write_error

	mov	ah,3Eh         ; Function 3Eh - Close file
	int	21h


.write_error:


	stc
	ret



	ret

buf	db	512 dup (0)
