;; ----------------------------------------------------------------------------
;; dstxt - give dwm something to draw
;;
;; This work is free. You can redistribute it and/or modify it under the
;; terms of the Do What The Fuck You Want To Public License, Version 2,
;; as published by Sam Hocevar. See the COPYING file for more details.
;;
;; 2016/07/13 - smattie <https://github.com/smattie>
;; ----------------------------------------------------------------------------

format ELF64
public _start

define UPDATESEC 7

extrn localtime
extrn lseek
extrn open
extrn read
extrn sleep
extrn snprintf
extrn time
extrn XOpenDisplay
extrn XStoreName
extrn XSync
extrn _exit

;; r15 Display *
;; r14 DefaultRootWindow
;; r13 battery fd
;; r12 last minute the time buffer was updated

section '.text' executable
_start:
	mov   rbp, rsp

	xor   edi, edi
	call  XOpenDisplay
	test  rax, rax
	jz    exit

	mov   r15, rax

	;; get root window - it's around here somewhere
	mov   rsi, [r15 + 232]
	mov   rsi, [rsi +  16]
	mov   r14, rsi

	mov   edi, BATPATH
	xor   esi, esi ;; O_RDONLY
	call  open
	test  eax, eax
	js    exit

	sub   rsp, 256
	mov   r13d, eax
	mov   r12d, -1

	mainloop:
	;; --[ battery ]----------------
	mov   edi, r13d
	mov   edx, 3
	lea   rsi, [rsp + 16]
	call  read
	dec   eax
	js    @f ;; 0 bytes read?
	mov   byte [rsp + 16 + rax], 0

	@@:
	mov   edi, r13d
	xor   esi, esi
	xor   edx, edx ;; SEEK_SET
	call  lseek

	;; --[ time ]-------------------
	xor   edi, edi
	call  time
	mov   [rsp], rax
	mov   rdi, rsp
	call  localtime
	mov   r11d, [rax + 4] ;; tm_min
	cmp   r11d, r12d
	je    @f

	mov   r12d, r11d
	movq  mm0, rbp

	mov   r11d, [rax +  8] ;; tm_hour
	mov   r10d, [rax + 12] ;; tm_mday
	mov   ebx,  [rax + 16] ;; tm_mon
	mov   ebp,  [rax + 24] ;; tm_wday

	mov   dword [rsp + 0], r11d
	mov   dword [rsp + 8], r12d

	lea   rdi, [rsp + 16 + battBuffLn]
	mov   esi, dateBuffLn
	mov   rdx, timeFmt
	mov   r8d, r10d
	lea   rcx, [day + rbp * 4]
	lea   r9,  [mon + rbx * 4]
	movq  rbp, mm0
	xor   eax, eax
	call  snprintf

	;; -----------------------------
	@@:
	lea   rdi, [rsp + 16 + battBuffLn + dateBuffLn]
	mov   esi, outBuffLn
	mov   rdx, outFmt
	lea   rcx, [rsp + 16]
	lea   r8,  [rsp + 16 + battBuffLn]
	xor   eax, eax
	call  snprintf

	mov   rdi, r15
	mov   rsi, r14
	lea   rdx, [rsp + 16 + battBuffLn + dateBuffLn]
	call  XStoreName

	mov   rdi, r15
	xor   esi, esi
	call  XSync

	mov   edi, UPDATESEC
	call  sleep
	jmp   mainloop

	;; -----------------------------
	exit:
	xor   edi, edi
	call  _exit

section '.data'
	BATPATH db "/sys/class/power_supply/BAT0/capacity", 0

	timeFmt db "%s %2i %s @ %02i:%02i", 0
	outFmt  db "[ BAT %2s%% ] :: [ %s ]", 0

	day     db "Sun", 0, "Mon", 0, "Tue", 0, \
	           "Wed", 0, "Thu", 0, "Fri", 0, "Sat", 0

	mon     db "Jan", 0, "Feb", 0, "Mar", 0, \
	           "Apr", 0, "May", 0, "Jun", 0, \
	           "Jul", 0, "Aug", 0, "Sep", 0, \
	           "Oct", 0, "Nov", 0, "Dec", 0

battBuffLn = 8
dateBuffLn = 32
outBuffLn  = 128
