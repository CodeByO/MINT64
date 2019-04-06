[ORG 0x00]	; 코드의 시작 어드레스를 0x00으로 설정
[BITS 16]	; 이하의 코드는 16비트 코드로 설정

SECTION .text	; text 섹션(세그먼트)을 정의

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;	코드 영역
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
START:
	mov ax, 1000 	; 보호 모드 엔트리 포인트의 싲ㄱ 어드레스(0x10000)를
		     	; 세그먼트 레지스터 값으로 변환
	mov ds, ax	; DS 세그먼트 레지스터에 설정
	mov es, ax	; ES 세그먼트 레지스터에 설정
	
	cli		; 인터럽트가 발생하지 못하도록 설정
	lgdt [ GDTR ]	; GDTR 자료구조를 프로세서에 설정하여 GDT 테이블을 로드
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 보호 모드로 진입
; Disable paging, Disable Cache, Internal FPU, Disable Align Check,
; Enable ProtectedMode
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	mov eax, 0x4000003B	; PG=0, CD=1, NW=0, AM=0, WP=0, NE=1, ET =1
				; TS=1, EM=0, MP=1, PE=1
	mov cr0, eax		; CR0 컨트롤 레지스터 위에서 저장한 플래그를
				; 설정하여 보호 모드로 전환
; 커널 코드 세그먼트를 0x00을 기준으로 하는것으로 교체하고 EIP값을 0x00을
; 기준으로 재설정. CS 세그먼트 셀렉터 : EIP

	jmp dword 0x08: (PROTECTEDMODE - $$ + 0x10000 )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	보호 모드로 진입
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

[BITS 32]	; 이하의 코드는 32비트 코드로 설정
PROTECTEDMODE:
	mov ax, 0x10	; 보호모드 커널용 데이터 SD를 AX레지에 저장
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax

	; 스택을 0x00000000~0x0000FFFF 영역에 64KB 크기로 생성
	mov ss, ax
	mov esp, 0xFFFE
	mov ebp, 0xFFFE

	;화면에 보호 모드로 전환되었다는 메세지를 출력
	push (SWITCHSUCCESSMESSAGE - $$ + 0x10000 ) ;출력할 메세지 주소를 스택에 삽입
	push 2	; Y좌표
	push 0	; X좌표
	call PRINTMESSAGE
	add esp, 12 ; 삽입한 파라미터 제거

	jmp $ ;	무한 루프


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;	함수 코드 영역
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

PRINTMESSAGE:
	push ebp
	mov ebp, esp
	push esi
	push edi
	push eax
	push ecx
	push edx

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; X,Y의 좌표로 비디오 메모리의 주소를 계산함
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;Y 좌표를 이용해서 먼저 라인 어드레스를 구함
	mov eax, dword [ ebp + 12]
	mov esi, 160
	mul esi
	mov edi, eax
; X 좌표를 이용해서 2를 곱한 후 최종 어드레스를 구함
	mov eax, dword [ ebp + 8 ]
	mov esi, 2
	mul esi
	add edi, eax

; 출력할 무자열의 어드레스
	mov esi, dword [ ebp + 16 ]

.MESSAGELOOP:
	mov cl, byte[ esi ]

	cmp cl, 0
	je .MESSAGEEND

	mov byte [edi + 0xB8000], cl
	add esi, 1
	add edi, 2
	
	jmp .MESSAGELOOP

.MESSAGEEND:
	pop edx
	pop ecx
	pop eax
	pop edi
	pop esi
	pop ebp 
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;	데이터 영역
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; 아래의 데이터들을 8바이트에 맞춰 정렬하기 위해 추가
align 8, db 0

; GDTR의 끝을 8Byte로 정렬하기 위해 추가
dw 0x0000

; GDTR 자료구조 정의
GDTR:
	dw GDTEND - GDT - 1
	dd ( GDT - $$ + 0x10000)

; GDT 테이블 정의
GDT:
	; 널 디스크립터, 반드시 0으로 초기화해야 함
	NULLDescriptor:
		dw 0x0000
		dw 0x0000
		db 0x00
		db 0x00
		db 0x00
		db 0x00

	; 보호 모드 커널용 코드 세그먼트 디스크립터
	CODEDESCRIPTOR:
		dw 0xFFFF	; Limit [15:0]
		dw 0x0000	; Base [15:0]
		db 0x00		; Base [23:16]
		db 0x9A		; P=1, DPL=0, Code Segment, Execute/Read
		db 0xCF		; G=1, D=1, L=0, Limit[19:16]
		db 0x00		; Base [31:24]

	; 보호 모드 커널용 데이터 세그먼트 디스크립터
	DATADESCRIPTOR:
		dw 0xFFFF	; Limit [15:0]
		dw 0x0000	; Base [15:0]
		db 0x00		; Base [23:16]
		db 0x92		; P=1, DPL=0, Data Segment, Read/Write
		db 0xCF		; G=1, D=1, L=0, Limit[19:16]
		db 0x00		; Base [31:24]

GDTEND:

	; 보호 모드로 전환되었다는 메시지
	SWITCHSUCCESSMESSAGE: db 'Switch To Protected Mode Success~!!', 0

	times 512 - ( $ - $$ ) db 0x00
