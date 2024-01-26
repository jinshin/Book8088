;This code implements floppy int 13h

cpu		8086

int_num		equ	13h

; This code implements floppy int 13h
; emulation via ch375 chip
; parts taken from floppy1.inc and floppy2.inc for compatibility
; Made by Serhii Liubshin, 2023

cmd_port	equ	261h
data_port	equ	260h

;We use some reserved BDA bytes
;to store media info
;I've checked - it's unused in Book8088
fd_enabled	equ	0ACh
fd_media	equ	0ADh
fd_heads	equ	0AEh
fd_sectors	equ	0AFh
;fd_totalsectors	equ	0B0h

%define	cmd_get_status	22h
%define	cmd_disk_unlock	23h
%define cmd_disk_init	51h
%define	cmd_disk_size	53h
%define	cmd_disk_ready	59h
%define	cmd_read_disk	54h
%define	cmd_read_cont	55h
%define	cmd_write_disk	56h
%define	cmd_write_cont	57h
;%define	cmd_disk_sense	59h
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

; offsets for registers on stack
int_13_bp	equ	0
int_13_ds	equ	int_13_bp+2
int_13_di	equ	int_13_ds+2
int_13_si	equ	int_13_di+2
int_13_dx	equ	int_13_si+2
int_13_dl	equ	int_13_dx
int_13_dh	equ	int_13_dx+1
int_13_cx	equ	int_13_dx+2
int_13_cl	equ	int_13_cx
int_13_ch	equ	int_13_cx+1
int_13_bx	equ	int_13_cx+2
int_13_bl	equ	int_13_bx
int_13_bh	equ	int_13_bx+1
int_13_ax	equ	int_13_bx+2
int_13_al	equ	int_13_ax
int_13_ah	equ	int_13_ax+1
int_13_ip	equ	int_13_ax+2
int_13_cs	equ	int_13_ip+2
int_13_flags	equ	int_13_cs+2
int_13_flags_l	equ	int_13_flags

fdc_m_360in360		equ	93h	; 250 Kbps, established, 360K in 360K
fdc_m_720		equ	97h	; 250 Kbps, established, other drive
fdc_m_try_360in1200	equ	61h	; 300 Kbps, not established, 360K in 1.2
fdc_m_360in1200		equ	74h	; 300 Kbps, established, 360K in 1.2M
fdc_m_try_1200in1200	equ	02h	; 500 Kbps, not established, 1.2M in 1.2
fdc_m_1200in1200	equ	15h	; 500 Kbps, established, 1.2M in 1.2M
fdc_m_try_1440		equ	07h	; 500 Kbps, not established, other drive
fdc_m_1440		equ	17h	; 500 Kbps, established, other drive
fdc_m_try_2880		equ	0C7h	; 1 Mbps, not established, other drive
fdc_m_2880		equ	0D7h	; 1 Mbps, established, other drive

bioscseg	equ	0F000h
biosdseg	equ	0040h

equipment_list	equ	10h	; word - equpment list
equip_floppies	equ	0000000000000001b	; floppy drivers installed

fdc_last_error	equ	41h	; byte - status of last diskette operation

fdc_e_success	equ	00h		; successful completion
fdc_e_invalid	equ	01h		; invalid function or parameter
fdc_e_address	equ	02h		; address mark not found
fdc_e_wprotect	equ	03h		; disk write-protected
fdc_e_notfound	equ	04h		; sector not found
fdc_e_changed	equ	06h		; disk changed
fdc_e_dma	equ	08h		; DMA overrun
fdc_e_boundary	equ	09h		; attempted DMA across 64K boundary
fdc_e_format	equ	0Ch		; not supported or drive type unknown
fdc_e_crc	equ	10h		; uncorrectable CRC error on read
fdc_e_failure	equ	20h		; controller failure
fdc_e_seek	equ	40h		; seek failed
fdc_e_timeout	equ	80h		; timeout / device not ready

type_none	equ	00h
type_360	equ	01h
type_1200	equ	02h
type_720	equ	03h
type_1440	equ	04h
type_2880	equ	06h


	org	100h
	jmp	install

;Logic for reading/writing:
;Init read by sending command, following by LBA offset and number of sectors
;Then send a command to read buffer and read data port
;Next, send 'continue read' command, following by read buffer command
;buffer size is 64 bytes, so for one sector it would be 1 read and 7 continue commands
;i didn't find a way to abort initiated read/write, so only dumb exhaust here.

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


;Do a full reset

;Mode:
;00H = Disabled device mode, 01H = Enabled device mode using external firmware mode,
;02H = Enabled device mode using internal firmware mode
;04H = Disabled host mode, 05H = Enabled host mode,
;06H = Enabled host mode with automatic generation of SOF packets, 07H = Enabled host mode and reset USB bus
;Output: Operation status (CMD_RET_SUCCESS or CMD_RET_ABORT, other values indicate that the operation is not completed) 

reset_controller:
	mov	al,cmd_set_mode
	call	write_cmd
	mov	al,6
	call	write_data
	call	wait_status
	cmp	al,usb_connect
	je	.next1
	stc
	ret

.next1:
	call	long_delay
	mov	al,cmd_disk_init
	call	write_cmd
	call	wait_status
	cmp	al,usb_success
	je	.next2
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
	stc
	ret
.next4:
	clc
	ret

;=================================
; Write sectors to USB
; ES - caller data segment
; DX:AX - LBA 
;
; If boot sector overwritten
; reinit our media data
;
write_sectors:

	push	ds
	push	ax
	push	dx
	xor	cx,cx
	mov	cl,[bp+int_13_al]
	test	cl,cl
	jnz	.next1
	stc
	jmp	.exit
.next1:

	mov	bx,ax	
	mov	si,[bp+int_13_bx]

	cld
;convert 512b sectors to 64b chunks
	push	cx
	shl	cx,1
	shl	cx,1
	shl	cx,1	
;start
	mov	al,cmd_write_disk
	call	write_cmd
;LBA
	mov	al,bl
	call	write_data
	mov	al,bh
	call	write_data
	mov	al,dl
	call	write_data
	mov	al,dh
	call	write_data
;sectors
	pop	ax ;cx->ax
	call	write_data

;DS:SI is input buffer
	push	es
	pop	ds

.main:	
	call	wait_status
	cmp	al,write_ok
	je	.writebuffer
	stc
	jmp	.exit
.writebuffer:
	mov	al,cmd_write_buffer
	call	write_cmd
	mov	al,40h
	call	write_data

	mov	dx,data_port

%rep	40h
	lodsb
	out	dx,al
%endrep

	mov	al,cmd_write_cont
	call	write_cmd
	dec	cx
	jz	.done
	jmp	.main
.done:
	call	wait_status
	stc
	cmp	al,usb_success
	jne	.exit
	clc

.exit:		

;If that was a write to sector 0, reread media info
	pop	dx
	pop	ax
	pop	ds
	jc	.e2
	test	ax,ax
	jnz	.e2
	test	dx,dx
	jnz	.e2

	call	read_boot
.e2:
	ret

;=================================
; Read sectors from USB
; ES - caller data segment
; DX:AX - LBA 
;
read_sectors:

	xor	cx,cx
	mov	cl,[bp+int_13_al]
	test	cl,cl
	jnz	.next1
	stc
	jmp	.exit
.next1:
	mov	bx,ax	
	mov	di,[bp+int_13_bx]

	cld
;convert 512b sectors to 64b chunks
	push	cx
	shl	cx,1
	shl	cx,1
	shl	cx,1	
;start
	mov	al,cmd_read_disk
	call	write_cmd

	mov	al,bl
	call	write_data
	mov	al,bh
	call	write_data
	mov	al,dl
	call	write_data
	mov	al,dh
	call	write_data

;sectors
	pop	ax ;cx->ax
	call	write_data

	mov	dx,data_port

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
	stc
	jmp	.exit
.transfer:

%rep	40h	
	in	al,dx
	stosb
%endrep

	mov	al,cmd_read_cont
	call	write_cmd
	dec	cx
	jz	.done
	jmp	.main
.done:
	call	wait_status
	stc
	cmp	al,usb_success
	jne	.exit
	clc
.exit:		
	ret

;Floppy boot sector structure

;0 – 2	Assembly Instruction for jump code.
;3 – 10	OEM Name.
;11 – 12	Bytes per sector.
;13	Sector per cluster.
;14 – 15	Number of reserved sector(Boot Sector)
;16	Number of File Allocation Table
;17 – 18	Maximum entries possible under root directory.
;19 – 20	Total number of sectors in file system.
;21	Media Type(According to Microsoft 0xf8 for fixed disk and 0xf0 for removable disk.
;Seen other values (0xF9 for example) here
;22 – 23	Sectors allocated for each File allocation table.
;24 – 25	Sectors per track.
;26 – 27	Number of head in storage device.
;28 – 31	Number of sectors before start of partition(Not applicable for floppy).
;32 – 35	Number of sectors in file system(32-bit value, not applicable for floppy).
;36	BIOS INT13h drive number.
;37	Not Used.
;38	Extended boot signature.
;39 – 42	Volume Serial Number.
;43 – 53	Volume label in ASCII.
;54 – 61	File System Type.
;62 – 509	Boot Code, otherwise contains information to replace disk.
;510 – 511	Signature for File System.


;F0     2.88 MB    3.5-inch, 2-sided, 36-sector
;F0     1.44 MB    3.5-inch, 2-sided, 18-sector
;F9     720K       3.5-inch, 2-sided, 9-sector
;F9     1.2 MB     5.25-inch, 2-sided, 15-sector
;FD     360K       5.25-inch, 2-sided, 9-sector
;FF     320K       5.25-inch, 2-sided, 8-sector
;FC     180K       5.25-inch, 1-sided, 9-sector
;FE     160K       5.25-inch, 1-sided, 8-sector
;FE     250K       8-inch, 1-sided, single-density
;FD     500K       8-inch, 2-sided, single-density
;FE     1.2 MB     8-inch, 2-sided, double-density
;F8     -----      Fixed disk

;Read boot sector, enable emulation if something resembling floppy image is there
;We store only needed stuff as we don't have a memory buffer, it's ROM
read_boot:
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
	stc
	ret
.readbuffer:
	mov	al,cmd_read_buffer
	call	write_cmd
	call	read_data
;buffer should be 64
	cmp	al,40h
	je	.transfer
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
	in	al,dx      ;Media type 0Fxh here

	in	al,dx
	in	al,dx

;get and validate sectors - our range is 8-36(64?)
	in	al,dx
	mov	ah,al
	in	al,dx
	xchg	ah,al
		
	cmp	ax,8
	jb	.sec_invalid
	cmp	ax,64
	jbe	.sec_ok
.sec_invalid:
        xor	ax,ax
.sec_ok:
	mov	[fd_sectors],al

;get and validate heads - our range is 1-2(64?)
	in	al,dx
	mov	ah,al
	in	al,dx
	xchg	ah,al
		
	cmp	ax,1
	jb	.h_invalid
	cmp	ax,64
	jbe	.h_ok
.h_invalid:
        xor	ax,ax
.h_ok:
	mov	[fd_heads],al

;We need to 'continue read' until usb_success
;i coudn't find a better way

	mov	cx,8
exhaust_loop:	
	mov	al,cmd_read_cont
	call	write_cmd
	call	wait_status
	cmp	al,usb_success
	je	exit_exhaust
	loop	exhaust_loop
exit_exhaust:

	mov	al,[fd_heads]
	test	al,al
	jz	bad_exit

	mov	al,[fd_sectors]
	test	al,al
	jz	bad_exit

	clc
	ret

bad_exit:
	stc
	ret

;delays, most probably not even close to correct
short_delay:
;	push	cx
;	mov	cx,10
;.l:	loop	.l
;	pop	cx
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

;==============================
;Wait for interrupt
;CH37X BIOS version 
wait_interrupt_old:
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


wait_interrupt:
	push	dx
	push	cx
	xor	cx,cx
	mov	dx,cmd_port
.w:
	in	al,dx
	test	al,80h	
	jz	.end
	jmp	.l	;Jumps invalidate cache (?)
.l:
	loop	.w	
.end:
	pop	cx
	pop	dx
	ret

;=================================================
; We always support change line
; (hopefully)
;
ch375_int_13_fn15:		;return drive type
	xor	ax,ax
	mov	al,[fd_enabled]
	test	al,al
	je	.over
	mov	ah,02h
.over:	
	clc
	mov	byte [fdc_last_error],0
	jmp	ch375_int_13_exit

;================================================
; Detect disk change
; Seem to be working
;
ch375_int_13_fn16:
	xor	ax,ax
	mov	al,[fdc_last_error]
	test	al,al
	je	.over
	;xor	ah,ah
	;mov	[fdc_last_error],ah
	mov	ah,[fdc_last_error]
	cmp	ah,fdc_e_changed
	jne	.over
	mov	ah,1
	stc
	jmp	.over2
.over:
	clc
.over2:
	mov	byte [fdc_last_error],0
	jmp	ch375_int_13_exit

;===================================================
; Get drive type, fn_08
; If emulation enforced - return set drive type
; but 1.44 if None
; If auto - return 1.44 if something present
;
ch375_int_13_drivetype:
	mov	al,[fd_enabled]
	cmp	al,2			;enforced emulation, return selected type or 1.44 if None
	jne	.next
	xor	ax,ax
%ifdef	BIOS_SETUP
	call	get_floppy
	shr	al,1
	shr	al,1
	shr	al,1
	shr	al,1
	jne	.return_type
%endif
	mov	al,type_1440
	jmp	.return_type

.next:
	cmp	al,1			;autoemulation active
	jne	.return_none
	mov	al,type_1440
	jmp	.return_type

.return_none:
	xor	cx,cx
	xor	di,di
	mov	byte [bp+int_13_bl],cl	; drive type is zero
	mov	byte [bp+int_13_dh],cl	; maximal head number is zero
	mov	es,cx			; disk parameter table segment = 0000h
	jmp	.set_parameters

.return_type:				; Copypasted from Sergey's
	mov	byte [bp+int_13_dh],1	; maximal head number is 1 for floppy
	mov	byte [bp+int_13_bl],al	; pass drive type to caller
	mov	cx,cs
	mov	es,cx			; diskette parameter table segment

	cmp	al,type_360
	je	.set_360
	cmp	al,type_720
	je	.set_720
	cmp	al,type_1200
	je	.set_1200
	cmp	al,type_1440
	je	.set_1440
.set_2880:
	mov	al,fdc_m_try_2880	; try 2.88M in 2.88M drive
	lea	di,[media_2880]		; only 2.88M uses 1 Mbps rate
	mov	cx,4F24h		; 2.88M - 80 cylinders, 36 sectors
	jmp	.set_media_type
.set_360:
	mov	al,fdc_m_360in360
	lea	di,[media_360_in_360]
	mov	cx,2709h		; 360K - 40 cylinders, 9 sectors
	jmp	.set_media_type

.set_720:
	mov	al,fdc_m_720
	lea	di,[media_720]
	mov	cx,4F09h		; 720K - 80 cylinders, 9 sectors
	jmp	.set_media_type

.set_1200:
	mov	al,fdc_m_try_1200in1200
	lea	di,[media_1200]
	mov	cx,4F0Fh		; 1.2M - 80 cylinders, 15 sectors
	jmp	.set_media_type

.set_1440:
	mov	al,fdc_m_try_1440
	lea	di,[media_1440]
	mov	cx,4F12h		; 1.44M - 80 cylinders, 18 sectors

.set_media_type:
.set_parameters:
	xor	ax,ax			; AH = 00h - successful completion
	mov	byte [bp+int_13_al],al	; successful completion
	mov	byte [fdc_last_error],al
	mov	byte [bp+int_13_bh],al	; clear BH just in case
	mov	word [bp+int_13_cx],cx	; cylinders / sectors
	mov	word [bp+int_13_di],di	; diskette parameter table pointer
	jmp	ch375_int_13_exit

; =========================
; CHS to LBA full version
; Returns LBA in DX:AX
; Takes BIOS int 13h params
;
chs_to_lba:
	mov	dx,cx
	xchg	dh,dl
	mov	cl,6
	shr	dh,cl
	mov	ax,dx
	xor	dx,dx
	xor	bx,bx
	mov	bl,[fd_heads]
	mul	bx
	mov	bl,[bp+int_13_dh]
	add	ax,bx
	adc	dx,0
	mov	bl,[fd_sectors]
	mul	bx
	mov	bl,[bp+int_13_cl]
	and	bl,111111b
	test	bl,bl
	jz	.exit_err
	dec	bx
	add	ax,bx
	adc	dx,0
	clc
	ret
.exit_err:
	stc
	ret

;=============================
; CHS to LBA
; simplified for floppy
;
chs_to_lba_simple:
	mov	ax,cx ;save track/sector
	mov	bx,cx
	and	bl,111111b
	xor	bh,bh
	dec	bx    ;sector number for LBA
	jns	.next ;sanity check
	stc
	jmp	.exit	
.next:
;	mov	cl,8  ;we don't need high two bits
;	shr	ax,cl ;track number for LBA
 	mov	al,ah
	xor	ah,ah

	mov	cl,[fd_heads]
	shr	cl,1
	shl	ax,cl  ;track * heads count

	mov	dl,dh ;head
	xor	dh,dh
;+ head
	add	ax,dx
	xor	dx,dx
	xor	cx,cx
	mov	cl,[fd_sectors]
	mul	cx
	test	dx,dx
	jz	.next2
;overflow
	stc
	ret
.next2:
;+ sector	
	add	ax,bx
	xor	dx,dx
	clc
.exit:
	ret
	
ch375_int_13_reset:
	call	reset_controller
	call	read_boot
	jc	.no_disk
	mov	al,[fd_media]
	cmp	al,1
	jne	.changed
	xor	ah,ah
	jmp	ch375_int_13_exit	
	
.changed:
	mov	al,1
	mov	[fd_media],al
	mov	ah,fdc_e_changed
	mov	[fdc_last_error],ah
	jmp	ch375_int_13_exit

.no_disk:
	xor	ah,ah
	mov	[fd_media],ah
	dec	ah
	stc
	jmp	ch375_int_13_exit

ch375_int_13_geterror:
	mov	al,[fdc_last_error]
	mov	byte [bp+int_13_al],al
	clc
	jmp	ch375_int_13_exit

;Read sectors
ch375_int_13_read:
	call	chs_to_lba
	jc	ch375_int_13_exit
	call	read_sectors
	jnc	ch375_int_13_exit
	mov	ah,010h	;Fixme - ECC error
	jmp	ch375_int_13_exit
	jmp	ch375_int_13_exit

;Write sectors
ch375_int_13_write:
	call	chs_to_lba
	jc	ch375_int_13_exit
	call	write_sectors
	jnc	ch375_int_13_exit
	mov	ah,0CCh	;Write error
	jmp	ch375_int_13_exit


;=============================================================


newint:
;only first floppy
	test	dl,dl
	jnz	old_int

int_13:
	sti
	push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	push	ds
	push	bp
	mov	bp,sp

	mov	bx,biosdseg
	mov	ds,bx

ch375_int_13:

	call	get_status
;Is zero even ok?
	test	al,al
	je	.next

;Still status of last operation - no change?
	cmp	al,usb_success
	je	.next

;USB_CONNECT means device inserted, disk change?
	cmp	al,usb_connect
	je	.disk_change

;USB_CONNECT means device removed, no disk?
	cmp	al,usb_disconnect
	je	.no_disk
	
.next:
	mov	al,[fd_media]
	test	al,al
	jnz	.continue

.disk_change:
	call	reset_controller
	call	read_boot
	jc	.bad_disk

	mov	byte [fd_media],1
	mov	ah,fdc_e_changed
	mov	[fdc_last_error],ah
	stc
	jmp	ch375_int_13_exit
	
.bad_disk:
.no_disk:
	mov	byte [fd_media],0
	;dec	ah
	mov	ah,fdc_e_changed
	mov	[fdc_last_error],ah
	stc
	jmp	ch375_int_13_exit		

.continue:
	mov	ax,[bp+int_13_ax]

	call	print_ax

	mov	cx,[bp+int_13_cx]
	mov	dx,[bp+int_13_dx]

	cmp	ah,00
	je	ch375_int_13_reset
	cmp	ah,01
	je	ch375_int_13_geterror
	cmp	ah,02
	je	ch375_int_13_read
	cmp	ah,03
	je	ch375_int_13_write
	cmp	ah,08
	je	ch375_int_13_drivetype
	cmp	ah,15h
	je	ch375_int_13_fn15
	cmp	ah,16h
	je	ch375_int_13_fn16

	clc
	xor	ah,ah		
	mov	[fdc_last_error],ah

ch375_int_13_exit:      
	mov	byte [bp+int_13_ah],ah	; pass AH to the caller
	mov	ax,201h			; set IF and CF
	jc	.set_error		; there is an error
	and	byte [bp+int_13_flags_l],0FEh ; no errors - clear CF
	dec	ax			; clear CF in AX too

.set_error:
	or	word [bp+int_13_flags],ax
	pop	bp
	pop	ds
	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	iret

old_int: 
	db      0EAh
oldint  dd      0

print_ax:
	push	ax
	push	bx
	push	cx
	push	es
	xchg	ah,al
	mov	ah,1Fh
	or	al,30h
	mov	bx,0B800h
	mov	es,bx
	xor	bx,bx
	mov	es:[bx],ax
	xor	cx,cx
b:	in	al,20h
	loop	b
	pop	es
	pop	cx
	pop	bx
	pop	ax
	ret


;START 
install:

	mov	ax,biosdseg
	mov	ds,ax
	xor	al,al
	mov	[fd_media],al	
	inc	ax
	mov	[fd_enabled],al

	call	print_ax

	call	reset_controller
	jc	.out
	call	read_boot
	jc	.out

	mov	al,1
	mov	[fd_enabled],al
	mov	[fd_media],al

	call	detect_floppy

	push	cs
	pop	ds

	cli
	cld
	push	ds
	push	es
	xor	ax,ax
	mov	ds,ax
	mov	si,int_num*4
	mov	di,oldint
	movsw
	movsw
	xor	ax,ax
	mov	es,ax
	mov	di,int_num*4
	mov	ax,newint
	stosw
	mov	ax,cs
	stosw
	sti
	pop	es
	pop	ds

	mov	dx,message
	mov	ah,9
	int	21h

	mov	dx,install
	int	27h


.out:
	ret

detect_floppy:
	push	ds
	push	dx
	mov	ax,biosdseg
	mov	ds,ax
	xor	ax,ax
	mov	[fd_media],al
	inc	ax
	mov	[fd_enabled],al
	call	reset_controller
	jc	.exit
	call	read_boot
	jc	.exit
	mov	al,1
	mov	[fd_enabled],al
	mov	[fd_media],al
	or	byte [equipment_list],equip_floppies
.exit:
	pop	dx
	pop	ds
	ret

message	db	"Floppy emulation for CH375",0Dh,0Ah
	db	"TSR test version",0Dh,0Ah
	db	"(C) 2023-2024 Serhii Liubshin",0Dh,0Ah,0Dh,0Ah,"$"

media_360_in_360:
	db	0DFh, 02h, 25h, 02h, 09h, 2Ah, 0FFh, 50h, 0F6h, 0Fh, 08h
	db	27h, 80h
media_1200:
	db	0DFh, 02h, 25h, 02h, 0Fh, 1Bh, 0FFh, 54h, 0F6h, 0Fh, 08h
	db	4Fh, 00h
media_720:
	db	0DFh, 02h, 25h, 02h, 09h, 2Ah, 0FFh, 50h, 0F6h, 0Fh, 08h
	db	4Fh, 80h
media_1440:
	db	0BFh, 02h, 25h, 02h, 12h, 1Bh, 0FFh, 6Ch, 0F6h, 0Fh, 08h
	db	4Fh, 00h
media_360_in_1200:
	db	0DFh, 02h, 25h, 02h, 09h, 23h, 0FFh, 50h, 0F6h, 0Fh, 08h
	db	27h, 40h
media_2880:
	db	0AFh, 02h, 25h, 02h, 24h, 1Bh, 0FFh, 50h, 0F6h, 0Fh, 08h
	db	4Fh, 0C0h

