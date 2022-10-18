.386
.model flat, stdcall
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;includem biblioteci, si declaram ce functii vrem sa importam
includelib msvcrt.lib
extern exit: proc
extern malloc: proc
extern calloc: proc
extern memset: proc

includelib canvas.lib
extern BeginDrawing: proc
extern scanf: proc
extern printf: proc
extern srand: proc
extern rand: proc
extern time: proc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;declaram simbolul start ca public - de acolo incepe executia
public start
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;sectiunile programului, date, respectiv cod
.data
;aici declaram date
format_scanf db "%d", 0
format_printf db "%d ", 0
format_new_line db 13, 10, 0

map_width dd 0
map_height dd 0


pixel_x dd 0
pixel_y dd 0
boat_x_rand dd 0
boat_y_rand dd 0
boat_direction dd 0 ; 0-sus 1-jos 2-dreapta 3-stanga
boat_nr dd 0
boat_piece_nr dd 0
hit dd 0
miss dd 0

window_title DB "Vaporase",0
area_width EQU 1200
area_height EQU 700
area DD 0
map DD 0
grid_ratio_coloane DD 0
grid_ratio_linii DD 0

counter DD 0 ; numara evenimentele de tip timer
zero dd 0
one dd 1
two dd 2
three dd 3
red equ 0FF0000h
blue equ 0FFh 

goz dd 0

arg1 EQU 8
arg2 EQU 12
arg3 EQU 16
arg4 EQU 20

border EQU 1140
dim_boat EQU 4

symbol_width EQU 10
symbol_height EQU 20
include digits.inc
include letters.inc

.code

print_nr macro x
	push ecx
	push edx
	push eax
	push x
	push offset format_printf
	call printf
	add esp, 8
	pop eax
	pop edx
	pop ecx
endm

print_new_line macro 
	push ecx
	push edx
	push eax
	push offset format_new_line
	call printf
	add esp, 4
	pop eax
	pop edx
	pop ecx
endm

print_map macro 
	local loop_linii, loop_coloane
	push eax
	push ebx
	push ecx
	push edx

	mov ebx, 0
	loop_coloane:
		mov edx, 0
		mov eax, map_width
		mul ebx ;eax=y*map_width index
		push ebx ;0->map_height coloane

		print_nr ebx

		mov ebx, 0 ;pt linii
		shl eax, 2 ;eax=y*map_width*4
		add eax, map
		
		loop_linii:
			push ebx ;0->map_width linii

			shl ebx, 2
			add eax, ebx 
			
			mov ecx, dword ptr [eax]
			print_nr ecx
			
			sub eax, ebx
			pop ebx
			inc ebx
			
			cmp ebx, map_width
		jne loop_linii
		
		print_new_line

		pop ebx
		inc ebx
		cmp ebx, map_height
	jne loop_coloane
	pop edx
	pop ecx
	pop ebx
	pop eax
endm


; procedura make_text afiseaza o litera sau o cifra la coordonatele date
; arg1 - simbolul de afisat (litera sau cifra)
; arg2 - pointer la vectorul de pixeli
; arg3 - pos_x
; arg4 - pos_y
make_text proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1] ; citim simbolul de afisat
	cmp eax, 'A'
	jl make_digit
	cmp eax, 'Z'
	jg make_digit
	sub eax, 'A'
	lea esi, letters
	jmp draw_text
make_digit:
	cmp eax, '0'
	jl make_space
	cmp eax, '9'
	jg make_space
	sub eax, '0'
	lea esi, digits
	jmp draw_text
make_space:	
	mov eax, 26 ; de la 0 pana la 25 sunt litere, 26 e space
	lea esi, letters
	
draw_text:
	mov ebx, symbol_width
	mul ebx
	mov ebx, symbol_height
	mul ebx
	add esi, eax
	mov ecx, symbol_height
bucla_simbol_linii:
	mov edi, [ebp+arg2] ; pointer la matricea de pixeli
	mov eax, [ebp+arg4] ; pointer la coord y
	add eax, symbol_height
	sub eax, ecx
	mov ebx, area_width
	mul ebx
	add eax, [ebp+arg3] ; pointer la coord x
	shl eax, 2 ; inmultim cu 4, avem un DWORD per pixel
	add edi, eax
	push ecx
	mov ecx, symbol_width
bucla_simbol_coloane:
	cmp byte ptr [esi], 0
	je simbol_pixel_alb
	mov dword ptr [edi], 0
	jmp simbol_pixel_next
simbol_pixel_alb:
	mov dword ptr [edi], 0FFFFFFh
simbol_pixel_next:
	inc esi
	add edi, 4
	loop bucla_simbol_coloane
	pop ecx
	loop bucla_simbol_linii
	popa
	mov esp, ebp
	pop ebp
	ret
make_text endp

; un macro ca sa apelam mai usor desenarea simbolului
make_text_macro macro symbol, drawArea, x, y
	push y
	push x
	push drawArea
	push symbol
	call make_text
	add esp, 16
endm

make_vertical_line macro dim
	local linie_verticala
	push edx
	push eax
	push ebx
	push ecx
	mov ecx, area_height ;y
	dec ecx
	linie_verticala:
		mov eax, ecx ;y
		mov edx, 0
		mov ebx, area_width
		mul ebx ;eax=y*area_width
		add eax, dim
		shl eax, 2
		add eax, area
		mov dword ptr[eax], 0 
	loop linie_verticala
	pop ecx
	pop ebx 
	pop eax
	pop edx
endm

make_horizontal_line macro linie
	local linie_orizontala
	push edx
	push eax
	push ebx
	push ecx
	mov eax, linie ;y
	mov ebx, area_width
	mul ebx
	shl eax, 2
	add eax, area
	mov ecx, border
	dec ecx
	linie_orizontala:
		mov dword ptr[eax], 0 
		add eax, 4
	loop linie_orizontala
	pop ecx
	pop ebx 
	pop eax
	pop edx
endm

show_nr macro number, coord_x1, coord_x2, coord_x3, coord_y
	mov ebx, 10
	mov eax, number
	;cifra unitatilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, coord_x1, coord_y
	;cifra zecilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, coord_x2, coord_y
	;cifra sutelor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area,  coord_x3, coord_y
endm

square macro culoare, index_x, index_y
	local loop_col_square, loop_line_square
	pusha 
	mov eax, index_y ;index y in map
	mov ebx, grid_ratio_linii
	mul ebx ; coord y in area
	mov ebx, area_width
	inc eax ;nu vreau sa colorez linia de la grid de sus(pt linii)
	mul ebx
	shl eax, 2
	add eax, area
	mov edi, eax

	mov eax, index_x
	mov ebx, grid_ratio_coloane
	mul ebx ; coord x in area
	shl eax, 2
	add edi, eax
	add edi, 4 ;nu vreau sa colorez linia de la grid din stg(pt coloane)

	mov ecx, grid_ratio_linii
	sub ecx, 1
	loop_col_square:
		push ecx
		mov ecx, grid_ratio_coloane
		sub ecx, 1
		loop_line_square:
			mov dword ptr[edi], culoare
			add edi, 4 ;edi ramane unde a ajuns dupa ce am colorat linia(coord init + grid_ratio)
		loop loop_line_square
		mov eax, area_width 
 		sub eax, grid_ratio_coloane ;lungime linie - grid_ratio 
		inc eax
  		sal eax, 2
  		add edi, eax ;edi = (coord init + grid_ratio + lungime_linie - grid_ratio)
		pop ecx
	loop loop_col_square
	popa 
endm

; functia de desenare - se apeleaza la fiecare click
; sau la fiecare interval de 200ms in care nu s-a dat click
; arg1 - evt (0 - initializare, 1 - click, 2 - s-a scurs intervalul fara click)
; arg2 - x
; arg3 - y
draw proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1]
	cmp eax, 1
	jz evt_click
	cmp eax, 2
	jz evt_timer ; nu s-a efectuat click pe nimic
	;mai jos e codul care intializeaza fereastra cu pixeli albi
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	push 255
	push area
	call memset
	add esp, 12
	
	make_vertical_line border
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	mov edx, 0
	mov eax, border
	mov ecx, map_width
	div ecx ;eax->border/map_width
	dec ecx
	mov grid_ratio_coloane, eax
	push eax
	grid_coloane:
		make_vertical_line grid_ratio_coloane
		add grid_ratio_coloane, eax
	loop grid_coloane
	pop eax
	mov grid_ratio_coloane, eax

	mov edx, 0
	mov eax, area_height
	mov ecx, map_height
	div ecx ;eax->area_height/map_width
	dec ecx
	mov grid_ratio_linii, eax
	push eax
	grid_linii:
		make_horizontal_line grid_ratio_linii
		add grid_ratio_linii, eax
	loop grid_linii
	pop eax
	mov grid_ratio_linii, eax
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	jmp afisare_litere
	
evt_click:
	cmp boat_piece_nr, 0
	je evt_timer
	mov eax, [ebp+arg3] ;eax = y
	mov pixel_y, eax ;coord pixel y
	mov ebx, area_width
	mul ebx         ;eax = y*area_width
	mov ebx, [ebp+arg2] ;ebx = x
	cmp ebx, border
	jge evt_timer ;daca trece de border nu fa nimic
	add eax, ebx
	shl eax, 2
	add eax, area
	mov ebx, 0FFFFFFFFh ;daca nu e alb nu fa nimic
	cmp dword ptr[eax], ebx
	jne afisare_litere
	
	mov edx, 0
	mov eax, [ebp+arg2] ;eax = x
	mov pixel_x, eax ;coord pixel x
	div grid_ratio_coloane
	mov boat_x_rand, eax ;index x
	print_nr eax
	mov edx, 0
	mov eax, [ebp+arg3]
	div grid_ratio_linii ;index y
	mov boat_y_rand, eax

	print_nr eax
	print_new_line

	mov eax, boat_y_rand
	mov edx, 0
	mov ebx, map_width
	mul ebx
	add eax, boat_x_rand
	shl eax, 2
			
	mov ebx, 1
	add eax, map

	cmp dword ptr [eax], ebx
	jne water
	square red, boat_x_rand, boat_y_rand
	inc hit
	dec boat_piece_nr
	cmp boat_piece_nr, 0
	jne next_click
	make_text_macro 'Y', area, 1150, 90
	make_text_macro 'O', area, 1160, 90
	make_text_macro 'U', area, 1170, 90

	make_text_macro 'W', area, 1150, 110
	make_text_macro 'O', area, 1160, 110
	make_text_macro 'N', area, 1170, 110
	jmp next_click
	water:
	square blue, boat_x_rand, boat_y_rand
	inc miss
	next_click:
	jmp afisare_litere

evt_timer:
	inc counter
	
afisare_litere:
	;afisam valoarea counter-ului curent (sute, zeci si unitati)
	show_nr counter, 1180, 1170, 1160, 10
	
	show_nr boat_piece_nr,  1180, 1170, 1160, 30
	make_text_macro 'L', area, 1150, 30

	show_nr hit, 1180, 1170, 1160, 50
	make_text_macro 'H', area, 1150, 50

	show_nr miss, 1180, 1170, 1160, 70
	make_text_macro 'M', area, 1150, 70


final_draw:
	popa
	mov esp, ebp
	pop ebp
	ret
draw endp

start:
	push offset map_width
	push offset format_scanf
	call scanf
	add esp, 8
	
	push offset map_height
	push offset format_scanf
	call scanf
	add esp, 8
	
	;initializez mapa
	mov eax, map_width
	mov ebx, map_height
	mul ebx
	mov ebx, 4
	push ebx
	push eax
	call calloc
	add esp, 4
	mov map, eax

	;nr barcute
	push offset boat_nr
	push offset format_scanf
	call scanf
	add esp, 4

	mov eax, boat_nr
	shl eax, 2
	mov boat_piece_nr, eax

	;inc boat_nr 

	;generez coordonate random pt barcute de dimensiunea de 4 "casute"
	mov eax, 0
	push eax
	call time
	add esp, 4
	push eax
	call srand
	add esp, 4

	mov ecx, 0
	
	make_barcutze:
		push ecx
		make_new_coord:
			;pt x
			call rand
			mov edx, 0
			; nr_rand%map_width = x din [0,...]
			mov ebx, map_width
			div ebx
			mov boat_x_rand, edx
			
			print_nr boat_x_rand
			;pt y
			call rand
			mov edx, 0
			; nr_rand%map_height = y din [0,...]
			mov ebx, map_height
			div ebx
			mov boat_y_rand, edx
			
			print_nr boat_y_rand
			print_new_line

			;verific daca nu se genereaza pe o celula cu barca
			mov eax, boat_y_rand
			mov edx, 0
			mov ebx, map_width
			mul ebx
			add eax, boat_x_rand
			shl eax, 2
			
			mov ebx, one
			add eax, map

			cmp dword ptr [eax], ebx
		je make_new_coord

		;mov dword ptr [eax], 1

		print_nr border
		print_new_line

		;directie random
		push eax ;locul din matrice de unde vreau sa construiesc barca
		call rand
		mov edx, 0
		mov ebx, 3
		div ebx
		mov boat_direction, edx
		pop eax

		print_nr boat_direction
		print_new_line

		;mov edx, 2 ;TESTING RIGHT

		;ce directie
		cmp edx, zero ;sus
		je boat_up
		cmp edx, one ;jos
		je boat_down
		cmp edx, two ;dreapta
		je boat_right
		jmp boat_left ;stanga
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		;verific in pt fiecare directie daca pot construi barca, daca nu, trec la urm directie
		boat_up:
			cmp boat_y_rand, 3
			jl make_new_coord ;daca nu iese din matrice
			mov ecx, 3 ;verific 3 casute in sus daca nu da de o barca 
			mov ebx, map_width
			shl ebx, 2 ;ebx=map_width*4
			coliziune_boat_up:
				sub eax, ebx ;ma duc cu un rand mai sus
				push ebx
				mov ebx, 1
				cmp  dword ptr [eax], ebx
				pop ebx
				je make_new_coord
			loop coliziune_boat_up
			mov ecx, 4
			construct_boat_up:
				mov dword ptr [eax], 1
				add eax, ebx
			loop construct_boat_up
			jmp make_another_boat

		boat_down:
			mov ecx, map_height
			sub ecx, 4
			cmp boat_y_rand, ecx
			jg make_new_coord
			mov ecx, 3
			mov ebx, map_width
			shl ebx, 2 ;ebx=map_width*4
			coliziune_boat_down:
				add eax, ebx
				push ebx
				mov ebx, 1
				cmp  dword ptr [eax], ebx
				pop ebx
				je make_new_coord
			loop coliziune_boat_down
			mov ecx, 4
			construct_boat_down:
				mov dword ptr [eax], 1
				sub eax, ebx
			loop construct_boat_down
			jmp make_another_boat
		boat_right:
			mov ecx, map_width
			sub ecx, 4
			cmp boat_x_rand, ecx
			jg make_new_coord
			mov ecx, 3
			mov ebx, 4
			coliziune_boat_right:
				add eax, ebx
				push ebx
				mov ebx, 1
				cmp  dword ptr [eax], ebx
				pop ebx
				je make_new_coord
			loop coliziune_boat_right
			mov ecx, 4
			construct_boat_right:
				mov dword ptr [eax], 1
				sub eax, ebx
			loop construct_boat_right
			jmp make_another_boat

		
		boat_left:
			cmp boat_X_rand, 3
			jl make_new_coord
			mov ecx, 3
			mov ebx, 4
			coliziune_boat_left:
				sub eax, ebx
				push ebx
				mov ebx, 1
				cmp  dword ptr [eax], ebx
				pop ebx
				je make_new_coord
			loop coliziune_boat_left
			mov ecx, 4
			construct_boat_left:
				mov dword ptr [eax], 1
				add eax, ebx
			loop construct_boat_left
			jmp make_another_boat

		make_another_boat:

		print_map

		pop ecx
		inc ecx
		cmp ecx, boat_nr

	jne make_barcutze

	;alocam memorie pentru zona de desenat
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	call malloc
	add esp, 4
	mov area, eax
	;apelam functia de desenare a ferestrei
	; typedef void (*DrawFunc)(int evt, int x, int y);
	; void __cdecl BeginDrawing(const char *title, int width, int height, unsigned int *area, DrawFunc draw);
	push offset draw
	push area
	push area_height
	push area_width
	push offset window_title
	call BeginDrawing
	add esp, 20
	;terminarea programului
	push 0
	call exit
end start
