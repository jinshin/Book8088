; This is a standalone TSR for testing INT 09 and 16 handling in Phatcode BIOS
; (C) 2024 
;
; Original copyright preserved
;===================================================================================================
;                  Super PC/Turbo XT BIOS for Intel 8088 or NEC "V20" Motherboards
;              Additions by Ya`akov Miles (1987) and Jon Petrosky <Plasma> (2008-2017)
;                                     http://www.phatcode.net/
;===================================================================================================                                                                                                                      
;+--------++
;| INT 09 ||
;+--------++
;---------------------------------------------------------------------------------------------------
; Interrupt 16h - Keyboard BIOS Services
;---------------------------------------------------------------------------------------------------
	.model tiny
	.code
	jumps
	locals
	org	100h
	
begin:	jmp	install

int_16	proc

@@check:
	cli					; No interrupts, critical code
	mov	bx, [ds:1Ah]			;   point to buffer head
	cmp	bx, [ds:1Ch]			;   equal buffer tail?
	mov	ax, [bx]			;   (fetch, look ahead)
	sti					; Enable interrupts
	pop	bx
	pop	ds
	retf	2				; Do iret, preserve flags

@@shift:
	mov	ax, [ds:17h]			; Read keypad shift status
	jmp	short @@end

@@stuff:
	mov	ax, cx
	call	stuff_keyboard_buffer
	mov	al, 0				; al=0 if buffer ok (must be MOV; XOR modifies cf!)
	jnc	@@end
	inc	al				; al=1 if buffer full
	jmp	short @@end

int_16_entry:
	sti					; Keyboard BIOS services
	push	ds
	push	bx

	mov	bx, 40h
	mov	ds, bx				; Load work segment

	cmp	ah, 5
	je	@@stuff				; Stuff keyboard buffer, ah=5

	mov	bx, ax				; Save function number to check for
						;   extended call later

	and	ah, 0Fh				; Translate enhanced keyboard function calls
						; ah=10h/11h/12h -> ah=00h/01h/02h
	or	ah, ah
	jz	@@read				; Read keyboard buffer, ah=0
	dec	ah
	jz	@@check				; Set Z if char ready, ah=1
	dec	ah
	jz	@@shift				; Return shift in al, ah=2

@@end:
	pop	bx				; Exit INT_16 keyboard service
	pop	ds
	iret

@@read:
	cli					; No interrupts, alters buffer
	mov	ax, [ds:1Ah]			;   point to buffer head
	cmp	ax, [ds:1Ch]			; If not equal to buffer tail
	jnz	@@have_char			;   char waiting to be read
	sti					; Else allow interrupts
	jmp	@@read				;   wait for him to type

@@have_char:
	test	bh, 10h				; Test for extended function call
	pushf					; Save zf for later

	xchg	ax, bx
	mov	ax, [bx]			; Fetch the character

	popf					; Is this an extended function call?
	jnz	@@no_translation		; Yes so don't change extended scan codes

	cmp	al, 0E0h			; Is scan code E0h?
	jne	@@no_translation
	xor	al, al				; If so translate to 00h for standard function
@@no_translation:

	inc	bx				; Point to next character
	inc	bx				;   char = scan code + shift
	mov	[ds:1Ah], bx			; Save position in head
	cmp	bx, [ds:82h]			;   buffer overflowed?
	jnz	@@end				;   no, done
	mov	bx, [ds:80h]			; Else reset to point at start
	mov	[ds:1Ah], bx			;   and correct head position
	jmp	short @@end

int_16	endp


;---------------------------------------------------------------------------------------------------
; Interrupt 9h - Keyboard Data Ready
;---------------------------------------------------------------------------------------------------
ascii		db	000h, 037h, 02Eh, 020h	; Scan -> ASCII, sign bit set
		db	02Fh, 030h, 031h, 021h	;   if further work needed
		db	032h, 033h, 034h, 035h
		db	022h, 036h, 038h, 03Eh
		db	011h, 017h, 005h, 012h
		db	014h, 019h, 015h, 009h
		db	00Fh, 010h, 039h, 03Ah
		db	03Bh, 084h, 001h, 013h
		db	004h, 006h, 007h, 008h
		db	00Ah, 00Bh, 00Ch, 03Fh
		db	040h, 041h, 082h, 03Ch
		db	01Ah, 018h, 003h, 016h
		db	002h, 00Eh, 00Dh, 042h
		db	043h, 044h, 081h, 03Dh
		db	088h, 02Dh, 0C0h, 023h
		db	024h, 025h, 026h, 027h
		db	028h, 029h, 02Ah, 02Bh
		db	02Ch, 0A0h, 090h

non_alpha	db	032h, 036h, 02Dh, 0BBh	; Non-Alphabetic secondary
		db	0BCh, 0BDh, 0BEh, 0BFh	;   translation table
		db	0C0h, 0C1h, 0C2h, 0C3h
		db	0C4h, 020h, 031h, 033h
		db	034h, 035h, 037h, 038h
		db	039h, 030h, 03Dh, 01Bh
		db	008h, 05Bh, 05Dh, 00Dh
		db	05Ch, 02Ah, 009h, 03Bh
		db	027h, 060h, 02Ch, 02Eh
		db	02Fh

ctrl_upper	db	040h, 05Eh, 05Fh, 0D4h	; CTRL uppercase secondary
		db	0D5h, 0D6h, 0D7h, 0D8h	;   translation table
		db	0D9h, 0DAh, 0DBh, 0DCh	;   for non-ASCII control
		db	0DDh, 020h, 021h, 023h
		db	024h, 025h, 026h, 02Ah
		db	028h, 029h, 02Bh, 01Bh
		db	008h, 07Bh, 07Dh, 00Dh
		db	07Ch, 005h, 08Fh, 03Ah
		db	022h, 07Eh, 03Ch, 03Eh
		db	03Fh

ctrl_lower	db	003h, 01Eh, 01Fh, 0DEh	; CTRL lowercase secondary
		db	0DFh, 0E0h, 0E1h, 0E2h	;   translation table
		db	0E3h, 0E4h, 0E5h, 0E6h	;   for non-ASCII control
		db	0E7h, 020h, 005h, 005h
		db	005h, 005h, 005h, 005h
		db	005h, 005h, 005h, 01Bh
		db	07Fh, 01Bh, 01Dh, 00Ah
		db	01Ch, 0F2h, 005h, 005h
		db	005h, 005h, 005h, 005h
		db	005h

alt_key		db	0F9h, 0FDh, 002h, 0E8h	; ALT key secondary
		db	0E9h, 0EAh, 0EBh, 0ECh	;   translation table
		db	0EDh, 0EEh, 0EFh, 0F0h
		db	0F1h, 020h, 0F8h, 0FAh
		db	0FBh, 0FCh, 0FEh, 0FFh
		db	000h, 001h, 003h, 005h
		db	005h, 005h, 005h, 005h
		db	005h, 005h, 005h, 005h
		db	005h, 005h, 005h, 005h
		db	005h

num_pad		db	'789-456+1230.' 	; Keypad secondary translation

num_ctrl	db	0F7h, 005h, 004h, 005h	; Numeric keypad CTRL secondary
		db	0F3h, 005h, 0F4h, 005h	;   translation table
		db	0F5h, 005h, 0F6h, 005h
		db	005h

num_upper	db	0C7h, 0C8h, 0C9h, 02Dh	; Numeric keypad SHIFT secondary
		db	0CBh, 005h, 0CDh, 02Bh	;   translation table
		db	0CFh, 0D0h, 0D1h, 0D2h
		db	0D3h


int_9	proc

	sti					; Key press hardware interrupt
	push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	push	ds

	cld
	mov	ax, 40h
	mov	ds, ax

	in	al, 60h 			; Read the scan code data
	mov	ah,al
	jmp	@@process			;   no, OK

int_9_end:
@@end:
	mov	al, 20h 			; Send end_of_interrupt code
	out	20h, al 			;   to 8259 interrupt chip

@@exit:
	pop	ds				; Exit the interrupt
	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	iret

@@process:
	and	al, 01111111b			; Valid scan code, no break
	cmp	al, 46h
	jbe	@@standard			; Standard key
	jmp	@@pad				; Numeric keypad key

@@standard:
	mov	bx, offset ascii		; Table for ESC thru Scroll Lck
	xlat	[cs:bx] 			;   translate to Ascii
	or	al, al				; Sign flags "Shift" type key
	js	@@flag				;   shift, caps, num, scroll etc
	or	ah, ah				; Invalid scan code?
	js	@@end				;   exit if so
	jmp	short @@ascii			; Else normal character

@@flag: and	al, 01111111b			; Remove sign flag bit
	or	ah, ah				;   check scan code
	js	@@shift_up			;   negative, key released
	cmp	al, 10h 			; Is it a "toggle" type key?
	jnb	@@toggle			;   yes
	or	[ds:17h], al			; Else set bit in "flag" byte
	jmp	@@end				;   and exit

@@toggle:
	test	byte ptr ds:[17h], 00000100b	; Control key pressed?
	jnz	@@ascii				;   yes, skip
	test	[ds:18h], al			; Else check "CAPS, NUM, SCRL"
	jnz	@@end				;   set, invalid, exit
	or	[ds:18h], al			; Show set in "flag_1" byte
	xor	[ds:17h], al			;   flip bits in "flag" byte
	jmp	@@end

@@shift_up:
	cmp	al, 10h 			; Released - is it "toggle" key
	jnb	@@toggle_up			;   skip if so
	not	al				; Else form two's complement
	and	[ds:17h], al			;   to do BIT_CLEAR "flags"
	cmp	al, 11110111b			; ALT key release special case
	jnz	@@end				;   no, exit
	mov	al, [ds:19h]			; Else get ALT-keypad character
	mov	ah, 0				;   pretend null scan code
	mov	[ds:19h], ah			;   zero ALT-keypad character
	cmp	al, ah				; Was there a valid ALT-keypad?
	jz	@@end				;   no, ignore, exit
	jmp	@@null			; Else stuff it in ASCII buffer

@@toggle_up:
	not	al				; Form complement of toggle key
	and	[ds:18h], al			;   to do BIT_CLEAR "flag_1"
	jmp	@@end

@@ascii:
	test	byte ptr [ds:18h], 00001000b	; Scroll lock pressed?
	jz	@@no_lock			;   no
	cmp	ah, 45h 			; Is this a NUM LOCK character?
	jz	@@done				;   no
	and	byte ptr [ds:18h], 11110111b	; Else clear bits in "flag_1"

@@done:	jmp	@@end				;   and exit

@@no_lock:
	mov	dl, [ds:17h]
	test	dl, 00001000b			; ALT key pressed?
	jnz	@@alt				;   yes
	test	dl, 00000100b			; CTRL key pressed?
	jnz	@@ctrl				;   yes
	test	dl, 00000011b			; Either shift key pressed?
	jnz	@@shift				;   yes

@@lower_case:
	cmp	al, 1Ah 			; Alphabetic character?
	ja	@@non_alpha			;   no
	add	al, 'a'-1			; Else add lower case base
	jmp	@@common

@@non_alpha:
	mov	bx, offset non_alpha		; Non-alphabetic character
	sub	al, 20h
	xlat	[cs:bx] 			;   do the xlate
	jmp	@@common

@@alt:	cmp	al, 1Ah 			; Control key pressed?
	ja	@@no_ctrl			;   no, skip
	mov	al, 0				; Else illegal key press
	jmp	@@buffer

@@no_ctrl:
	mov	bx, offset alt_key		; Load ALT key translation
	sub	al, 20h 			;   bias to printing char
	xlat	[cs:bx] 			;   do the translation
	jmp	@@common

@@ctrl: cmp	ah, 46h 			; Scroll lock key?
	jnz	@@ctrl_1			;   no, skip
	mov	byte ptr [ds:71h], 10000000b	; Else CTRL-"Scroll" = break
	mov	ax, [ds:80h]			;   get key buffer start
	mov	[ds:1Ch], ax			;   get key tail to start
	mov	[ds:1Ah], ax			;   get key head to start
	int	1Bh				; Issue a "Break" interrupt
	sub	ax, ax
	jmp	@@common_2

@@ctrl_1:
	cmp	ah, 45h 			; Num lock key?
	jnz	@@ctrl_2			;   no, skip
	or	byte ptr [ds:18h], 00001000b	; Else show scroll lock
	mov	al, 20h 			;   send end_of_interrupt
	out	20h, al 			;   to 8259 int controller
	cmp	byte ptr [ds:49h], 7		; Monochrome monitor?
	jz	@@poll				;   yes, skip
	mov	dx, 3D8h			; Else reset mode
	mov	al, [ds:65h]			;   for the
	out	dx, al				;   CGA color card

@@poll: test	byte ptr [ds:18h], 00001000b	; Wait for him to type
	jnz	@@poll				;   not yet
	jmp	@@exit

@@ctrl_2:
	cmp	ah, 3				; Is it a Control @ (null) ?
	jnz	@@ctrl_3			;   no
	mov	al, 0				; Else force a null

@@ctrl_4:
	jmp	@@buffer			;   save in buffer

@@ctrl_3:
	cmp	al, 1Ah 			; Is it a control character?
	jbe	@@ctrl_4			;   yes
	mov	bx, offset ctrl_lower		; Else non-ascii control
	sub	al, 20h 			;   lower case
	xlat	[cs:bx] 			;   translation
	jmp	@@common

@@shift:
	cmp	ah, 37h 			; Print_Screen pressed?
	jnz	@@shift_2
	mov	al, 20h 			; Yes, send end_of_interrupt
	out	20h, al 			;   to 8259 interrupt chip
	int	5				; Request print_screen service
	jmp	@@exit				;   and exit key service

@@shift_2:
	cmp	al, 1Ah 			; Alphabetic char?
	ja	@@shift_3			;   no
	add	al, 'A'-1			; Yes, add base for alphabet
	jmp	@@common

@@shift_3:
	mov	bx, offset ctrl_upper		; Non-ascii control
	sub	al, 20h 			;   upper case
	xlat	[cs:bx] 			;   translation
	jmp	@@common

@@pad:
	sub	al, 47h 			; Keypad key, convert origin
	mov	bl, [ds:17h]			;   get "flag" byte
	test	bl, 00001000b			; Look for ALT keypad entry
	jnz	@@alt_num			;   do special entry thing
	test	bl, 00000100b			; CTRL key pressed?
	jnz	@@released			;   skip if so
	test	bl, 00100000b			; Toggle "Num Lock" ?
	jz	@@pad_1				;   no, continue
	test	bl, 00000011b			; Shift keys hit?
	jnz	@@pad_2				;   no, check "INS"
	jmp	short @@pad_5			; Else xlat keypad char.

@@pad_1:
	test	bl, 00000011b			; Shift keys hit?
	jz	@@pad_2				;   no, check "INS" key
	jmp	@@pad_5				; Else xlat keypad char.

@@alt_num:
	or	ah, ah				; ALT-keypad entry, scan code
	js	@@done_2			;   out of range
	test	byte ptr [ds:17h], 00000100b	; Else check CTRL state
	jz	@@alt_num_2			;   not pressed, ALT keypad

@@turbo_patch:
	cmp	ah, 53h 			; Patch for CTRL ALT - toggle
	jnz	@@turbo_check			;   not a DEL (reset)
reboot:
	mov	word ptr [ds:72h], 1234h	; Ctrl-Alt-Del,	set init flag
;fixme
;	jmp	warm_boot			;   do a warm reboot

@@turbo_check:

@@alt_num_2:
	mov	bx, offset num_pad		; Get keypad translation table
	xlat	[cs:bx] 			;   convert to number
	cmp	al, '0' 			; Is it a valid ASCII digit?
	jb	@@done_2			;   no, ignore it
	sub	al, 30h 			; Else convert to number
	mov	bl, al				;   save a copy
	mov	al, [ds:19h]			; Get partial ALT-keypad sum
	mov	ah, 0Ah 			;   times 10 (decimal)
	mul	ah
	add	al, bl				; Add in new digit to sum
	mov	[ds:19h], al			;   save as new ALT entry

@@done_2:
	jmp	@@end				; End_of_interrupt, exit

@@released:
	or	ah, ah				; Key released?
	js	@@done_2			;   ignore if so
	mov	bx, offset num_ctrl		; Else Numeric Keypad Control
	xlat	[cs:bx] 			;   secondary translate
	jmp	@@common			;   and save it

@@pad_2:
	call	set_insert_flags		; Check for INS press and set
	jc	@@done_2			;   flags accordingly

@@pad_4:
	mov	bx, offset num_upper		; Numeric Keypad Upper Case
	xlat	[cs:bx] 			;   secondary translation
	jmp	@@common

@@pad_5:
	or	ah, ah				; Was the key released?
	js	@@done_2			;   yes, ignore
	mov	bx, offset num_pad		; Load translation table
	xlat	[cs:bx] 			;   do translate

@@common:
	cmp	al, 5				; Common entry, char in al
	jz	@@done_3			;   Control E, ignore
	cmp	al, 4
	ja	@@common_1			; Above Control D

	or	al, 10000000b			; Else set sign flag
	jmp	@@common_2

@@common_1:
	test	al, 10000000b			; Is sign bit set?
	jz	@@common_3			;   skip if so
	and	al, 01111111b			; Else mask sign off

@@common_2:
	mov	ah, al				; Save in high order byte
	mov	al, 0				;   set scan code to zero

@@common_3:
	test	byte ptr [ds:17h], 01000000b	; Test for "CAPS LOCK" state
	jz	@@buffer			;   no, skip
	test	byte ptr [ds:17h], 00000011b	; Test for SHIFT key
	jz	@@common_4			;   skip if no shift
	cmp	al, 'A' 			; Check for alphabetic key
	jb	@@buffer			;   not SHIFT_able
	cmp	al, 'Z' 			; Check for alphabetic key
	ja	@@buffer			;   not SHIFT_able
	add	al, 20h 			; Else do the shift
	jmp	short @@buffer

@@common_4:
	cmp	al, 'a' 			; Check for alphabetic key
	jb	@@buffer			;   not SHIFT_able
	cmp	al, 'z' 			; Check for Alphabetic key
	ja	@@buffer			;   not SHIFT_able
	sub	al, 20h 			; Else do the shift

int_9_stuff:
@@buffer:
	call	stuff_keyboard_buffer		; Put keystroke in buffer
	jnc	@@done_3

@@beep:
;	mov	bl, 1				; Do a
;	call	beep				;   short beep

@@done_3:
	jmp	@@end

@@null: mov	ah, 38h 			; ALT key pressed, released
	jmp	@@buffer			;   for no logical reason

int_9	endp


;---------------------------------------------------------------------------------------------------
; Check for INS key up/down scan codes and set flags. cf=1 if scan code is any key up.
;---------------------------------------------------------------------------------------------------
set_insert_flags	proc

	cmp	ah, 0D2h			; Was "INS" key released?
	jnz	@@pad_3
	and	byte ptr [ds:18h], 01111111b	; Yes, clear "INS" in "FLAG_1"

@@done_2:
	stc
	ret

@@pad_3:
	or	ah, ah				; Key released?
	js	@@done_2			;   ignore if so

	cmp	ah, 52h 			; Else check for "INS" press
	jnz	@@done				;   not "INS" press
	test	byte ptr [ds:18h], 10000000b	; Was INS key in effect?
	jnz	@@done				;   yes, ignore
	xor	byte ptr [ds:17h], 10000000b	; Else tog "INS" in "FLAG" byte
	or	byte ptr [ds:18h], 10000000b	;   set "INS" in "FLAG_1" byte

@@done:
	clc
	ret

set_insert_flags endp


;---------------------------------------------------------------------------------------------------
; Put keystroke in ax (al=ASCII, ah=scan) in the keyboard buffer. cf=1 if buffer is full.
;---------------------------------------------------------------------------------------------------
stuff_keyboard_buffer	proc

	mov	bx, [ds:1Ch]			; bx = tail of buffer
	mov	di, bx				;   save it
	inc	bx				;   advance
	inc	bx				;   by word
	cmp	bx, [ds:82h]			; End of buffer reached?
	jnz	@@check				;   no, skip
	mov	bx, [ds:80h]			; Else bx = beginning of buffer

@@check:
	cmp	bx, [ds:1Ah]			; bx = Buffer Head ?
	jnz	@@stuff				;   no, OK
	stc					; cf=1, buffer full
	ret

@@stuff:
	mov	[ds:di], ax			; Stuff scan code, char in buffer
	mov	[ds:1Ch], bx			;   and update buffer tail
	clc					; cf=0, no errors
	ret

stuff_keyboard_buffer endp

banner	db "Phatcode BIOS keyboard handlers test",0Dh,0Ah
	db "Conversion by Serhii Liubshin",0Dh,0Ah."$"	

install:
        cld
        cli
        xor     ax,ax
        mov     es,ax

        mov     di,9h*4
        mov     ax,offset int_9
        stosw
        mov     ax,cs
        stosw

        mov     di,16h*4
        mov     ax,offset int_16_entry
        stosw
        mov     ax,cs
        stosw

        sti
        mov     dx,offset install
        int     27h

	end	begin