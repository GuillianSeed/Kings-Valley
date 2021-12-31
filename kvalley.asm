
;-------------------------------------------------------------------------------
;
; King's Valley (RC727)
;
; Copyright 1985 Konami
;
; Desensamblado	e interpretado por Manuel Pazos	(jose.manuel.pazos@gmail.com)
; Santander,  17-07-2009
;
;-------------------------------------------------------------------------------


VERSION2	equ	1	; Segunda version de la ROM con correccion de fallos

;-------------------------------------------------------------------------------
; Modificando la constante VERSION2 se pueden generar las dos versiones del juego que existen
; La version 2 [A1] corrige algunos fallos de la version previa como:
;
; - Impide que se pueda lanzar un cuchillo cuando la puerta se esta abriendo.
;   De esta forma se evita que se corrompa el grafico de la puerta al pasar el cuchillo sobre ella
;
; - Impide que se pueda lanzar un cuchillo cuando se esta pegado a un objeto (gema, pico, etc...)
;   En la version original atravesaba el objeto al lanzar el cuchillo
;
; - Se puede picar sobre un muro trampa
;
; - Corregida la posicion del muro trampa de la piramide 10 de la pantalla de la izquierda, abajo a la izquierda (aparece al coger el cuchillo)
;   La version original lo tenía en la pantalla de la derecha bajo las escaleras. Pero hacia falta cabar un par de ladrillos del suelo para que apareciese.
;
; - Modificación de la posicion del muro trampa de la pirámide 12, en la pantalla de la derecha, abajo a la derecha (aparece al coger el pico) Se ha movido un tile a la derecha (?)
;
; - Los muros trampa se detienen al chocar contra un objeto. En la version anterior lo borraba (erroneamente decrementaba los decimales X en vez de la coordenada Y)
;-------------------------------------------------------------------------------

; En la piramide 10-2 hay una momia que parece por encima del suelo (!?)

;-------------------------------------------------------------------------------
; Estructuras
;-------------------------------------------------------------------------------

;--------------------------------------
; ACTOR
;--------------------------------------
ACTOR_STATUS:	 equ	0
ACTOR_CONTROL:	 equ	1			; 1 = Arriba, 2	= Abajo, 4 = Izquierda,	8 = Derecha
ACTOR_SENTIDO:	 equ	2			; 1 = Izquierda, 2 = Derecha
ACTOR_Y:	 equ	3
ACTOR_X_DECIMAL: equ	4
ACTOR_X:	 equ	5
ACTOR_ROOM:	 equ	6
ACTOR_SPEEDXDEC: equ	7
ACTOR_SPEED_X:	 equ	8
ACTOR_SPEEDROOM: equ	9
ACTOR_MOV_CNT:	 equ	0Ah
ACTOR_FRAME:	 equ	0Bh
ACTOR_JMP_P:	 equ	0Ch		; Puntero a tabla con los valores del salto
ACTOR_JMP_P_H:	 equ	0Dh
ACTOR_JUMPSENT:	 equ	0Eh		; 0 = Subiendo,	1 = Cayendo
ACTOR_SENT_ESC:	 equ	0Fh		; Sentido en el	que van	las escaleras. 0 = \  1	= /
ACTOR_POS_RELAT: equ	10h		; 0 = A	la misma altura	(o casi), 1 = Momia por	encima,	2 = Por	debajo
ACTOR_TIMER:	 equ	11h
ACTOR_TIPO:	 equ	14h
ACTOR_STRESS:	 equ	15h		; Contador de stress de	la momia (para saber si	choca muy a menudo)

;--------------------------------------
; Puerta giratoria
;--------------------------------------
SPINDOOR_STATUS: equ	0
SPINDOOR_Y:	 equ	1
SPINDOOR_X_DEC:	 equ	2
SPINDOOR_X:	 equ	3
SPINDOOR_ROOM:	 equ	4
SPINDOOR_SENT:	 equ	5
SPINDOOR_TIMER:	 equ	6

;--------------------------------------
; MUSIC
;--------------------------------------
MUSIC_CNT_NOTA:	 equ	0
MUSIC_DURAC_NOTA: equ	1
MUSIC_ID:	 equ	2
MUSIC_ADD_LOW:	 equ	3
MUSIC_ADD_HIGH:	 equ	4
MUSIC_OCTAVA:	 equ	5			; Octava?
MUSIC_VOLUME_CH: equ	6			; Volumen canal
MUSIC_VOLUME:	 equ	7
MUSIC_CNT_LOOP:	 equ	9			; Veces	que se ha reproducido un pattern
MUSIC_TEMPO:	 equ	0Ah

;-------------------------------------------------------------------------------
; BIOS
;-------------------------------------------------------------------------------

byte_6:		equ	6
byte_7:		equ	7
WRTVDP:		equ	#47
RDVRM:		equ	#4a
WRTVRM:		equ	#4d
SETRD:		equ	#50
SETWR:		equ	#53
WRTPSG:		equ	#93
RDPSG:		equ	#96
RDVDP:		equ	#13e
SNSMAT:		equ	#141	;  Read	keyboard row

H_TIMI:		equ	#fd9a





;-------------------------------------------------------------------------------
;
; ROM header
;
;-------------------------------------------------------------------------------
		SIZE    16 * 1024       ; ROM de 16K

		org	#4000

		dw	4241h
		dw	startCode
		dw	0
		dw	0
		dw	0
		dw	0
		dw	0
		dw	0

;----------------------------------------------------
; Suma HL + A
;----------------------------------------------------

ADD_A_HL:
		add	a, l
		ld	l, a
		ret	nc
		inc	h
		ret

;----------------------------------------------------
; Suma DE + A
;----------------------------------------------------

ADD_A_DE:
		add	a, e
		ld	e, a
		ret	nc
		inc	d
		ret


;-------------------------------------------------------------------------------
;
; MAIN
;
; Funcion principal llamada desde el gancho de interrupcion (50	o 60 Hz)
; Actualiza el reproductor de sonido
; Evita	que se ejecute la logica al producirse una interrupcion	si no ha
; terminado la iteracion anterior
;-------------------------------------------------------------------------------

tickMain:
		call	RDVDP		; Borra	el flag	de interrupcion
		di
		call	updateSound	; Actualiza el driver de sonido

		ld	hl, tickInProgress ; Si	el bit0	esta a 1 no se ejecuta la logica del juego
		bit	0, (hl)
		jr	nz, tickMain2	; No se	ha terminado la	iteracion anterior

		inc	(hl)		; Indica que se	va a realizar una iteracion
		ei
		call	chkControls	; Actualiza el estado de los controles
		call	runGame		; Ejecuta la logica del	juego

		xor	a
		ld	(tickInProgress), a ; Indica que ha terminado la iteracion actual

tickMain2:
		call	RDVDP		; Lee y	borra el flag de interrupcion
		or	a		; Se ha	producido una interrupcion mientras se ejecutaba logica	del juego?
		di
		call	m, updateSound	; Si, actualiza	el sonido
		ei
		ret


;----------------------------------------------------
; Lee el estado	de las teclas
; Proteccion anticopia (!?)
; Si se	ejecuta	en RAM machaca el programa
;----------------------------------------------------

ReadKeys_AC:
		ld	hl, KonamiLogo2
		ld	a, (JumpIndex2)
		ld	(hl), a
		inc	hl
		ld	(hl), 0C9h	; RET opcode
		jp	ReadKeys

;----------------------------------------------------
; Jump index
; (SP) = Puntero a funciones
;  A = Indice de la funcion
;----------------------------------------------------

jumpIndex:
		add	a, a

JumpIndex2:
		pop	hl
		call	getIndexHL_A
		jp	(hl)


;----------------------------------------------------
; Igual	que WriteDataVRAM pero escribiendo siempre 0
;----------------------------------------------------

ClearDataVRAM:
		ld	c, 0		; Mascara a aplicar con	AND al byte a escribir
		jr	writeDataVRAM2


;----------------------------------------------------
; Escribe en la	VRAM datos con formato
; In:
;   C =	Mascara	AND aplicada al	dato a escribir
;  DE =	direccion datos
;  0-1:	VRAM address
;  2...: Datos
; Datos:
;  FE: next block (nueva direccion + datos)
;  FF: end datos
;----------------------------------------------------

WriteDataVRAM:
		ld	c, 0FFh		; Mascara a aplicar con	AND al byte a escribir

writeDataVRAM2:
		ex	de, hl
		ld	e, (hl)
		inc	hl
		ld	d, (hl)
		ex	de, hl
		inc	de

writeDataVRAM3:
		ld	a, (de)
		inc	de
		ld	b, a
		inc	b		; Es #FF?
		ret	z		; Fin de los datos

		inc	b		; Es #FE?
		jr	z, writeDataVRAM2 ; Cambia puntero a VRAM

		and	c		; Aplica mascara AND al	dato a escribir	en la VRAM
		call	WRTVRM
		inc	hl
		jr	writeDataVRAM3

;-------------------------------------------------------------------------------
;
; Boot code
;
; Fija la rutina de interrupcion que llamara a la logica del juego cada	frame
; Borra	el area	de variables
; Inicializa el	hardware (modo de video, PSG)
; Ejecuta un loop infinito, tipico de Konami.
;-------------------------------------------------------------------------------

startCode:
		di
		im	1
		ld	a, 0C3h
		ld	(H_TIMI), a
		ld	hl, tickMain
		ld	(H_TIMI+1), hl	; Pone la rutina de interrupcion que lleva la logica del juego

		ld	sp, stackTop	; Fija el lugar de la pila
		ld	hl, GameStatus
		ld	de, subStatus
		ld	bc, 6FFh
		ld	(hl), 0
		ldir			; Inicializa el	area de	variables del juego

		ld	a, 1
		ld	(tickInProgress), a ; Evita que	se ejecute la logica del juego mientras	se inicializa el hardware
		call	initHardware	; Inicializa el	modo de	video y	el PSG

		xor	a
		ld	(tickInProgress), a ; Permite que se ejecute la	logica del juego en la proxima interrupcion
		call	RDVDP		; Borra	el flag	de interrupcion
		ei

dummyLoop:
		jr	$

;----------------------------------------------------
; VRAM write con proteccion anticopia
; Antes	de escribir en la VRAM machaca el codigo si se ejecuta en RAM
;----------------------------------------------------

VRAM_writeAC:
		ld	(copyProtect_+1), de ; Proteccion anticopia (!?)
		jp	setFillVRAM

;-------------------------------------------------------------------------------
;
; Tick game
;
;-------------------------------------------------------------------------------

runGame:
		ld	hl, timer
		inc	(hl)		; Incrementa timer global del juego

		ld	bc, (GameStatus) ;  C =	Game status, B = Substatus
		ld	a, (controlPlayer) ; bit 6 = Prota controlado por el jugador
		bit	6, a		; Se esta jugando?
		jr	nz, runGame2	; Si, no esta en modo demo o en	el menu

		ld	hl, chkPushAnyKey ; Se añade esta funcion para comprobar si se pulsa una tecla y hay que empezar una partida
		push	hl

runGame2:
		ld	a, c
		call	jumpIndex

		dw KonamiLogo		; 0 = Muestra el logo de Konami
		dw WaitMainMenu		; 1 = Espera en	el menu. Si   no se pulsa una tecla salta a la demo
		dw SetDemo		; 2 = Prepara el modo demo
		dw iniciaPartida	; 3 = Reproduce	musica inicio, parpadea	PLAY START y pasa al modo de juego
		dw StartGame		; 4 = Borra menu, dibuja piramide, puerta y como entra el prota
		dw gameLogic		; 5 = Logica del pergamino o del juego
		dw tickMuerto		; 6 = Pierde una vida /	Muestra	mensaje	de Game	Over
		dw tickGameOver		; 7 = Game Over
		dw stageClear		; 8 = Stage clear (suma	una vida y activa el pergamino)
		dw ScrollPantalla	; 9 = Scroll pantalla
		dw FinalJuego		; 10 = Muestra el final	del juego


;----------------------------------------------------------------------------
; Konami logo (0)
; 0 = Inicializa logo: borra pantalla, carga graficos y	pone modo grafico
; 1 = Sube el logo cada	2 frames. Subraya Konami y pone	el texto "SOFTWARE"
; 2 = Espera un	rato y borra la	pantalla.
; 3 = Dibuja el	menu.
;----------------------------------------------------------------------------

KonamiLogo:
		djnz	KonamiLogo2
		ld	a, (timer)
		rra
		ret	nc		; Sube el logo cada dos	frames

		call	dibujaLogo
		ret	nz		; Aun esta subiendo el logo

		ld	de, TXT_Sofware
		call	unpackGFXset	; Subraya Konami y pone	texto "Software"
		xor	a
		jr	UpdateSubstatus

KonamiLogo2:
		djnz	KingsValleyLogo
		ld	hl, waitCounter
		dec	(hl)
		ret	nz		; Espera un rato mostrando el logo

		call	clearScreen
		call	setColor
		xor	a
		ld	(gameLogoCnt), a ; Contador que	indica que parte del logo del menu se esta pintando
		jr	doNextSubStatus

KingsValleyLogo:
		djnz	InitLogo
		call	drawGameLogo	; Dibuja el menu
		ret	c
		xor	a
		jp	NextGameStatus_

InitLogo:
		call	clearScreen
		call	LoadIntroGfx
		call	SetVideoMode

doNextSubStatus:
		jp	NextSubStatus

;----------------------------------------------------------------------------
; Menu (1)
; Espera un rato y salta a la demo
;----------------------------------------------------------------------------

WaitMainMenu:
		ld	hl, waitCounter
		dec	(hl)
		ret	nz		; Hay que seguir esperando

		jp	NextGameStatusT	; Pasa al modo demo

;----------------------------------------------------------------------------
;
; Game demo (2)
; Pone el status de juego e inicializa las variables de	la demo
;
;----------------------------------------------------------------------------

SetDemo:
		ld	hl, 4		; Start	game status, substatus = 0
		ld	(GameStatus), hl
		ld	l, 0
		ld	(PiramidesPasadas), hl ; Cada bit indica si la piramide	correspondiente	ya esta	pasada/terminada
		ld	a, l
		ld	(numFinishGame), a ; Numero de veces que se ha terminado el juego

		call	setDatosPartida

		ld	hl, 805h	; Piramide 5, puerta de	la derecha
		ld	(piramideDest),	hl

		ld	hl, DemoKeyData	; Controles grabados de	la demo
		ld	(keyPressDemo),	hl ; Puntero a los controles grabados

		ld	a, 8
		ld	(KeyHoldCntDemo), a
		ret

UpdateSubstatus:
		ld	(waitCounter), a

NextSubStatus:
		ld	hl, subStatus
		inc	(hl)

doNothing:
		ret

;----------------------------------------------------------------------------
;
; Start	game (4)
;
;
;----------------------------------------------------------------------------

StartGame:
		ld	a, (flagPiramideMap) ; 0 = Mostrando mapa, 1 = Dentro de la piramide
		rra			; Se esta mostrando el mapa de piramides?
		jp	nc, showMap

		ld	a, b		; Substatus
		or	a		; Si es	igual a	cero esta haciendo la cortinilla desde el menu
		jr	z, waitEntrada	; No dibuja el brillo de las gemas

		push	bc
		call	drawBrilloGemas	; Dibuja el brillo de las gemas
		pop	bc

; Sub1:	Espera en las escaleras	de la entrada


waitEntrada:
		djnz	bajaEscaleras
		ld	hl, waitCounter
		dec	(hl)
		ret	nz
		jr	UpdateSubstatus

; Sub2:	Baja por las escaleras

bajaEscaleras:
		djnz	initStage2
		call	updateSprites
		jp	escalerasEntrada



;-------------------------------------------------------------------------------
; Se ejecuta tras perder una vida o al empezar una partida.
; Borra	lo que hay en pantalla con una cortinilla negra	de izquierda a derecha.
; Substatus = 0
;-------------------------------------------------------------------------------

InitStage:
		call	drawCortinilla
		ret	p


		call	hideSprAttrib	; Quita	sprites	de la pantalla
		ld	hl, Vidas
		dec	(hl)		; Quita	una vida

		ld	a, (flagMuerte)
		or	a
		jr	nz, dummyJump	; (!?)

dummyJump:				; Descomprime graficos y mapa con todos	los elementos
		call	unpackStage
		call	AI_Salidas	; Pinta	la salida abierta
		call	setSprDoorProta
		call	setAttribProta	; Actualiza atributos de los sprites del prota
		call	updateSprites	; Actualiza attributos de los sprites (RAM->VRAM)
		call	setupRoom	; Pinta	pantalla
		call	renderHUD	; Dibuja el marcador, puntos, vidas
		ld	a, 10h
		jr	UpdateSubstatus

; Sub3:	Comienza la fase

initStage2:
		djnz	InitStage
; Ha bajado las	escaleras y ya se ha cerrado la	puerta
		ld	hl, waitCounter
		dec	(hl)
		ret	nz

		xor	a
		ld	(flagStageClear), a
		call	AI_Salidas

		ld	a, (controlPlayer) ; bit 6 = Prota controlado por el jugador
		bit	6, a
		jr	z, initStage3

		ld	a, 8Bh		; Ingame music
		call	setMusic

initStage3:
		ld	hl, flagVivo
		ld	(hl), 1

NextGameStatusT:
		ld	a, 20h

NextGameStatus_:
		ld	(waitCounter), a

NextGameStatus:
		ld	hl, GameStatus
		inc	(hl)

ResetSubStatus:
		xor	a
		ld	(subStatus), a
		ret

showMap:
		djnz	doCortinilla
		ld	hl, waitCounter
		dec	(hl)
		ret	nz

		call	renderMarcador
		call	setupPergamino
		jr	initStage3

doCortinilla:
		call	drawCortinilla
		ret	p

		ld	hl, Vidas
		dec	(hl)
		ld	a, 1
		jp	UpdateSubstatus

;----------------------------------------------------
;
; Logica del juego
;
;----------------------------------------------------

gameLogic:
		ld	a, (flagPiramideMap) ; 0 = Mostrando mapa, 1 = Dentro de la piramide
		rra			; Esta en modo juego o mapa?
		push	af
		call	c, tickGame	; Logica del juego
		pop	af
		call	nc, tickPergamino ; Logica del pergamino

		ld	a, (flagEndPergamino) ;	1 = Ha terminado de mostar el pergamino/mapa
		or	a
		jr	z, chkVivo

		ld	a, 7
		ld	(GameStatus), a
		jr	NextGameStatus

chkVivo:
		ld	a, (flagVivo)
		or	a		; Esta vivo?
		ret	nz		; Si
		jr	NextGameStatusT	; No, pasa al siguiente	status

;----------------------------------------------------
;
; Pierde una vida / Muestra Game over
;
;----------------------------------------------------

tickMuerto:
		ld	a, (MusicChanData)
		or	a
		ret	nz		; Esta sonando la musica de muerte

		ld	a, (controlPlayer) ; bit 6 = Prota controlado por el jugador
		bit	6, a		; Esta en modo demo?
		jr	nz, pierdeVida

		xor	a
		jp	setGameStatus	; Reinicia el juego al morir en	el modo	demo

pierdeVida:
		ld	a, (Vidas)
		or	a
		jr	nz, setGameMode

; Borra	el area	donde se imprimira el mensaje de GAME OVER
		xor	a
		ld	hl, 3929h
		ld	b, 5

clrGameOverArea:
		push	bc
		xor	a
		ld	bc, 0Ch
		call	setFillVRAM
		ld	a, 20h
		call	ADD_A_HL
		pop	bc
		djnz	clrGameOverArea

		ld	a, 9Ah		; Musica de GAME OVER
		call	setMusic

		ld	de, TXT_GameOver
		call	WriteDataVRAM	; Imprime mensaje de GAME OVER

		ld	a, 6
		ld	(GameStatus), a	; (!?) Para que	pone esto si en	la siguiente llamada se	cambia?
		ld	a, 0B8h
		jp	NextGameStatus_	; Pasa al estado de Game Over

setGameMode:
		ld	a, 4		; Empezando la partida

setGameStatus:
		ld	(GameStatus), a
		ld	a, 20h
		ld	(waitCounter), a
		jp	ResetSubStatus

;----------------------------------------------------
;
; Logica del Game Over
; Hace una pausa suficientemente larga como para que termine la	musica
; Si se	esta pulsando alguna direccion vuelve al menu. De lo contrario muestra el logo de Konami.
;
;----------------------------------------------------

tickGameOver:
		ld	hl, timer
		ld	a, (hl)
		and	1
		ret	z		; Procesa una de cada dos iteraciones

		inc	hl
		dec	(hl)
		ret	nz		; Decrementa el	tiempo de espera

		call	chkPushAnyKey	; Comprueba si se pulsa	una tecla para volver al menu

		ld	a, (GameStatus)
		cp	7		; Modo Game Over?
		ld	de, controlPlayer ; bit	6 = Prota controlado por el jugador
		jr	z, reiniciaJuego

		ld	a, (de)
		and	10111111b	; Borra	el bit 6
		ld	(de), a
		ret

reiniciaJuego:
		ld	a, (de)
		and	10111111b	; Borra	el bit 6
		ld	(de), a
		xor	a
		jr	setGameStatus	; Muestra el logo de Konami

;----------------------------------------------------
;
; Stage	clear
;
; Silencia el sonido, incrementa la vidas y activa el pergamino
;
;----------------------------------------------------

stageClear:
		ld	a, 20h		; Silencio
		call	setMusic

		ld	hl, Vidas
		inc	(hl)		; Incrementa las vidas
		inc	hl
		ld	a, (hl)
		add	a, 1
		daa
		ld	(hl), a		; Activa pergamino/mapa
		xor	a
		ld	(flagEndPergamino), a ;	1 = Ha terminado de mostar el pergamino/mapa
		jr	setGameMode


;----------------------------------------------------
;
; Scroll de la pantalla
; Mueve	la pantalla y actualiza	la posicion del	prota
; al cambiar de	una habitacion a otra
;
;----------------------------------------------------

ScrollPantalla:
		call	tickScroll
		ret	c		; No ha	terminado el scroll

		ld	hl, GameStatus
		ld	(hl), 5		; Modo = jugando
		ld	a, (sentidoProta) ; 1 =	Izquierda, 2 = Derecha
		rra
		ld	a, (ProtaRoom)	; Parte	alta de	la coordenada X. Indica	la habitacion de la piramide
		ld	c, 0F0h		; Coordena X del prota en la parte derecha de la pantalla
		ld	b, a
		dec	b		; Mueve	el prota una pantalla a	la izquierda
		jr	c, scrollPantalla2
		inc	b
		inc	b		; Mueve	el prota una pantalla a	la derecha
		ld	c, 4		; Coordenada X en la parte izquierda

scrollPantalla2:
		ld	(ProtaX), bc	; Coloca al prota en la	posicion correcta
		jp	setAttribProta	; Actualiza atributos de los sprites del prota

;----------------------------------------------------
;
; Game ending
;
;----------------------------------------------------

FinalJuego:
		jp	ShowEnding

;----------------------------------------------------
;
; Inicia una partida
;
; - Reproduce musica de	inicio de partida
; - Parpadea PLAY START
; - Inicia las variables de la partida y pasa el estado	de juego
;
;----------------------------------------------------

iniciaPartida:
		djnz	PlayIntroMusic
		ld	hl, waitCounter
		dec	(hl)
		jr	z, ComienzaPartida

		bit	2, (hl)		; Parpadea cada	4 frames
		ld	de, TXT_PLAY_START
		jp	nz, ClearDataVRAM ; Borra texto

		jp	WriteDataVRAM	; Muestra "PLAY START"

ComienzaPartida:
		call	IniciaDatosPartida
		jp	NextGameStatusT

PlayIntroMusic:
		ld	a, 97h		; Musica de incio de partida
		call	setMusic
		ld	a, 50h
		ld	(waitCounter), a
		jp	NextSubStatus


;----------------------------------------------------
;
;----------------------------------------------------

setColor:
		ld	b, 0E0h
		ld	c, 7
		jp	WRTVDP

;----------------------------------------------------
;
; Cargar graficos del logo de Konami, la fuente	y el menu
;
;----------------------------------------------------

LoadIntroGfx:
		call	loadKonamiLogo	; Logo de Konami
		
		call	loadFont	; Fuente
		
		ld	hl, 8
		ld	de, GFX_Space	; Espacio en blanco
		call	UnpackPatterns	; Patron de espacio en blanco

setGfxMenu:
		ld	de, GFX_Menu	; Logo de King's Valley y piramide del menu
		ld	hl, 2480h	; BG char
		call	UnpackPatterns

		ld	de, ATTRIB_Menu	; Atributos de color de	la piramide del	menu
		ld	hl, 480h	; BG Attrib
		call	UnpackPatterns

		ld	hl, 44D8h	; #4D8 = Tabla de color	del logo
		ld	b, 16h

coloreaLogo:
		push	bc
		push	hl
		ld	de, COLORES_LOGO ; Atributos de	color del logo de King's Valley del menu
		call	UnpackPatterns
		pop	hl
		ld	bc, 10h
		add	hl, bc
		pop	bc
		djnz	coloreaLogo

		ld	a, 40h		; Color
		ld	bc, 10h		; Bytes	a rellenar
		jp	fillVRAM3Bank


;----------------------------------------------------
; Inicializa las variables para	una partida nueva
;----------------------------------------------------

IniciaDatosPartida:
		ld	hl, score_0000xx
		ld	bc, 0E7h
		ld	d, h
		ld	e, l
		inc	e
		ld	(hl), 0
		ldir

;----------------------------------------------------
;
; Inicializa los valores para una partida nueva
;
;----------------------------------------------------

setDatosPartida:
		ld	hl, ValoresIniciales
		ld	de, Vidas
		ld	bc, 7
		ldir
		ret
ValoresIniciales:db    5
					; Vidas
		db    1			; No muestra el	pergamino
		db    0			; Contador de vidas extra
		db    2			; Flag vivo
		db    1			; Piramide actual
		db    1			; Piramide destino
		db    8			; Direccion de la flecha

;----------------------------------------------------
;
; Carga	los graficos y prepara la piramide actual
;
;----------------------------------------------------

unpackStage:
		call	loadGameGfx	; Carga	los graficos y sprites
		jp	setupStage	; Descomprime el mapa actual

;----------------------------------------------------
; Cortinilla vertical
;----------------------------------------------------

drawCortinilla:
		ld	hl, timer
		dec	(hl)
		inc	hl
		dec	(hl)
		ret	m
		
		ld	a, (hl)
		ld	h, 38h		; #3800	es el area del BG map
		xor	1Fh
		ld	l, a
		ld	b, 18h		; Numero de patrones a escribir	verticales
		xor	a

drawCortinilla2:
		call	WRTVRM
		ld	de, 20h
		add	hl, de		; Siguiente columna
		djnz	drawCortinilla2


;----------------------------------------------------
; Borra	los atributos de los sprites de	la VRAM
;----------------------------------------------------

HideSprites:
		ld	hl, 3B00h	; Sprite attribute area
		ld	bc, 80h		; Numero de bytes a rellenar (32 sprites * 4 bytes)
		ld	a, 0C3h		; Valor	a rellenar
		call	setFillVRAM
		xor	a
		ret


;----------------------------------------------------
; Oculta los sprites colocando su coordenada Y de los
; atributos RAM	en #E1
;----------------------------------------------------

hideSprAttrib:
		ld	b, 20h

hideSprAttrib2:
		ld	hl, sprAttrib	; Tabla	de atributos de	los sprites en RAM (Y, X, Spr, Col)

hideSprAttrib3:
		ld	(hl), 0E1h
		inc	hl
		inc	hl
		inc	hl
		inc	hl
		djnz	hideSprAttrib3
		ret

;----------------------------------------------------
; Quita	momias
;----------------------------------------------------

quitaMomias:
		ld	hl, enemyAttrib
		ld	b, 0Ah
		jr	hideSprAttrib3


;----------------------------------------------------
; Dibuja los textos
; (C) KONAMI PYRAMID-xx
; El numero de la piramide se calcula:
; veces	que se ha terminado el juego * 15 + piramide actual
;----------------------------------------------------

drawPyramidNumber:
		ld	de, TXT_KONAMI_PYR
		call	WriteDataVRAM
		ld	a, (numFinishGame) ; Numero de veces que se ha terminado el juego
		ld	b, a
		add	a, a
		add	a, a
		add	a, a
		add	a, a
		sub	b		; x15
		ld	b, a
		ld	a, (piramideActual)
		add	a, b
		ld	hl, 3AF3h	; Coordenadas
		jp	drawDigit


;----------------------------------------------------
; Dibuja el numero de vidas
;----------------------------------------------------

dibujaVidas:
		ld	hl, 381Dh	; VRAM address name table = coordendas de las vidas
		ld	a, (Vidas)

drawDigit:
		call	convDecimal
		ld	b, 1
		jp	renderNumber3

;----------------------------------------------------
; Convierte un valor a decimal
;----------------------------------------------------

convDecimal:
		ld	b, a
		sub	64h
		jr	nc, convDecimal
		ld	c, 0

convDecimal2:
		ld	a, b
		sub	0Ah
		jr	c, convDecimal3
		push	af
		ld	a, c
		add	a, 10h
		ld	c, a
		pop	af
		ld	b, a
		jr	nz, convDecimal2

convDecimal3:
		ld	a, c
		or	b
		ret


;----------------------------------------------------
; Setup	menu
;----------------------------------------------------

SetUpMenu:
		call	setGfxMenu	; Carga	los graficos del logo del menu
		xor	a
		ld	(gameLogoCnt), a

loopDrawLogo:
		call	drawGameLogo
		jr	c, loopDrawLogo
		ret
;---------------------------------------------------
;
; Dibuja el logo de KING'S VALLEY del menu
; Lo hace pintando columna a columna cada palabra
;
;---------------------------------------------------

drawGameLogo:
		ld	hl, gameLogoCnt	; Contador para	saber que parte	del logo del menu se esta pintado
		ld	a, (hl)
		inc	(hl)
		cp	16h		; Ha terminado de pintar KING'S VALLEY?

copyProtect_:
		jp	nc, drawMenuEnd
		ld	hl, 38A7h	; Coordenadas de KING'S
		cp	9		; Ha terminado de pintar "KING'S"?
		jr	c, drawGameLogo2
		ld	hl, 3904h	; Coordenadas de VALLEY

drawGameLogo2:
		ld	c, a
		add	a, l
		ld	l, a
		ld	a, c
		add	a, a
		add	a, 9Bh		; #9B es el primer patron que forma el logo. KING'S(#9B-#AC), VALLEY(#AD-C6)
		ld	c, a
		ld	b, 2		; Numero de patrones a pintar por iteracion

drawGameLogo3:
		ld	a, c
		call	WRTVRM
		ld	a, 20h		; Incrementa la	coordenada Y (siguiente	fila de	patrones)
		call	ADD_A_HL
		inc	c
		djnz	drawGameLogo3

		ld	a, l
		sub	0ECh		; Nametable + #EC = Parte de abajo de la G
		cp	2
		jr	nc, drawGameLogo4
		add	a, 0C7h		; Patron parte de abajo	de la G	de KING'S
		call	WRTVRM

drawGameLogo4:
		scf
		ret

drawMenuEnd:
		ld	de, TXT_MainMenu
		call	WriteDataVRAM	; Imprime "KONAMI 1985" y "PUSH SPACE KEY"

		ld	de, GFX_PiramidLogo
		ld	hl, 3892h	; Coordenadas
		ld	bc, 306h	; Alto x ancho
		call	DEtoVRAM_NXNY
		xor	a
		ret


;----------------------------------------------------
; Muestra informacion pantalla:	marcador, vidas
;----------------------------------------------------

renderHUD:
		call	drawPyramidNumber

renderMarcador:
		ld	de, TXT_Marcador ; "REST SCORE"
		call	WriteDataVRAM
		call	dibujaVidas
		jr	renderRecord

;----------------------------------------------------
; Actualiza la puntuacion y el record
;
; DE = Puntos a	sumar
; A los	10000 puntos vida extra
; Luego	cada 20000
;----------------------------------------------------

SumaPuntos:
		ld	a, (controlPlayer) ; bit 6 = Prota controlado por el jugador
		add	a, a
		ret	p		; Esta en modo demo, no	suma puntos

		ld	hl, score_0000xx
		ld	a, (hl)
		add	a, e
		daa
		ld	(hl), a		; Actualiza unidades/decenas

		ld	e, a
		inc	l
		ld	a, (hl)
		adc	a, d		; Suma el acarreo de la	anterior operacion
		daa
		ld	(hl), a		; Actualiza centenas/unidades de millar

		ld	d, a
		inc	hl
		jr	nc, setRecord	; No han cambiado la decenas de	millar

		ld	a, (hl)
		add	a, 1		; Incrementa decenas de	millar x0000
		daa
		ld	(hl), a
		jr	nc, chkExtraLife ; Comprueba si	obtiene	una vida extra

		ld	bc, 9999h	; Maxima puntuacion posible
		ld	(record_0000xx), bc
		ld	(record_0000xx+1), bc ;	Recors = 999999
		jr	renderRecord

chkExtraLife:
		ld	a, (extraLifeCounter)
		cp	(hl)
		jr	nc, setRecord

		push	de
		push	hl
		add	a, 2		; Cada 20000 puntos
		daa
		jr	nc, chkExtraLife2
		ld	a, 0FFh

chkExtraLife2:
		ld	(extraLifeCounter), a ;	Siguiente multiplo de 10.000 en	el que obtendra	una vida extra
		call	VidaExtra	; Suma vida extra
		pop	hl
		pop	de

setRecord:
		ld	a, (record_xx0000)
		ld	b, (hl)
		sub	b
		jr	c, setRecord2	; La puntuacion	es mayor que el	record actual. Actualiza el record

		jr	nz, renderScore	; Es menor

		ld	hl, (record_0000xx)
		sbc	hl, de
		jr	nc, renderScore

setRecord2:
		ld	(record_0000xx), de
		ld	a, b
		ld	(record_xx0000), a

renderRecord:
		ld	de, record_xx0000
		ld	hl, 3811h	; Coordenadas /	Direccion VRAM
		call	renderNumber

renderScore:
		ld	hl, 3807h	; Coordenadas /	Direccion VRAM
		ld	de, score_xx0000

renderNumber:
		ld	b, 3		; Imprime 3 pares de numeros (cada byte	son dos	numeros)

renderNumber2:
		ld	a, (de)

renderNumber3:
		push	bc
		call	AL_C__AH_B	; Copia	el nibble alto de A en B y el bajo en C
		ld	a, b
		add	a, 10h		; Numero de patron que corresponde con el '0'
		call	WRTVRM

		inc	hl		; Incrementa la	coordenada X
		ld	a, c
		add	a, 10h		; Numero de patron que corresponde con el '0'
		call	WRTVRM

		dec	de		; Siguiente pareja (byte)
		inc	hl		; Siguiente posicion VRAM
		pop	bc
		djnz	renderNumber2
		ret


;----------------------------------------------------
; Copia	el nibble alto de A en B y el bajo en C
;----------------------------------------------------

AL_C__AH_B:
		push	af		; Copia	el nibble alto de A en B y el bajo en C
		rra
		rra
		rra
		rra
		and	0Fh
		ld	b, a
		pop	af
		and	0Fh
		ld	c, a
		ret

;----------------------------------------------------
;
; Borra	la pantalla
;
; Oculta los sprites y borra la	tabla de nombres
;
;----------------------------------------------------

clearScreen:
		call	HideSprites
		ld	hl, 7800h	; Tabla	de nombres (#3800) VRAM	= 16K #0000-#3FFF
		ld	bc, 300h	; Name table size
		xor	a

;----------------------------------------------------
; Rellena la VRAM
; HL = Direccion VRAM
; A = Dato
; BC = Numero de bytes
;----------------------------------------------------

setFillVRAM:
		call	setVDPWrite

fillVRAM:
		ex	af, af'

VRAM_write2:
		ex	af, af'
		exx
		out	(c), a
		exx
		ex	af, af'
		dec	bc
		ld	a, b
		or	c
		jr	nz, VRAM_write2
		ex	af, af'
		ret

;----------------------------------------------------
; Rellena BC bytes de VRAM con el dato (DE)
;----------------------------------------------------

fillVRAM_DE:
		ld	a, (de)
		inc	de
		jr	fillVRAM

;----------------------------------------------------
;
; Transfiere datos desde la RAM	a la VRAM
; HL = Direccion de destino en la VRAM
; DE = Origen
; BC = Numero de datos
;
;----------------------------------------------------

DEtoVRAMset:
		call	setVDPWrite


;----------------------------------------------------
;
; Transfiere datos desde la RAM	a la VRAM
; DE = Origen
; BC = Numero de datos
;
;----------------------------------------------------

DEtoVRAM:
		ld	a, (de)
		exx
		out	(c), a
		exx
		inc	de
		dec	bc
		ld	a, b
		or	c
		jr	nz, DEtoVRAM
		ret


;----------------------------------------------------
; Carga	la fuente y rellena la tabla de	color
;----------------------------------------------------

loadFont:
		ld	de, GFX_Font
		ld	hl, 2080h	; Pattern generator table addres (pattern 16)
		call	UnpackPatterns

		ld	a, 0F0h		; Color	blanco sobre negro
		ld	hl, 80h		; Color	table address (tile 16)
		ld	bc, 180h	; Numero de bytes a rellenar

fillVRAM3Bank:
		ld	d, 3

fillVRAM3Bank2:
		push	bc
		push	de
		call	setFillVRAM	; Rellena la tabla de color
		ld	de, 800h	; Siguiente banco
		add	hl, de
		pop	de
		pop	bc
		dec	d
		jr	nz, fillVRAM3Bank2
		ret
;----------------------------------------------------
;
; Descomprime datos de la tabla	de patrones o de colores
; en los tres bancos de	la pantalla
;
;----------------------------------------------------

UnpackPatterns:
		ld	b, 3

setPatternDatax_:
		push	bc
		push	de
		call	unpackGFX
		ld	de, 800h	; Siguiente banco
		add	hl, de
		pop	de
		pop	bc
		djnz	setPatternDatax_
		ret


;----------------------------------------------------
; (!?) Codigo no usado!!
;----------------------------------------------------
		exx
		ld	b, 3

loc_4504:
		exx
		push	bc
		push	de
		call	DEtoVRAMset
		ld	de, 800h
		add	hl, de
		pop	de
		pop	bc
		exx
		djnz	loc_4504
		ret

;----------------------------------------------------
; DE:
; +0 DW	direccion VRAM donde descomprimir
;
;----------------------------------------------------

unpackGFXset:
		ex	de, hl
		ld	e, (hl)
		inc	hl
		ld	d, (hl)
		ex	de, hl		; HL = Direccion de la VRAM
		inc	de
;---------------------------------------------------------------
; Interpreta los datos graficos
;
; DE = Datos a interpretar
; HL = VRAM address
;
; +0: Numero de	veces a	repetir	un dato
; +1: Dato a repetir
;
; Si el	bit7 del numero	de veces a repetir esta	activo:
; +0: Cantidad de bytes	a transferir a VRAM
; +1: Datos a transferir
;
; 0 = Fin de datos
;---------------------------------------------------------------


unpackGFX:
		call	setVDPWrite

unpackGFX2:
		ld	a, (de)
		and	7Fh
		ld	c, a
		ld	a, (de)
		inc	de
		jr	nz, unpackGFX3
		cp	c
		jr	nz, unpackGFXset ; Cambia a una	nueva posicion en la VRAM
		ret

unpackGFX3:
		ld	b, 0
		cp	c
		push	af
		call	nz, DEtoVRAM	; Transfiere desde DE a	VRAM (BC bytes)
		pop	af
		call	z, fillVRAM_DE
		jr	unpackGFX2

;----------------------------------------------------
; Prepara el VDP para escritura
;----------------------------------------------------

setVDPWrite:
		ex	af, af'
		call	SETWR
		exx
		ld	a, (byte_6)
		ld	c, a
		exx
		ex	af, af'
		ret


;----------------------------------------------------
;(!?) Codigo no	usado
;----------------------------------------------------
		call	SETRD		; Prepara el VDP para lectura
		exx
		ld	a, (byte_7)
		ld	c, a
		exx
		ret

;----------------------------------------------------
; Invierte un sprite
; HL = Direccion VRAM original
; DE = Direccion VRAM invertido
;----------------------------------------------------

flipSprites:
		push	de

flipSprite2:
		ld	b, 10h

flipSprite3:
		call	InviertePatron
		inc	hl
		inc	e
		djnz	flipSprite3

		ld	a, e
		sub	20h
		ld	e, a
		bit	4, e
		jr	z, flipSprite2

		pop	de
		ld	a, 20h
		call	ADD_A_DE
		dec	c
		jr	nz, flipSprites
		ret

;----------------------------------------------------
; Invierte patrones
; HL = Direccion VRAM patrones originales
; DE = Direccion VRAM patrones invertido
; C = Numero de	patrones a invertir
;----------------------------------------------------

FlipPatrones:
		ld	b, 3		; Numero de bancos de tiles

flipPatron2:
		push	bc
		push	hl
		push	de

flipPatron3:
		ld	b, 8

flipPatron4:
		call	InviertePatron
		inc	hl
		inc	de
		djnz	flipPatron4
		dec	c
		jr	nz, flipPatron3
		pop	hl
		ld	de, 800h	; Distancia al siguiente banco
		add	hl, de
		ex	de, hl
		pop	hl
		pop	bc
		djnz	flipPatron2
		ret

;----------------------------------------------------
; Invierte un byte
; In: A	= Byte a invertir
; Out: A = byte	invertido
;----------------------------------------------------

invierteByte:
		push	bc
		ld	c, a
		ld	b, 8

invierteByte2:
		rr	c
		rla
		djnz	invierteByte2
		pop	bc
		ret


;----------------------------------------------------
; Invierte un patron en	la VRAM
; HL = Direccion patron	original
; DE = Direccion patron	invertido
;----------------------------------------------------

InviertePatron:
		call	RDVRM
		call	invierteByte
		ex	de, hl
		call	WRTVRM
		ex	de, hl
		ret


;----------------------------------------------------
; Inicializa el	hardware
; Silencia el PSG, borra la VRAM y pone	el modo	de video
;----------------------------------------------------

initHardware:
		ld	a, 10111000b
		call	SetPSGMixer

		ld	a, 20h		; Silencio
		call	setMusic

		ld	de, 0		; (!?) No tendría que ser HL? Aunque la proteccion anticopia use DE, la rutina "setFillVRAM" usa HL
		ld	bc, 4000h
		xor	a
		call	VRAM_writeAC

;----------------------------------------------------
;
; Modo de video:
;
; Screen 2
; Sprites 16x16	unzoomed
; Pattern name table = #3800-#3AFF
; Pattern color	table =	#0000-#17FF
; Pattern generator table = #2000-#37FF
; Sprite atribute table	= #3b00-#3B7F
; Sprite generator table = #1800-#1FFF
; Background color = #E4 (Gris/Azul)
;----------------------------------------------------

SetVideoMode:
		ld	hl, VDP_InitData
		ld	d, 8
		ld	c, 0

setVideoMode2:
		ld	b, (hl)
		call	WRTVDP
		inc	hl
		inc	c
		dec	d
		jr	nz, setVideoMode2
		ret

VDP_InitData:	db 2
		db 0E2h
		db 0Eh
		db 7Fh
		db 7
		db 76h
		db 3
		db 0E4h


;----------------------------------------------------
;
; Actualiza el estado de los controles
;
;----------------------------------------------------

chkControls:
		ld	hl, controlPlayer ; bit	6 = Prota controlado por el jugador
		bit	6, (hl)
		jr	nz, UpdateKeys	; No esta en modo demo

		ld	a, (GameStatus)
		cp	5
		jr	nz, UpdateKeys	; No esta en modo de juego

ReplaySavedMov:
		call	ControlProtaDemo ; Lee los movimientos grabados	de la demo
		jr	storeControls	; Actualiza el valor de	los controles

UpdateKeys:
		call	ReadKeys	; Lee el estado	de los cursores	y el joystick

storeControls:
		ld	hl, KeyHold	; 1 = Arriba, 2	= Abajo, 4 = Izquierda,	8 = Derecha, #10 = Boton A, #20	=Boton B

StoreKeyValues:
		ld	c, (hl)		; Lee valores anteriores
		ld	(hl), a		; Guarda los nuevos en KeyHold
		xor	c		; Borra	las teclas que siguen pulsadas
		and	(hl)		; Se queda con las que se acaban de pulsar
		dec	hl
		ld	(hl), a		; Lo guarda en KeyTrigger
		ret



;---------------------------------------------------------------------------
; Lee el estado	de los cursores	y del joystick
; 0: Arriba
; 1: Abajo
; 2: Izquierda
; 3: Derecha
; 4: Boton A / Space
; 5: Boton B / Select
;---------------------------------------------------------------------------

ReadKeys:
		ld	e, 8Fh
		ld	a, 0Fh		; I/O port B
		call	WRTPSG		; Write	PSG
		ld	a, 0Eh
		di
		call	RDPSG		; Lee el estado	del joystick
		ei
		cpl
		and	3Fh

		push	af
		ld	a, 7
		call	SNSMAT		;  Read	keyboard row
		cpl
		rrca
		and	20h
		ld	e, a		; SELECT

		ld	a, 8
		call	SNSMAT		;  Read	keyboard row
		cpl
		rrca
		rrca
		ld	b, a
		and	4
		or	e
		ld	c, a
		ld	a, b
		rrca
		rrca
		ld	b, a
		and	18h
		or	c
		ld	c, a
		ld	a, b
		rrca
		and	3
		or	c
		pop	bc
		or	b
		ret


;----------------------------------------------------
; Interpreta la	secuencia de pulsaciones grabada para la demo
;----------------------------------------------------

ControlProtaDemo:
		ld	hl, KeyHoldCntDemo
		dec	(hl)		; decrementa tiempo de la pulsacion
		ld	b, (hl)

		ld	hl, (keyPressDemo) ; Puntero a los controles grabados
		ld	a, (hl)		; Controles pulsados

		push	af
		ld	a, b
		or	a
		jr	nz, controlDemo2 ; Aun sigue la	tecla apretada

		inc	hl
		ld	a, (hl)		; Tiempo que hay que mantener las nuevas pulsaciones
		cp	0FFh		; Ha terminado la demo?
		jr	nz, controlDemo1

		xor	a
		ld	(flagVivo), a	; Fin de la demo
		jr	controlDemo2

controlDemo1:
		ld	(KeyHoldCntDemo), a ; Actualiza	el tiempo de pulsacion
		inc	hl
		ld	(keyPressDemo),	hl ; Puntero a los controles grabados

controlDemo2:
		pop	af
		ret
;----------------------------------------------------------------------------
;
; Funcion que comprueba	si se pulsa una	tecla mientras no se esta jugando
; Si se	pulsa, salta al	menu
; Si ya	estaba en el menu comienza una partida.
;
;----------------------------------------------------------------------------

chkPushAnyKey:
		call	ReadKeys_AC	; (!?) Cuidado
		ld	hl, KeyHold2
		call	StoreKeyValues
		or	a
		ret	z		; No se	ha pulsado ninguna tecla

		push	af
		ld	a, 20h		; Silencio
		call	setMusic
		pop	af

		ld	b, a
		xor	a
		ld	(waitCounter), a
		ld	a, 1		; Status menu
		ld	hl, GameStatus
		cp	(hl)
		jr	z, StartGame_0	; Si esta en el	menu comienza una partida

		ld	(hl), a		; Pone status de menu
		call	clearScreen
		call	setColor
		jp	SetUpMenu

StartGame_0:
		ld	a, b
		and	30h
		ret	z		; No ha	pulsado	el disparo 1 o 2

		ld	hl, controlPlayer ; bit	6 = Prota controlado por el jugador
		set	6, (hl)		; Control manual
		ld	hl, 3		; Game start status
		ld	(GameStatus), hl ; Status parpadea PUSH	START
		ret


;----------------------------------------------------
; Graficos de la fuente
;----------------------------------------------------
GFX_Font:	db 8Bh,	0, 1Ch,	22h, 63h, 63h, 63h, 22h, 1Ch, 0, 18h, 38h, 4, 18h, 0CEh, 7Eh
		db 0, 3Eh, 63h,	3, 0Eh,	3Ch, 70h, 7Fh, 0, 3Eh, 63h, 3, 0Eh, 3, 63h, 3Eh
		db 0, 0Eh, 1Eh,	36h, 66h, 66h, 7Fh, 6, 0, 7Fh, 60h, 7Eh, 63h, 3, 63h, 3Eh
		db 0, 3Eh, 63h,	60h, 7Eh, 63h, 63h, 3Eh, 0, 7Fh, 63h, 6, 0Ch, 18h, 18h,	18h
		db 0, 3Eh, 63h,	63h, 3Eh, 63h, 63h, 3Eh, 0, 3Eh, 63h, 63h, 3Fh,	3, 63h,	3Eh
		db 3Ch,	42h, 99h, 0A1h,	0A1h, 99h, 42h,	3Ch, 18h, 3Ch, 18h, 8, 10h, 27h, 0, 1
		db 7Eh,	4, 0, 0C1h, 1Ch, 36h, 63h, 63h,	7Fh, 63h, 63h, 0, 7Eh, 63h, 63h, 7Eh
		db 63h,	63h, 7Eh, 0, 3Eh, 63h, 60h, 60h, 60h, 63h, 3Eh,	0, 7Ch,	66h, 63h, 63h
		db 63h,	66h, 7Ch, 0, 7Fh, 60h, 60h, 7Eh, 60h, 60h, 7Fh,	0, 7Fh,	60h, 60h, 7Eh
		db 60h,	60h, 60h, 0, 3Eh, 63h, 60h, 67h, 63h, 63h, 3Fh,	0, 63h,	63h, 63h, 7Fh
		db 63h,	63h, 63h, 0, 3Ch, 5, 18h, 83h, 3Ch, 0, 1Fh, 4, 6, 8Bh, 66h, 3Ch
		db 0, 63h, 66h,	6Ch, 78h, 7Ch, 6Eh, 67h, 0, 6, 60h, 93h, 7Fh, 0, 63h, 77h
		db 7Fh,	7Fh, 6Bh, 63h, 63h, 0, 63h, 73h, 7Bh, 7Fh, 6Fh,	67h, 63h, 0, 3Eh, 5
		db 63h,	0A3h, 3Eh, 0, 7Eh, 63h,	63h, 63h, 7Eh, 60h, 60h, 0, 3Eh, 63h, 63h, 63h
		db 6Fh,	66h, 3Dh, 0, 7Eh, 63h, 63h, 62h, 7Ch, 66h, 63h,	0, 3Eh,	63h, 60h, 3Eh
		db 3, 63h, 3Eh,	0, 7Eh,	6, 18h,	1, 0, 6, 63h, 82h, 3Eh,	0, 4, 63h
		db 0A4h, 36h, 1Ch, 8, 0, 63h, 63h, 6Bh,	6Bh, 7Fh, 77h, 22h, 0, 63h, 76h, 3Ch
		db 1Ch,	1Eh, 37h, 63h, 0, 66h, 66h, 7Eh, 3Ch, 18h, 18h,	18h, 0,	7Fh, 7,	0Eh
		db 1Ch,	38h, 70h, 7Fh, 0, 3, 24h, 4, 0,	0

; Grafico del espacio en blanco
GFX_Space:	db 8
		db 0FFh
		db    0


;----------------------------------------------------
; Textos del marcador
; Formato:
; - Coordenadas/direccion VRAM (2 bytes)
; - Patrones
; - #FE	= Leer nuevas coordenadas y datos
; - #FF	= Fin
;----------------------------------------------------
TXT_Marcador:	dw 3818h
		db  32h, 25h, 33h, 34h,	20h ; REST
		db 0FEh


		dw 3801h
		db 33h,	23h, 2Fh, 32h, 25h, 20h	; SCORE
		db 0FEh


		dw 380Eh
		db 28h,	29h, 20h	; HI
		db 0FFh


;----------------------------------------------------
; Textos del menu principal
; "KONAMI 1985"
; "PUSH SPACE KEY"
;----------------------------------------------------
TXT_MainMenu:	dw 39AAh
		db 1Ah,	2Bh, 2Fh, 2Eh, 21h, 2Dh, 29h, 0, 11h, 19h, 18h,	15h ; KONAMI 1985
		db 0FEh


		dw 3A49h
		db 30h,	35h, 33h, 28h, 0, 33h, 30h, 21h, 23h, 25h, 0, 2Bh, 25h,	39h ; PUSH SPACE KEY
		db 0FFh

;----------------------------------------------------
; Texto	"PLAY START"
;----------------------------------------------------
TXT_PLAY_START:	dw 3A49h
		db 0, 0, 30h, 2Ch, 21h,	39h, 0 ; PLAY


		db 33h,	34h, 21h, 32h, 34h, 0, 0 ; START
		db 0FFh

;----------------------------------------------------
; Mensaje de "GAME OVER"
;----------------------------------------------------
TXT_GameOver:	dw 396Bh
		db  27h, 21h, 2Dh, 25h,	  0, 2Fh, 36h, 25h, 32h	; GAME OVER
		db 0FFh


TXT_Sofware:	dw 394Ah
		db 0Ch			; Longitud linea subrayado
		db 7Ah			; Patron de subrayado
		db 16h			; Numero de espacios (para cuadrar SOFWARE debajo de la	raya)
		db 0			; Patron vacio
		db 88h			; Transferir 8 bytes a la posicion VRAM	actual
		db 33h,	2Fh, 26h, 34h, 37h, 21h, 32h, 25h ; texto:SOFTWARE
		db 0			; Fin de los datos

;----------------------------------------------------
; Texto	informacion "(C)KONAMI" "PYRAMID-"
;----------------------------------------------------
TXT_KONAMI_PYR:	dw 3AE1h
		db  1Ah			; (C)
		db 2Bh,	2Fh, 2Eh, 21h, 2Dh, 29h	; KONAMI
		db 0FEh			; Cambio de coordenadas


		dw 3AEBh		; Coordenadas
		db 30h,	39h, 32h, 21h, 2Dh, 29h, 24h, 20h ; texto: PYRAMID-
		db 0FFh


;----------------------------------------------------
;
; Descomprime los patrones que forman el logo de Konami
; y los	colorea	de blanco
;
;----------------------------------------------------

loadKonamiLogo:
		ld	a, 0Eh
		ld	(gameLogoCnt), a ; Filas que sube el logo

		ld	hl, 3AAAh	; Coordenadas iniciales	del logo
		ld	(CoordKonamiLogo), hl

		ld	de, GFX_KonamiLogo
		ld	hl, 6300h	; #2300	Pattern	generator table	= Patter #60
		call	UnpackPatterns

		ld	hl, 300h	; Direccion de los atributos de	color del logo
		ld	bc, 0D8h	; Tamaño
		ld	a, 0F0h		; Blanco
		jp	fillVRAM3Bank	; Colorea el logo



;----------------------------------------------------
;
; Dibuja el logo de Konami y lo	desplaza hacia arriba
;
; El logo esta formado por tres	filas:
; - Parte superior de la "K"
; - Parte central del logo
; - Parte inferior
;----------------------------------------------------

dibujaLogo:
		ld	hl, (CoordKonamiLogo)
		ld	de, -20h
		add	hl, de
		ld	(CoordKonamiLogo), hl ;	Lo desplaza hacia arriba una fila

		ld	a, 60h		; Primer patron	del logo de Konami
		ld	b, 3		; Tres patrones	de la parte alta de la "K"
		call	drawLogoRow	; Dibuja fila superior

		ld	bc, 0B0Ch
		call	drawLogoRow	; Dibuja fila central

		ld	b, c
		call	drawLogoRow	; Dibuja fila inferior

		xor	a
		call	setFillVRAM	; Borra	rasto inferior
		ld	hl, gameLogoCnt
		dec	(hl)		; Decrementa el	numero de iteraciones restantes
		ret

;----------------------------------------------------
; Dibuja una fila del logo y desplaza el puntero a la siguiente	fila
;
; A = Patron inicial de	la fila
; B = Numero de	patrones a dibujar
;----------------------------------------------------

drawLogoRow:
		push	hl

drawLogoRow2:
		call	WRTVRM
		inc	hl
		inc	a
		djnz	drawLogoRow2
		pop	de
		ld	hl, 20h
		add	hl, de		; Siguiente fila del logo
		ret

;----------------------------------------------------
;
; Graficos del logo de Konami
;
;----------------------------------------------------
GFX_KonamiLogo:	db 0Fh,	0, 1, 1, 6, 0, 82h, 0FFh, 0FEh,	8, 0Fh,	84h, 0C3h, 0C7h, 0CFh, 0DFh
		db 3, 0FFh, 89h, 0FEh, 0FCh, 0F8h, 0F0h, 0E0h, 0C0h, 80h, 7, 7,	5, 0, 83h, 3
		db 0CFh, 0DFh, 5, 0, 83h, 0E1h,	0F9h, 7Dh, 5, 0, 83h, 0EFh, 0FFh, 0F7h,	5, 0
		db 83h,	7, 8Fh,	9Eh, 5,	0, 83h,	0F0h, 0F8h, 78h, 5, 0, 83h, 0F7h, 0FFh,	0FBh
		db 5, 0, 8Bh, 8Fh, 0DFh, 0F7h, 0Ch, 1Eh, 1Eh, 0Ch, 0, 1Eh, 9Eh,	9Eh, 8,	0Fh
		db 90h,	0FFh, 0FFh, 0DFh, 0CFh,	0C7h, 0C3h, 0C1h, 0C0h,	7, 87h,	0C7h, 0EFh, 0FFh, 0FFh,	0FFh
		db 0FCh, 4, 0DEh, 84h, 9Eh, 9Fh, 0Fh, 3, 5, 3Dh, 83h, 7Dh, 0F9h, 0E1h, 8, 0E3h
		db 90h,	0DCh, 0C0h, 0C7h, 0DEh,	0DCh, 0DEh, 0CFh, 0C3h,	3Ch, 7Ch, 0FCh,	3Ch, 3Ch, 7Ch, 0FCh
		db 0DEh, 8, 0F1h, 8, 0E3h, 8, 0DEh, 88h, 38h, 44h, 0BAh, 0AAh, 0B2h, 0AAh, 44h,	38h
		db 3, 0, 1, 0FFh, 4, 0,	0


;----------------------------------------------------
;
; Grafico del logo de King's Valley y piramide del menu
;
;----------------------------------------------------
GFX_Menu:	db 0ACh, 0, 3, 7, 0, 1Fh, 3Fh, 7Fh, 0, 0, 3, 7,	0Fh, 0,	0, 0
		db 0FFh, 0, 0FFh, 0FFh,	0FFh, 0, 0, 1, 0FFh, 1,	3, 1, 0Eh, 3, 3Eh, 7
		db 0FCh, 0Fh, 0FCh, 0F8h, 1Fh, 0F0h, 0F0h, 0E0h, 3Fh, 7Fh, 0C0h, 0C0h, 80h, 4, 0FFh, 94h
		db 80h,	0C0h, 0E0h, 0, 0F8h, 0,	0FEh, 0, 0FFh, 0, 0, 0FFh, 0, 0, 0, 0FFh
		db 80h,	0, 0, 0F0h, 3, 0, 2, 0FFh, 3, 0, 4, 0FFh, 8Dh, 80h, 0, 0
		db 0, 0F8h, 0FCh, 0FEh,	0FFh, 3Fh, 6Fh,	37h, 17h, 0Fh, 9, 7, 97h, 0Fh, 1Fh, 0C7h
		db 83h,	7, 0Eh,	3Ch, 0F8h, 0F0h, 7Ch, 1Eh, 1Eh,	0Eh, 0Fh, 0Fh, 0Fh, 8Fh, 0C7h, 87h
		db 0Fh,	7, 0, 0Fh, 8, 7, 88h, 87h, 0EFh, 0CFh, 0, 80h, 0, 1Fh, 9Eh, 3
		db 0Fh,	6, 0Eh,	89h, 8Fh, 9Fh, 0, 0, 0,	78h, 0FCh, 0DEh, 8Eh, 7, 0Eh, 89h
		db 1Fh,	0BFh, 0, 0, 0, 0Fh, 1Fh, 38h, 30h, 4, 60h, 8Eh,	70h, 70h, 3Fh, 1Fh
		db 0Fh,	0, 0, 0, 0F9h, 0F3h, 0F3h, 71h,	70h, 71h, 3, 70h, 3, 0F0h, 0ADh, 0E0h
		db 0, 0, 3, 8Fh, 0DEh, 0DFh, 8Fh, 87h, 1, 0, 38h, 1Ch, 3Eh, 3Fh, 1Fh, 0Fh
		db 0, 0, 0F0h, 0FCh, 0Eh, 6, 0C0h, 0F0h, 0F8h, 7Ch, 1Ch, 1Eh, 3Eh, 0FEh, 0FCh, 0F8h
		db 7Fh,	0F1h, 7Bh, 11h,	7, 1Fh,	7, 7, 3, 3, 1, 1, 4, 0,	0A9h, 0C3h
		db 8Fh,	3Bh, 61h, 1, 3,	3, 86h,	86h, 0CCh, 0D8h, 0F8h, 0F0h, 0F0h, 60h,	60h, 8Fh
		db 0DBh, 0DFh, 87h, 8Eh, 0Eh, 1Fh, 1Eh,	38h, 30h, 30h, 74h, 7Ch, 7Ch, 3Ch, 18h,	0FEh
		db 0F3h, 77h, 3Eh, 7Ch,	0FCh, 9Eh, 1Eh,	1Eh, 3,	0Fh, 3,	7, 83h,	0Fh, 7,	3
		db 9, 1, 86h, 3, 87h, 8Ch, 0CDh, 0E7h, 0E0h, 6,	0C0h, 3, 0C3h, 88h, 0E1h, 0C0h
		db 8Eh,	3Fh, 0FFh, 0FFh, 0Fh, 7, 8, 3, 87h, 83h, 87h, 0CFh, 0C8h, 0CBh,	8Fh, 0C0h
		db 6, 80h, 3, 86h, 0AEh, 0C3h, 81h, 1Dh, 7Fh, 0FFh, 0FFh, 3Fh, 1Fh, 0Fh, 0Fh, 0Fh
		db 0Eh,	0Dh, 0Dh, 0Eh, 0Fh, 0Fh, 0Fh, 8Fh, 9Fh,	0BFh, 1Fh, 0FFh, 7, 1Eh, 38h, 60h
		db 0C0h, 18h, 7Ch, 0CCh, 0, 0, 1, 83h, 0FFh, 0FFh, 0FEh, 3Fh, 73h, 2Fh,	0Fh, 7
		db 3, 1, 1, 4, 0, 8Ch, 80h, 80h, 1, 3, 8Fh, 7Bh, 3, 87h, 0CEh, 0DCh
		db 0F8h, 0F8h, 6, 0F0h,	85h, 0F8h, 0FCh, 80h, 0C0h, 80h, 0Eh, 0, 84h, 60h, 70h,	3Fh
		db 3Fh,	3, 0, 85h, 70h,	70h, 0F0h, 0E0h, 0C0h, 3, 0, 0


;----------------------------------------------------
; Atributos de la piramide del menu
;----------------------------------------------------
ATTRIB_Menu:	db 1Ch,	0E0h, 88h, 0F0h, 0E0h, 0F0h, 0E0h, 0F0h, 0E0h
		db 0E0h, 0F0h, 3, 0E0h,	2, 0F0h, 3, 0E0h, 2Ch, 0F0h, 0

;----------------------------------------------------
;
; Colores del logo KING'S VALLEY
;
;----------------------------------------------------
COLORES_LOGO:	db 3, 60h, 8Dh,	80h, 80h, 90h, 90h, 0A0h, 0B0h,	0E0h, 30h
		db 70h,	50h, 50h, 40h, 40h, 0


;----------------------------------------------------
;
; Tabla	de nombres de la piramide del menu
;
;----------------------------------------------------
GFX_PiramidLogo:db    0,   0, 93h, 96h,	  0,   0
		db    0, 90h, 94h, 97h,	98h,   0
		db  91h, 92h, 95h, 99h,	99h, 9Ah

;----------------------------------------------------
;
; Pulsaciones de teclas	de la demo
;
;----------------------------------------------------
DemoKeyData:	db    8, 98h
		db    6, 38h
		db    8, 68h
		db    5,   8
		db  14h, 80h
		db    4,   8
		db  14h, 48h
		db    8, 48h
		db    5, 30h
		db    8, 40h
		db    5, 30h
		db    8, 40h
		db    5, 90h
		db    9, 38h
		db    4,   8
		db  14h, 68h
		db    4,   8
		db  14h, 10h
		db    4,   8
		db  14h, 48h
		db    8, 48h
		db    5,0A0h
		db    9,   8
		db  18h, 40h
		db    8,   8
		db  18h, 90h
		db    9, 48h
		db    4, 58h
		db    8,   8
		db  18h, 80h
		db    6,0FFh


;----------------------------------------------------
;
; Logica del juego (jugando)
;
;----------------------------------------------------

tickGame:
		ld	hl, flagStageClear
		ld	a, (hl)
		or	a		; Ha cogido todas la gemas?
		jr	z, tickGame2	; No

		ld	a, (musicCh1)
		ld	b, a
		ld	a, (musicCh2)
		or	b		; Esta sonando algo?
		jr	nz, tickGame2	; Si

		ld	(hl), a
		ld	a, 8Bh		; Ingame music
		call	setMusic	; Hace sonar de	nuevo la musica	del juego tras la fanfarria de fase completada

tickGame2:
		call	updateSprites	; Actualiza los	sprites	RAM->VRAM
		call	chkScroll	; Comprueba si el prota	se sale	de la pantalla e indica	que hay	que hacer scroll
		call	drawBrilloGemas	; Cambia el color del brillo de	las gemas y de la palanca de la	puerta

		ld	a, (flagEntraSale) ; 1 = Entrando o saliendo de	la piramide. Ejecuta una logica	especial para este caso
		and	a		; Esta entrando	o saliendo de la piramide?
		jp	nz, escalerasEntrada ; Ejecuta logica especial para este caso

		call	chkPause	; Comprueba si se pausa	el juego o ya esta pausado
		call	AI_Momias	; Mueve	a las momias
		call	AI_Gemas	; Si se	coge una se borra de la	pantalla y del mapa
		call	AI_Prota	; Logica del prota
		call	AI_Cuchillos	; Logica de los	cuchillos
		call	chkCogeKnife	; Comprueba si el prota	coge un	cuchillo del suelo
		call	chkCogeGema	; Comprueba si el prota	coge una gema
		call	AI_Salidas	; Logica de las	puertas	de la piramide
		call	MurosTrampa	; Logica de los	muros trampa que se cierran al pasar el	prota
		call	chkCogePico	; Comprueba si el prota	coge un	pico
		call	chkTocaMomia	; Comprueba si el prota	toca a una momia
		call	spiningDoors	; Logica de las	puerta giratorias


; Comprueba si se suicida pulsando F2

		ld	a, (controlPlayer) ; bit 6 = Prota controlado por el jugador
		bit	6, a
		ret	z		; Esta en modo demo, no	comprueba si se	suicida	pulsado	F2

		ld	a, 6		; Si se	pulsa F2 se suicida
		call	SNSMAT		;  Read	keyboard row
		cpl
		bit	6, a		; F2 key
		jr	z, doNothing2

		xor	a
		ld	(flagVivo), a
		inc	a
		ld	(flagMuerte), a
		ld	a, 1Dh		; Musica muerte
		call	setMusic

doNothing2:
		ret

;-----------------------------------------------------------------------------------------------------------
;
; Actualiza los	atributos de los sprites RAM ->	VRAM
; Al prota y al	cacho de puerta	los pinta siempre en los mismos	planos
; A los	enemigos los cambia de plano para evitar que desaparezcan si coinciden mas de 5	sprites	en la misma Y
;
;-----------------------------------------------------------------------------------------------------------

updateSprites:
		ld	de, sprAttrib	; Tabla	de atributos de	los sprites en RAM (Y, X, Spr, Col)
		ld	hl, 3B00h	; Tabla	de atributos de	los sprites
		ld	bc, 18h		; 6 sprites (6*4)
		call	DEtoVRAMset

		ld	hl, offsetPlanoSpr ; Contador que modifica el plano en el que son pintados los sprites,	asi se consigue	que parpaden en	vez de desaparecer
		inc	(hl)		; Incrementa el	desplazamiento de plano	de los enemigos
		ld	a, (hl)
		and	3		; Rango	de 0-3 (4 enemigos max.)
		ld	c, a		; C = indice de	desplazamiento
		add	a, a
		add	a, a		; x4 (sprite attribute size)
		ld	de, enemyAttrib	; Tabla	de atributos de	los enemigos en	RAM
		call	ADD_A_DE	; Calcula el plano que le corresponde a	ese desplazamiento
		ld	hl, 3B18h	; Direccion VRAM de los	atributos de los sprites de los	enemigos
		ld	b, 4		; Numero de enemigos/planos a rotar

setSprAttrib2:
		push	bc
		ld	bc, 4
		call	DEtoVRAMset	; Actualiza los	atributos de un	sprite/momia
		pop	bc
		ld	a, 4
		call	ADD_A_HL	; Siguiente momia
		inc	c		; Incrementa el	indice de desplazamiento
		ld	a, c
		cp	4		; Comprueba si ha llegado al ultimo plano reservado para enemigos
		jr	nz, setSprAttrib3

		ld	de, enemyAttrib	; Apunta al comienzo de	la tabla de atributos de los enemigos
		ld	c, 0		; Resetea el indice

setSprAttrib3:
		djnz	setSprAttrib2

		ld	de, unk_E0D8	; Attributos del resto de sprites del juego
		ld	hl, 3B28h
		ld	bc, 58h		; Attrib. size
		jp	DEtoVRAMset	; Actualiza VRAM


;----------------------------------------------------
; Comprueba si el prota	llega a	los limites laterales de la pantalla
; Si es	asi, indica que	hay que	realizar scroll	y quita	los sprites
;----------------------------------------------------


chkScroll:
		ld	a, (sentidoProta) ; 1 =	Izquierda, 2 = Derecha
		rra
		ld	a, (ProtaX)
		jr	nc, chkScroll2
		cp	2		; Limite parte derecha
		ret	nc
		jr	c, chkScroll3

chkScroll2:
		cp	0F4h		; Limite parte izquierda
		ret	c

chkScroll3:
		ld	a, 20h
		ld	(waitCounter), a ; Numero de desplazamientos o tiles a moverse
		ld	a, 1
		ld	(flagScrolling), a ; Se	esta realizando	el scroll
		call	HideSprites	; Borra	sprites	dela VRAM
		call	hideSprAttrib	; Borra	sprites	de la RAM
		ld	a, 9		; Scroll mode
		ld	(GameStatus), a
		pop	hl
		ret


;----------------------------------------------------
; Cambia el color de los destellos de las gemas
; y de la palanca de la	puerta
;----------------------------------------------------

drawBrilloGemas:
		ld	a, (timer)
		rra
		and	3		; Indice de color a usar

		push	af
		ld	hl, coloresBrillo ; Colores de los destellos de	las gemas
		ld	de, 288h	; Color	table address (destellos)
		ld	bc, 18h		; Numero de bytes (3 destellos por 8 bytes)
		call	chgColorBrillo	; Cambia el color de los destellos de las gemas
		pop	af

		ld	bc, 3		; Numero de bytes a cambiar
		ld	de, 2E5h	; Color	table address de la parte inferior de la palanca de la puerta
		ld	hl, ColoresPalanca ; Colores de	la palanca de la puerta

chgColorBrillo:
		call	ADD_A_HL
		ld	a, (hl)
		ex	de, hl
		jp	fillVRAM3Bank

coloresBrillo:	db 10h,	0F0h, 0A0h, 0A0h
					; Colores de los destellos de las gemas

ColoresPalanca:	db 16h,	0F6h, 0A6h, 0A6h
					; Colores de la	palanca	de la puerta



;----------------------------------------------------
;
; Comprueba si se pulsa	F1 para	pausar el juego
; Si se	pausa, muestra el texto	PAUSING	en la esquina inferior derecha del mapa
;
;----------------------------------------------------

chkPause:
		ld	a, (controlPlayer) ; bit 6 = Prota controlado por el jugador
		bit	6, a
		ret	z		; Esta en modo demo

		ld	a, 6		; F3 F2	F1 CODE	CAPS GRAPH CTRL	SHIFT
		call	SNSMAT		;  Read	keyboard row
		cpl
		ld	hl, keyHoldMap
		call	StoreKeyValues
		bit	5, a		; keyTrigger F1
		inc	hl
		inc	hl
		ld	a, (hl)		; Flag que indica si esta pausado
		jr	nz, chkPause2	; Se ha	pulsado	F1
		and	a		; Esta pausado?
		ret	z		; No

		call	blinkPausing	; Muestra el cartel de "PAUSING" parpadeando
		pop	hl
		ret

chkPause2:
		xor	1
		ld	(hl), a		; Invierte el flag de pausa
		and	a
		jr	z, erasePausing	; Se acaba de quitar la	pusa, borra el letrero
		ret

blinkPausing:
		ld	a, (timer)
		ld	b, a
		and	7
		ret	nz		; El parpadeo dura 8 frames

		bit	4, b		; Cada 8 frames	muestra	el texto o lo borra
		ld	de, txtPAUSING
		jr	z, printPause

erasePausing:
		ld	de, eraseData

printPause:
		ld	hl, 3AF6h	; Coordenadas de pantalla
		ld	bc, 7
		jp	DEtoVRAMset


txtPAUSING:	db 30h,	21h, 35h, 33h, 29h, 2Eh, 27h
					; PAUSING



;----------------------------------------------------
;
; Logica del prota
;
;----------------------------------------------------

AI_Prota:
		ld	hl, setAttribProta ; Actualiza atributos de los	sprites	del prota
		push	hl		; Mete en la pila la funcion que actualiza los atributos del prota
		ld	a, (protaStatus) ; Obtiene el estado actual del	prota
		and	a
		jr	z, AI_Prota2	; Estado 0 = Andando

		cp	3
		jr	nz, AI_Prota3	; Estado 2 = Cayendo. No comprueba los controles

AI_Prota2:
		ld	hl, protaControl ; 1 = Arriba, 2 = Abajo, 4 = Izquierda, 8 = Derecha, #10 = Boton A, #20 =Boton	B
		ld	a, (KeyHold)	; 1 = Arriba, 2	= Abajo, 4 = Izquierda,	8 = Derecha, #10 = Boton A, #20	=Boton B
		ld	(hl), a		; Copia	los controles/teclas pulsados al control del prota
		and	a
		jr	z, AI_Prota3	; No hay ninguna tecla pulsada

		rra
		rra
		and	3
		jr	z, AI_Prota3	; No esta pulsado ni DERECHA ni	IZQUIERDA

		inc	hl
		ld	(hl), a		; Sentido del prota

AI_Prota3:
		ld	a, (protaStatus) ; Estado del prota
		call	jumpIndex
		dw protaAnda		; 0 = Andar
		dw protaSalta		; 1 = Realiza el salto y comprueba si choca con	algo
		dw protaCayendo		; 2 = Cayendo
		dw protaEscaleras	; 3 = Mueve al prota por las escaleras y comprueba si llega al final de	estas
		dw protaLanzaKnife	; 4 = Anima al prota para hacer	la animacion de	lanzamiento. Al	terminar restaura el sprite y pasa al estado de	andar
		dw protaPicando		; 5 = Animacion	del prota picando y rompiendo los ladrillos
		dw protaGiratoria	; 6 = Pasando por una puerta giratoria

;----------------------------------------------------
; Prota	status 0: Andar
;----------------------------------------------------

protaAnda:
		ld	a, (KeyTrigger)
		bit	4, a		; Acaba	de pulsar FIRE1	/ Boton	A?
		jr	z, protaAnda2	; No

		ld	a, (objetoCogido) ; #10	= Cuchillo, #20	= Pico
		and	0F0h		; Tiene	algun objeto el	prota?
		jp	z, setProtaSalta ; No, intenta saltar

		cp	10h		; Es un	cuchillo?
		jp	nz, chkProtaPica ; No, es un pico. Intenta hacer un agujero

		jp	setLanzaKnife	; Lanza	el cuchillo

protaAnda2:
		call	chkProtaCae	; Hay suelo bajo el prota?
		jp	c, setProtaCae	; No hay suelo

		xor	a
		ld	(modoSentEsc), a ; Si es 0 guarda en "sentidoEscalera" el tipo de escalera que se coge el prota. 0 = \, 1 = /
		call	chkCogeEscalera	; Comprueba si coge una	escalera para subir o bajar
		ret	z		; si, la ha cogido

		ld	hl, protaControl ; 1 = Arriba, 2 = Abajo, 4 = Izquierda, 8 = Derecha, #10 = Boton A, #20 =Boton	B
		ld	a, (hl)
		and	1100b		; Se queda solo	con los	controles DERECHA e IZQUIERDA
		jp	z, protaQuieto	; No se	mueve hacia los	lados

		ld	hl, protaMovCnt	; Contador usado cada vez que se mueve el prota. (!?) No se usa	su valor
		inc	(hl)		; Incrementa el	contador de movimientos

		call	chkChocaAndar
		jr	nc, protaAnda3	; No choca

		ld	a, (hl)		; HL apunta al tile del	mapa contra el que ha chocado
		and	0F0h		; Se queda con el tipo de tile/familia
		cp	50h		; Es una puerta	giratoria?
		jr	nz, protaAnda5	; No

		ld	a, (hl)
		and	0Fh		; Tipo de tile de puerta giratoria
		sub	1
		cp	2		; Ha choacado contra la	parte azul de la puerta?
		jr	c, protaAnda5	; No

		ld	hl, timerEmpuja	; Timer	usado para saber el tiempo que se empuja una puerta giratoria
		inc	(hl)		; Incrementa tiempo de empuje
		ld	a, 10h		; Tiempo necesario de empuje para que se mueva la puerta
		cp	(hl)
		jp	nz, protaAnda5	; Aun no ha empujado lo	suficiente

		ld	a, 6		; Estado: Pasando por una puerta giratoria
		ld	(protaStatus), a ; Actualiza el	estado del prota
		ld	a, 20h
		ld	(accionWaitCnt), a ; Contador usado para controlar la animacion	y duracion de la accion	(lanzar	cuchillo, cavar, pasar puerta giratoria)

		ld	a, 3		; Puerta giratoria
		call	setMusic
		jp	chkGiratorias	; Identifia la puerta que esta empujando

protaAnda3:
		xor	a
		ld	(timerEmpuja), a ; Resetea contador de empuje

protaAnda4:
		call	mueveProta	; Actualiza las	coordenadas del	prota

protaAnda5:
		jp	calcFrame	; Actualiza el fotograma de la animacion

;----------------------------------------------------
; Actualiza los	atributos de los dos sprite del	prota en RAM
; segun	sus coordenadas
;----------------------------------------------------

setAttribProta:
		ld	hl, ProtaY	; Actualiza atributos de los sprites del prota
		ld	c, (hl)		; Y prota
		inc	hl
		inc	hl		; X prota
		ld	b, (hl)		; BC = XY
		ld	a, (protaFrame)
		ld	hl, protaAttrib
		dec	c
		dec	c
		bit	0, a		; El frame es par o impar?
		jr	z, setAttribProta2
		inc	c		; Los frames pares los mueve un	pixel hacia arriba

setAttribProta2:
		ld	de, framesProta	; Sprite a usar	segun el frame
		call	ADD_A_DE
		ld	a, (de)		; Numero de sprite
		ld	d, a
		call	setAttribProta3

setAttribProta3:			; Y
		ld	(hl), c
		inc	hl
		ld	(hl), b		; X
		inc	hl
		ld	a, (sentidoProta) ; 1 =	Izquierda, 2 = Derecha
		rra			; En que sentido mira?
		ld	a, d
		jr	nc, setAttribProta4 ; Derecha
		add	a, 60h		; Distancia a sprites girados a	la izquierda

setAttribProta4:
		ld	(hl), a		; Sprite
		ld	a, d
		add	a, 4		; Siguiente sprite 16x16
		ld	d, a
		inc	hl		; Color
		inc	hl		; Atributos del	siguiente sprite
		ret


;----------------------------------------------------
; Pone el frame	del elemento segun su contador de movimientos
; Cada 4 movimientos se	incrementa en 1	el numero de frame
; El rango de valores es de 0 a	7
;----------------------------------------------------

calcFrame:
		ld	hl, protaMovCnt	; Contador usado cada vez que se mueve el prota. (!?) No se usa	su valor

calcFrame2:
		ld	a, (hl)
		rra
		rra
		and	7
		inc	hl
		ld	(hl), a
		ret

protaQuieto:
		xor	a
		ld	(accionWaitCnt), a ; Contador usado para controlar la animacion	y duracion de la accion	(lanzar	cuchillo, cavar, pasar puerta giratoria)
		inc	a		; Pies juntos
		jr	setProtaFrame


		ld	a, 2		; (!?) Esto no se ejecuta nunca!

setProtaFrame:
		ld	(protaFrame), a
		ret


;----------------------------------------------------
; Numero de sprite a usar en cada frame	del prota
;----------------------------------------------------
framesProta:	db    8
		db    0			; 1 = Pies juntos
		db  10h			; 2 = Saltando
		db    8			; 3 = Andando
		db    0			; 4 = Pies juntos
		db  10h			; 5 = Pies separados
		db    0			; 6 = Pies juntos
		db  10h			; 7 = Pies separados
		db  18h			; 8 = Frame 1 accion (cavando, lanzando)
		db  20h			; 9 = Frame 2 accion


;----------------------------------------------------
; Se ha	pulsado	el boton de salto
; El prota intenta saltar
;----------------------------------------------------

setProtaSalta:
		ld	hl, ProtaY
		ld	a, (hl)
		and	a
		ret	z		; No salta. El prota esta en la	parte superior de la pantalla, pegado arriba del todo

		call	chkSaltar	; Comprueba si puede saltar o hay algun	obstaculo que se lo impide
		ret	nc		; Choca	contra algo. No	puede saltar

		ex	de, hl
		ld	a, (hl)		; Puntero al mapa
		and	0F0h
		cp	10h		; Es una plataforma o muro?
		ret	z		; Si

setProtaSalta_:
		ld	a, (KeyHold)	; 1 = Arriba, 2	= Abajo, 4 = Izquierda,	8 = Derecha, #10 = Boton A, #20	=Boton B
		ld	(sentidoEscalera), a ; Guarda el estado	de las teclas al saltar
		ld	hl, protaStatus	; Puntero a los	datos del prota
		jp	Salta

;----------------------------------------------------
; Prota	status 1: Saltar
; Actualiza sus	coordenadas y comprueba	si choca con al	al saltar
; Si choca, pasa al estado de cayendo
;----------------------------------------------------

protaSalta:
		ld	hl, sentidoProta ; 1 = Izquierda, 2 = Derecha
		call	doSalto		; Actualiza la posicion	del prota al saltar
		ld	hl, protaStatus	; Puntero a los	datos del prota
		push	hl
		pop	ix
		call	chkChocaSalto	; Comprueba si choca con algo en el salto
		ret	nz		; No ha	chocado	con nada

		ld	a, 3
		ld	(protaStatus), a ; (!?)	Para que pone esto! Seguido se cambia a	estatus	cayendo
		jr	protaCayendo

;----------------------------------------------------
; El prota ha llegado al suelo
; Pone estado de andar/normal y	reproduce efecto de aterrizaje
;----------------------------------------------------

protaAterriza:
		ld	a, 2		; SFX choca suelo
		call	setMusic
		xor	a
		ld	(protaStatus), a ; Pone	estado de andar
		ret


;----------------------------------------------------
; Pone al prota	en estado de caida
;----------------------------------------------------

setProtaCae:
		xor	a
		ld	(flagSetCaeSnd), a ; Si	es 0 hay que inicializar los datos del sonido de caida
		ld	a, 1
		call	setMusic	; SFX caer

;----------------------------------------------------
; Prota	status 2: Caer
; Actualiza las	coordenadas del	prota debido a la caida
; Pone estado de caida
; Comprueba si llega al	suelo
;----------------------------------------------------

protaCayendo:
		ld	hl, protaStatus	; Puntero al estado del	prota
		call	cayendo		; Pone estado de cayendo y comprueba si	llega al suelo
		jp	nc, protaAterriza ; Ha llegado al suelo
		ret


;----------------------------------------------------
; Prota	status 3: Escaleras
; Mueve	al prota por las escaleras y comprueba si llega	al final
; Si llega al final pasa al estado de andar
;----------------------------------------------------

protaEscaleras:
		ld	hl, protaControl ; 1 = Arriba, 2 = Abajo, 4 = Izquierda, 8 = Derecha, #10 = Boton A, #20 =Boton	B
		ld	a, (hl)
		and	0Ch
		ret	z		; No esta pulsado DERECHA ni IZQUIERDA

		ld	b, 1		; Velocidad del	prota en las escaleras (mascara	aplicada al timer)
		xor	a
		ld	(quienEscalera), a ; (!?) Se usa esto? Quien esta en una escalera 0 = Prota. 1 = Momia
		call	andaEscalera	; Mueve	al prota por la	escalera y comprueba si	llega al final
		jr	z, protaEscaleras2 ;  Ha llegado al final de las escaleras
		jp	calcFrame	; Actualiaza el	frame de la animacion

protaEscaleras2:
		xor	a		; Estado: andar
		jr	protaEscaleras3



		ld	a, 3		; (!?) Este codigo no se ejecuta nunca!

protaEscaleras3:
		ld	(protaStatus), a ; Esto	solo se	usa para poner al prota	en estado de andar al terminar una escalera
		ret

;----------------------------------------------------
; El prota lanza un cuchillo
;----------------------------------------------------

setLanzaKnife:
	IF	(VERSION2)
		xor	a
		ld	hl,ElemEnProceso
		ld	(hl),a
chkPuertaMov:		
		push	hl
		ld	a,04
		call	getExitDat	; Obtiene puntero al estatus de la puerta que se está procesando
		and	#F0		; Se queda con el status (nibble alto)
		cp	#30		; Se esta abriendo?
		pop	hl
		ret	z		; Impide lanzar el cuchillo mientras la puerta se abre para impedir que se corrompan los tiles al pasar el cuchillo sobre la puerta
		inc	(hl)
		ld	a,04		; Numero máximo de cuchillos
		cp	(hl)
		jr	nz,chkPuertaMov ; Aún quedan cuchillos por comprobar
	ENDIF

		xor	a
		ld	(lanzamFallido), a ; 1 = El cuchillo se	ha lanzado contra un muro y directamente sale rebotando

		ld	hl, sentidoProta ; 1 = Izquierda, 2 = Derecha
		ld	a, (hl)
		inc	hl		; Apunta a la Y
		rra
		ld	bc, 0FF00h	; X-1
		jr	c, setLanzaKnife2 ;  Lo	lanza a	la izquierda
		ld	b, 12h		; X+18

setLanzaKnife2:
		push	bc
		call	chkTocaMuro	; Lo esta intentando lanzar pegado a un	muro?
		pop	bc
		jr	z, setLanzaKnife4 ; Si,	asi no se puede	a no ser que haya un hueco un tile por encima

	IF	(VERSION2)
		push	bc
		ld	a,(de)		; Tile del mapa contra el que ha chocado
		call	chkKnifeChoca	; Comprueba el tipo de tile que es
		pop	bc
		jr	z,setLanzaKnife4 ; Es un muro, cuchillo, gema o pico

	ENDIF

setLanzaKnife3:
		ld	a, 15h
		ld	(accionWaitCnt), a ; Contador usado para controlar la animacion	y duracion de la accion	(lanzar	cuchillo, cavar, pasar puerta giratoria)
		ld	a, 4
		ld	(protaStatus), a ; Cambia el estado del	prota a	"lanzando cuchillo"
		jp	setFrameLanzar	; Pone fotograma de lanzar cuchillo

; Comprueba si al lanzar un cuchillo contra un muro
; hay un hueco sobre este para que caiga el cuchillo
; Por ejemplo: el prota	esta en	un agujero pero	a los lados sobre su cabeza hay	sitio libre

setLanzaKnife4:

	IF	(VERSION2)
		cp	#10		; Es un muro?
		ret	nz		; No
	ENDIF

		dec	c		; El tile que esta una fila por	encima del prota
		ld	hl, ProtaX
		ld	a, (hl)		; X prota
		and	7
		cp	4		; En medio de un tile?
		ret	nz		; No

		dec	hl
		dec	hl		; Apunta a la Y
		call	chkTocaMuro	; Z = choca
		ld	a, c		; Tile comprobado
		or	a		; Es cero?
		ret	nz		; No esta libre

		ld	hl, lanzamFallido ; 1 =	El cuchillo se ha lanzado contra un muro y directamente	sale rebotando
		inc	(hl)
		jr	setLanzaKnife3

;----------------------------------------------------
; Prota	status 4: El prota esta	lanzando un cuchillo
; Aqui llega el	prota con el frame 1 de	lanzar puesto
; Tras unas iteraciones	pasa al	frame 2	de la animacion
; Al terminar la animacion/espera, se restaura el sprite normal	(sin objeto en las manos) y el estado de andar
;----------------------------------------------------

protaLanzaKnife:
		ld	hl, accionWaitCnt ; Contador usado para	controlar la animacion y duracion de la	accion (lanzar cuchillo, cavar,	pasar puerta giratoria)
		bit	4, (hl)		; Es menor de #10?
		jr	z, chkLanzaEnd

		dec	(hl)
		ld	a, (hl)
		and	0Fh		; Al llegar lanzaWaitCnt a #10 pone el segundo frame de	la animacion de	lanzar
		ret	nz

		ld	hl, IDcuchilloCoge ; Cuchillo que coge el prota
		ld	a, (hl)
		inc	hl
		ld	(hl), a		; Cuchillo en proceso

		xor	a
		call	getKnifeData
		ld	(hl), 4		; Estado: lanzamiento

		ld	a, (sentidoProta) ; 1 =	Izquierda, 2 = Derecha
		and	3
		inc	hl
		ld	(hl), a		; Pone al cuchillo el mismo sentido que	tiene el prota

		ld	a, (lanzamFallido) ; 1 = El cuchillo se	ha lanzado contra un muro y directamente sale rebotando
		or	a		; Sale directamente rebotando contra el	muro?
		jr	z, setFrameLanzar2 ; Pone frame	2 del lanzamiento: brazo abajo


; El cuchillo directamente sale	rebotando para caer sobre el muro que esta delante

		dec	hl
		ld	(hl), 7		; estado: rebotando
		inc	hl		; sentido
		inc	hl		; Y

		ld	de, ProtaY
		ld	a, (de)		; Y del	prota
		sub	8
		ld	(hl), a		; Y del	cuchillo 8 pixeles por encima del prota

		inc	hl		; X decimales
		inc	hl		; X cuchillo
		inc	de		; X decimales
		inc	de		; X prota

		ld	a, (de)		; X prota
		add	a, 4
		ld	(hl), a		; X del	cuchillo igual a X prota + 4
		inc	hl
		inc	de
		ld	a, (de)		; Habitacion prota
		ld	(hl), a		; Habitacion cuchillo

		ld	a, 4
		call	ADD_A_HL
		ld	(hl), 0

setFrameLanzar2:
		ld	a, 9		; Frame	2 de lanzar cuchillo (accion frame 2)
		jp	setFrameProta

setFrameLanzar:
		ld	a, 8		; Frame	de lanzar cuchillo (accion frame 1)

setFrameProta:
		ld	(protaFrame), a
		ret

;----------------------------------------------------
; Comprueba si termina el lanzamiento para restaurar el	sprite y el estado de andar
;----------------------------------------------------

chkLanzaEnd:
		ld	hl, accionWaitCnt ; Contador usado para	controlar la animacion y duracion de la	accion (lanzar cuchillo, cavar,	pasar puerta giratoria)
		dec	(hl)
		ret	nz

		xor	a
		ld	(protaStatus), a ; Pone	estado de andar
		jr	quitaObjeto	; Carga	sprites	normales (sin objeto)



;----------------------------------------------------
; Status 5: Prota picando
; Animacion del	prota picando y	rompiendo los ladrillos
;----------------------------------------------------

protaPicando:
		ld	hl, accionWaitCnt ; Contador usado para	controlar la animacion y duracion de la	accion (lanzar cuchillo, cavar,	pasar puerta giratoria)
		dec	(hl)
		ld	a, (hl)
		and	0Fh
		jr	z, protaPicando3

		ld	a, (hl)
		bit	4, a
		ld	a, 9		; Frame	2 de la	accion de picar
		jr	z, protaPicando2
		dec	a		; Frame	1 de la	accion de picar

protaPicando2:
		jp	setProtaFrame

protaPicando3:
		ld	a, (hl)		; Contador de la accion	de picar
		bit	4, a		; Es multiplo de #20
		ld	b, 4		; Frames con el	pico abajo
		jr	nz, protaPicando4

		ld	b, 8		; Frames con el	pico arriba
		push	bc
		push	hl
		ld	hl, agujeroCnt	; Al comenzar a	pica vale #15
		dec	(hl)
		dec	(hl)
		dec	(hl)
		call	drawAgujero	; Dibuja la animacion de como se rompen	los ladrillos al picar y los borra del mapa
		pop	hl
		pop	bc

protaPicando4:
		ld	a, (hl)		; AccionWaitCnt
		and	0F0h
		or	b		; Numero de frames que se mantiene en la posicion actual
		xor	10h
		ld	(hl), a

		ld	a, (agujeroCnt)	; Al comenzar a	pica vale #15
		and	a
		ret	nz		; No ha	terminado de hacer el agujero

		call	chkIncrust	; Comprueba que	al terminar el agujero el prota	no este	incrustado (?)

		ld	a, 1
		call	setProtaFrame	; Pone frame con los pies juntos

		xor	a
		ld	(protaStatus), a ; Restaura estado de andar

;----------------------------------------------------
; Quita	el objeto que se tiene.
; Actualiza los	sprites	dependiendo de que se lleve en las manos
;----------------------------------------------------

quitaObjeto:
		xor	a

cogeObjeto:
		ld	(objetoCogido),	a ; #10	= Cuchillo, #20	= Pico
		jp	loadAnimation	; Actualiza los	sprites	del prota


;----------------------------------------------------
; Prota	usa pico
; Comprueba si	el prota puede hacer un	agujero	con el pico
; Para ello tiene que estar sobre suelo	firme (plataforma de piedra)
; y que	debajo de la plataforma	no haya	una puerta giratoria
; Tambien comprueba que	sobre el lugar del agujero no haya un cuchillo o una gema
;----------------------------------------------------

chkProtaPica:
		ld	hl, ProtaY
		call	chkPisaSuelo
		ret	nz		; El prota no esta sobre suelo firme

		dec	hl
		push	hl		; Apunta al sentido
		call	chkChocaAndar3
		pop	hl
		jr	nc, chkProtaPica2 ; No choca

		ld	a, (hl)		; Sentido
		xor	3		; Invierte el sentido
		ld	b, a		; Lo guarda en B para pasarselo	a la funcion
		push	hl
		call	chkChocaAndar4
		pop	hl
		jp	c, picaLateral	; Si esta atrapado en un agujero pica uno de los muros lateralmente

chkProtaPica2:
		ld	e, (hl)		; Sentido
		inc	hl
		ld	a, (hl)		; Y prota
		add	a, 10h		; Le suma el alto del prota
		ld	d, a		; Guarda en D la Y del suelo bajo los pies
		inc	hl
		inc	hl
		ld	a, (hl)		; X prota
		ld	bc, 10h		; Offset X: izquierda =	0, derecha = 16
		and	7
		cp	5		; Calcula la posicion relativa respecto	al tile
		jr	c, chkProtaPica3

	IF	(VERSION2)
		ld	b,#08
	ELSE
		ld	bc, 810h	; Offset: izquierda = 8, derecha = 16
	ENDIF
	
chkProtaPica3:
		ld	a, e		; Sentido
		rra
		ld	a, b		; Offset picando a la izquierda
		jr	c, chkProtaPica4
		ld	a, c		; Offset picando a la derecha

chkProtaPica4:
		add	a, (hl)		; Suma el desplazamiento a la X	del prota
		ld	e, a
		and	0F8h
		ret	z		; Demasiado pegado a la	izquierda

		cp	0F8h
		ret	z		; Demasiado pegado a la	derecha

		ld	hl, agujeroDat	; Y, X,	habitacion
		push	hl
		ld	(hl), d		; Y agujero
		inc	hl
		inc	hl
		ld	(hl), e		; X agujero
		inc	de
		inc	hl
		ld	a, (ProtaRoom)	; Parte	alta de	la coordenada X. Indica	la habitacion de la piramide
		ld	(hl), a		; Habitacion del agujero
		pop	hl
		call	getMapOffset00	; Obtiene en HL	el puntero al mapa de las coordenadas apuntada por HL
		and	0F0h		; Se queda con el tipo de tile
		cp	10h		; Es una plataforma, ladrillo o	muro?
		ret	nz		; No

		ld	a, (hl)
		and	0Fh		; Se queda con el tipo de ladrillo
		cp	4		; Es ladrillo de muro o	plataforma?

	IF	(VERSION2)
		jr	c,chkProtaPica4b
		cp	9		; Es un ladrillo de un muro trampa?
		ret	nz
	ELSE
		ret	nc		; No
	ENDIF
	
chkProtaPica4b:	
		ld	a, 60h		; Desplazamiento a una fila inferior
		call	ADD_A_HL
		ld	a, (hl)		; Tile del mapa	que esta por debajo del	anterior
		and	0F0h		; Tipo de tile
		cp	50h		; Es una puerta	giratoria?
		ret	z		; Si, aqui no se puede hacer un	agujero	(que nos cargamos la puerta!)


; Esta comprobacion evita que se haga un agujero debajo	de un cuchillo, pico o una gema

		ld	bc, -0C0h	; Desplazamiento 2 filas mas arriba. Justo un tile por encima del suelo
		add	hl, bc
		ld	a, (hl)		; Lee tile del mapa
		and	0F0h		; Esta vacio?
		jr	z, chkProtaPica5+1 ; (!?) Esto salta y ejecuta "JR NZ,#4ED1" Claro que nunca sera NZ si salta siendo Z

chkProtaPica5:
		cp	20h		; Es una escalera?
		ret	nz		; Si, se puede hacer un	agujero	a los pies de una escalera

		ld	hl, protaStatus	; Puntero al estado del	prota
		ld	(hl), 5		; Estado: Picando

		inc	hl
		inc	hl
		ld	a, (hl)		; Sentido del prota
		rra
		inc	hl
		inc	hl
		inc	hl
		ld	a, (hl)		; X
		jr	nc, chkProtaPica7 ; Mira a la derecha

		and	7		; Posicion relativa al tile
		cp	5		; Esta en los 4	pixeles	derechos del tile?
		ld	a, (hl)		; X
		jr	c, chkProtaPica6 ; No
		add	a, 4		; Pasa al siguiente tile
		and	0F8h		; Lo ajusta a la X del tile
		add	a, 2		; Le suma 2

chkProtaPica6:
		ld	(hl), a		; Actualiza la X del prota
		jr	setPicarStatus

; El prota esta	haciendo el agujero hacia la derecha

chkProtaPica7:
		and	7		; Posicion X relativa al tile
		sub	1
		cp	3		; Esta en la parte derecha o izquierda del tile?
		ld	a, (hl)
		jr	c, chkProtaPica8
		and	0FCh		; Ajusta la X del prota	a la X del tile

chkProtaPica8:
		ld	(hl), a		; Actualiza la X del prota

setPicarStatus:
		ld	a, 15h
		ld	(agujeroCnt), a	; Al comenzar a	pica vale #15
		ld	a, 5
		ld	(protaStatus), a ; Pone	estado de picando
		ret


;----------------------------------------------------
; Cuando el prota esta atrapado	entre dos muros	en vez de
; picar	en el suelo, pica en la	pared
;----------------------------------------------------

picaLateral:
		ld	de, agujeroDat	; Y, X,	habitacion
		inc	hl
		ld	a, (hl)		; Y del	prota
		ld	(de), a		; Y del	agujero
		inc	hl
		inc	de
		inc	de
		inc	hl
		ld	a, (sentidoProta) ; 1 =	Izquierda, 2 = Derecha
		rra
		ld	a, (hl)		; X del	prota
		jr	c, picaLateral2	; Va a pizar hacia la izquierda
		add	a, 10h		; Pica hacia la	derecha, asi que le suma a la X	el ancho del prota (16 pixeles)

picaLateral2:
		ld	(de), a		; X del	agujero
		and	0F8h
		ret	z		; Esta picando el muro izquierdo que delimita la habitacion

		cp	0F8h
		ret	z		; Esta intentando picar	el muro	derecho	que delimita la	habitacion

		inc	hl
		inc	de
		ld	a, (hl)		; Habitacion prota
		ld	(de), a		; Habitacion agujero
		call	setPicarStatus	; Pone al prota	en estado de picar

		ld	a, 2
		ld	(accionWaitCnt), a ; Contador usado para controlar la animacion	y duracion de la accion	(lanzar	cuchillo, cavar, pasar puerta giratoria)
		ld	hl, ProtaY
		call	getMapOffset00	; Obtiene en HL	el puntero al mapa de las coodenadas apuntada por HL

		ld	a, (sentidoProta) ; 1 =	Izquierda, 2 = Derecha
		rra
		jr	c, picaLateral3	; Izquierda

		inc	hl
		inc	hl		; Apunta al tile que esta a la derecha del prota

picaLateral3:
		ld	a, (hl)		; Tile del mapa
		and	0F0h
		cp	10h		; Es un	muro/plataforma?
		jr	z, picaLateral4	; Si


; Si a la altura de la cabeza del prota	no hay muro, comienza a	picar un tile mas abajo

		ld	hl, agujeroDat	; Y, X,	habitacion
		ld	a, (hl)
		add	a, 8
		ld	(hl), a		; Desplaza el orgigen del agujero un tile mas abajo
		ld	a, 9		; Como solo va a picar un tile la duracion es la mitad
		ld	(agujeroCnt), a	; Al comenzar a	pica vale #15

picaLateral4:
		ld	a, 45h		; SFX picar
		jp	setMusic


;----------------------------------------------------
; Status 6: Prota pasando por una puerta giratoria
;----------------------------------------------------

protaGiratoria:
		ld	a, (timer)
		and	1
		ret	nz		; Procesa uno de cada dos frames

		ld	hl, accionWaitCnt ; Contador usado para	controlar la animacion y duracion de la	accion (lanzar cuchillo, cavar,	pasar puerta giratoria)
		dec	(hl)		; Ha terminado de pasar	la puerta?
		jr	z, setProtaAndar ; si

		ld	hl, protaMovCnt	; Contador usado cada vez que se mueve el prota. (!?) No se usa	su valor
		inc	(hl)		; Incrementa contardor de movimiento y animacion
		jp	protaAnda4	; Mueve	y anima	al prota

setProtaAndar:
		ld	(protaStatus), a ; Pone	el estado 0 (andar) en el prota
		ret

;----------------------------------------------------
; Comprueba si el prota	esta incrustado	despues	de hacer un agujero con	el pico
; (Por si le baja un muro trampa?)
;----------------------------------------------------

chkIncrust:
		ld	hl, ProtaY
		ld	bc, 40Ch	; Offset X+4, Y+12
		call	chkIncrustUp
		ld	b, 4
		jr	nc, chkIncrust2

		ld	bc, 0B0Ch	; offset X+11, Y+12
		call	chkIncrustUp
		ret	c
		ld	b, 0

chkIncrust2:
		ld	hl, ProtaX
		ld	a, (hl)		; X prota
		add	a, b		; Le suma el desplazamiento
		and	0FCh		; Ajusta la coordenada X del prota a multiplo de 4
		ld	(hl), a		; Actualiza la X del prota
		ret
;----------------------------------------------------
;
; Carga	los graficos y sprites del juego y
; crea copias invertidas de algunos de ellos
;
;----------------------------------------------------

loadGameGfx:
		ld	hl, statusEntrada
		ld	de, lanzamFallido ; 1 =	El cuchillo se ha lanzado contra un muro y directamente	sale rebotando
		ld	bc, 500h
		xor	a
		ld	(hl), a
		ldir			; Borra	RAM

		ld	hl, 2200h	; Destino = Patron #40 de la tabla
		ld	de, GFX_InGame
		call	UnpackPatterns

		ld	hl, 228h	; Tabla	de colores de los patrones del juego
		ld	de, COLOR_InGame
		call	UnpackPatterns

		ld	hl, 2340h	; Origen = Patron #68 (Puerta)
		ld	de, 23B8h	; Destino = Patron #77
		ld	c, 0Fh		; Numero de patrones a invertir
		call	FlipPatrones	; Invierte algunos graficos como las escaleras y las puertas

		ld	de, COLOR_Flipped
		ld	hl, 3B8h
		call	UnpackPatterns	; Pone color a los patrones invertidos

		ld	b, 6		; Numero de gemas
		ld	hl, 2430h	; Destino = Patron #96 de la tabla (Gemas)

UnpackGema:
		ld	de, GFX_GEMA
		push	hl
		push	bc
		call	UnpackPatterns
		pop	bc
		pop	hl
		ld	de, 8
		add	hl, de
		djnz	UnpackGema


		ld	de, COLOR_GEMAS
		ld	hl, 430h
		call	UnpackPatterns

		ld	de, GFX_SPRITES2
		call	unpackGFXset

		ld	de, GFX_MOMIA
		call	unpackGFXset

		ld	hl, 1940h	; Datos	GFX momia (Sprite generatos table address)
		ld	de, 1C50h	; Direccion SGT	de la momia invertida
		ld	c, 3
		call	flipSprites

; Carga	los sprites que	corresponden al	estado del personaje
; Nada en las manos, llevando un cuchillo o llevando un	pico

loadAnimation:
		ld	a, (objetoCogido) ; #10	= Cuchillo, #20	= Pico
		rra
		rra
		rra
		and	1Eh
		ld	hl, IndexSprites
		call	getIndexHL_A
		ex	de, hl
		ld	hl, 1800h
		push	hl
		call	unpackGFXset
		pop	hl		; Recupera la direccion	de los sprites en VRAM
		ld	de, 1B10h	; Destino sprites invertidos (#60-#61)
		ld	c, 0Ah		; Numero de sprites a invertir
		jp	flipSprites



IndexSprites:	dw GFX_Prota
		dw GFX_ProtaKnife
		dw GFX_ProtaPico


		ld	hl, ProtaY	; (!?) Este codigo no se ejecuta nunca!

;----------------------------------------------------
; Comprueba si choca contra el suelo
; Out:
;   Z =	Ha chocado
;   C =	No ha chocado
;----------------------------------------------------

chkChocaSuelo:
		push	hl
		dec	hl
		ld	a, (hl)		; Sentido
		inc	hl
		ld	bc, 50Fh	; Parte	inferior izquierda
		rra
		jr	c, chkChocaSuelo2 ; Va hacia la	izquierda
		ld	b, 0Bh		; Parte	inferior derecha

chkChocaSuelo2:
		call	getMapOffset	; Obtiene en HL	la direccion del mapa que corresponde a	las coordenadas
		pop	hl
		and	0F0h		; Se queda con la familia de tiles
		cp	10h		; Es una plataforma?
		ret	z		; Si, ha chocado

		scf
		ret


;----------------------------------------------------
; Comprueba si hay suelo bajo los pies del prota
; Out:
;    Z = Hay suelo
;    C = No hay	suelo
;----------------------------------------------------

chkProtaCae:
		ld	hl, ProtaY

chkCae:	
		call	chkPisaSuelo
		ret	z		; Esta pisando suelo

		inc	hl
		inc	hl
		ld	a, (hl)		; X del	elemento
		and	7
		cp	4		; Se encuentra en los 4	primeros pixeles de un tile?
		ld	a, (hl)
		jr	nc, chkCae2	; Dependiendo del lado por el que se cae, mueve	el elemento 4 pixeles en esa direccion para separarlo de la plataforma

		add	a, 4		; Desplaza el elemento 4 pixeles a la derecha

chkCae2:
		and	0FCh		; Ajusta la X a	multiplo de 4
		ld	(hl), a		; Actualiza la X
		scf
		ret

;----------------------------------------------------
; Comprueba si el elemento actual esta pisando suelo
; Tanto	el prota como las momias tienen	una altura de 16
; por lo que sumando 17	a su altura se miran lo	que hay	justo
; debajo de sus	pies
; Out:
;   DE = Puntero al tile del mapa
;    Z = Choca
;----------------------------------------------------

chkPisaSuelo:
		ld	bc, 611h	; Coordenadas X	+ 6, Y + 17
		call	chkTocaMuro	; Z = choca
		ret	z		; Esta sobre una plataforma

		ld	bc, 0A11h	; X + 10, Y + 17

chkTocaMuro:
		push	hl		; Z = choca
		call	getMapOffset	; Obtiene en HL	la direccion del mapa que corresponde a	las coordenadas
		ex	de, hl
		pop	hl

		dec	hl
		dec	hl
		dec	hl

		ld	b, (hl)		; Status
		inc	hl
		inc	hl
		inc	hl
		and	0F0h		; Se queda con la familia a la que corresponde el tile del mapa
		ld	c, a
		cp	10h		; Plataformas
		ret	z		; Esta tocando una plataforma

		ld	a, b		; Status
		cp	2		; Cayendo?
		ld	a, c		; Recupera el tipo de tile que toca
		jr	z, noTocaMuro

		cp	50h		; Puerta giratoria
		ret

noTocaMuro:
		ld	a, c		; (!?) No hace falta
		dec	b		; Set NZ
		ret

getMapOffset00:
		push	de		; Obtiene en HL	el puntero al mapa de las coodenadas apuntada por HL
		push	bc
		ld	bc, 0
		call	getMapOffset	; Obtiene en HL	la direccion del mapa que corresponde a	las coordenadas
		pop	bc
		pop	de
		ret

;----------------------------------------------------
; Obtiene el tile del mapa que hay en la coordenadas a
; las que apunta HL.
;
; In:
;  HL =	Puntero	a coordenadas (Y, X decimales, X, Habitacion)
;   B =	Offset X (puede	tener valores negativos)
;   C =	Offset Y
; Out:
;  HL =	Puntero	a la posicion del mapa de esas coordenadas
;   A =	Patron del mapa	que hay	en esas	coordenadas
;----------------------------------------------------

getMapOffset:
		ld	a, (hl)		; Y
		add	a, c		; Le suma el desplazamiento Y para poder comprobar un punto determinado
					; del elemento distinto	de sus coordendas de origen
		rra
		rra
		rra
		and	1Fh		; Ajusta la coordenada Y a patrones (/8)

		ld	e, a
		ld	d, 0
		ex	de, hl
		add	hl, hl
		add	hl, hl
		add	hl, hl
		add	hl, hl
		add	hl, hl		; x32

		push	bc
		ld	b, h
		ld	c, l
		add	hl, hl
		add	hl, bc		; x96 (#60) Tres pantallas en horizontal
		pop	bc

		ex	de, hl		; DE = Desplazamiento en el mapa correspondiente a la Y	(Y * 96)
					; HL = Datos del elemento (coordenadas)
		inc	hl		; Decimales X
		inc	hl
		ld	a, (hl)		; X
		inc	hl
		ld	h, (hl)		; Pantalla (0-2)
		ld	l, a		; HL = Coordenada X global (Pantalla + X local)
		push	bc
		ld	c, b
		ld	b, 0
		bit	7, c		; Es negativo el offset	X?
		jr	z, getMapOff2	; No
		dec	b		; Convierte el valor en	negativo

getMapOff2:
		add	hl, bc		; Offset X
		ld	a, l
		pop	bc
		srl	h
		rra
		srl	h
		rra
		srl	h
		rra
		ld	l, a		; Divide HL entre 8 para ajustar a patrones
		add	hl, de		; Le suma el desplazamiento Y calculado	anteriormente
		ld	de, MapaRAMRoot	; La primera fila del mapa no se usa (ocupada por el marcador).	Tambien	usado como inicio de la	pila
		add	hl, de		; Calcula puntero a la posicion	de mapa
		ld	a, (hl)		; Lee el contenido actual de esas coordenadas
		ret

		scf			; (!?) Este codigo no se ejecuta nunca!
		ret

;----------------------------------------------------
; Comprueba si ha llegado al final de la escalera
; Out:
;   Z =	Ha llegado al final
;  NZ =	No ha llegado al final
;----------------------------------------------------

chkFinEscalera:
		ld	a, (hl)
		and	7
		ret	nz		; La Y no es multiplo de 8

		push	bc
		ld	bc, 810h	; Offset parte central abajo (8,16)
		call	getMapOffset	; Obtiene el tile que esta en los pies
		and	0F0h		; Se queda con la familia o tipo
		cp	10h		; Es una plataforma o incio de escalera?
		pop	bc
		ret	z		; Si

		and	a		; No
		ret

;----------------------------------------------------
; Comprueba si coge una	escalera
; Lo primero que se comprueba es si estan los controles	de ARRIBA o ABAJO pulsados
; Dependiendo de la posicion relativa X	respecto al tile del mapa se comprueba si sube a la derecha (0-3) o a la izquierda (4-7)
; Luego	se mira	el tile	que hay	en los pies del	personaje y se compara con el tipo de escalera anterior
; Out:
;    NZ	= No la	coge
;----------------------------------------------------

chkCogeEscalera:
		ld	hl, protaControl ; 1 = Arriba, 2 = Abajo, 4 = Izquierda, 8 = Derecha, #10 = Boton A, #20 =Boton	B

chkCogeEsc2:
		ld	a, (hl)		; Controles
		and	3		; Arriba o abajo?
		jr	z, noCogeEscalera ; No

		rra
		jr	nc, chkBajaEscalera ; Abajo

		inc	hl
		inc	hl
		inc	hl
		inc	hl
		ld	a, (hl)		; X
		and	7
		jr	z, noCogeEscalera ; No esta "dentro" del tile de escalera

		sub	5		; Dependiendo de la posicion relativa X	respecto al tile del mapa se compruba si sube a	la derecha (0-3) o a la	izquierda (4-7)
		ld	b, 22h		; Escaleras suben derecha
		jr	c, chkCogeEsc3
		dec	b		; Escaleras suben izquierda

chkCogeEsc3:
		dec	hl
		dec	hl		; Apunta a la Y
		push	hl
		call	getMapOffset00	; Obtiene en HL	el puntero al mapa de las coodenadas apuntada por HL
		ld	a, 61h		; 3 pantallas +	1 (tile	abajo a	la derecha = Piernas del elemento)
		call	ADD_A_HL

		ld	a, (hl)		; Tile del mapa	que esta en las	piernas	del elemento
		ld	c, a
		pop	hl		; Apunta a la Y
		cp	b		; Es una escalera?
		jr	z, chkSubeEsc2	; si

; Comprueba si hay un cuchillo sobre el	primer peldaño de la escalera

		push	af
		ld	a, b
		add	a, 10h		; B = #32 o #31? (tiles	cuchillo sobre escalera)
		ld	b, a
		pop	af
		cp	b
		jr	nz, noCogeEscalera

chkSubeEsc2:
		and	1
		xor	1
		ld	b, a		; 1 = Escaleras	a la derecha, 0	= A la izquierda

		ld	a, (modoSentEsc) ; Si es 0 guarda en "sentidoEscalera" el tipo de escalera que se coge el prota. 0 = \, 1 = /
		and	a
		jr	nz, chkSubeEsc3	; No guarda en sentidoEscalera el sentido de la	escalera

		ld	a, b
		ld	(sentidoEscalera), a ; 0 = \, 1	= /
					; Tambien usado	para saber si el salto fue en vertical (guarda el estado de las	teclas en el momento del salto.

chkSubeEsc3:
		inc	hl
		inc	hl
		ld	a, (hl)		; X
		dec	hl
		dec	hl		; Apunta a la Y
		ld	de, distPeldano
		and	7		; Se queda con la X relativa del personaje respecto al tile de la escalera
		call	ADD_A_DE
		ld	a, (de)		; Desplazamiento vertical
		add	a, (hl)		; Se lo	suma a la Y
		ld	(hl), a
		dec	hl
		dec	hl
		dec	hl
		ld	(hl), 3		; Status: subiendo o bajando escalera

		xor	a
		cp	0		; Set Z, NC
		ret

;----------------------------------------------------
; Tabla	con las	distancias al primer peldaño dependiendo
; de la	posicion del personaje respecto	al tile	del peldaño
;
;----------------------------------------------------
distPeldano:	db 0
		db -1
		db -2
		db -3
		db -4
		db -3
		db -2
		db -1

noCogeEscalera:
		xor	a
		dec	a
		ret


;----------------------------------------------------
; Comprueba si hay escaleras para bajar	bajo los pies del personaje
; Out:
;    NC/Z = Baja escaleras
;----------------------------------------------------

chkBajaEscalera:
		inc	hl
		inc	hl
		inc	hl
		inc	hl
		ld	a, (hl)		; X
		and	7
		cp	4
		jr	nz, noCogeEscalera ; No	esta justo en la mitad del tile	de la escalera

		dec	hl
		dec	hl
		push	hl		; Apunta a Y
		call	getMapOffset00	; Obtiene en HL	el puntero al mapa de las coodenadas apuntada por HL
		ld	a, 0C1h		; Fila de patrones por debajo del personaje, justo bajo	sus pies
					; #60 por fila * 2 (16 de altura) + 1 (8 pixeles) = justo bajo los pies
		call	ADD_A_HL
		ld	a, (hl)		; Tile del mapa	bajo los pies
		ld	c, a
		pop	hl
		cp	16h		; Tile incio de	escaleras que bajan a la derecha
		jr	z, chkBajaEsc2

		cp	17h		; Tile inicio de escaleras que bajan a la izquierda
		jr	nz, noCogeEscalera

chkBajaEsc2:
		ld	a, (modoSentEsc) ; Si es 0 guarda en "sentidoEscalera" el tipo de escalera que se coge el prota. 0 = \, 1 = /
		and	a
		jr	nz, chkBajaEsc3

		ld	a, c
		and	1		;  0 = \, 1 = /
		ld	(sentidoEscalera), a ; 0 = \, 1	= /
					; Tambien usado	para saber si el salto fue en vertical (guarda el estado de las	teclas en el momento del salto.

chkBajaEsc3:
		ld	a, (hl)		; Y
		add	a, 4
		ld	(hl), a		; Desplaza al personaje	4 pixeles hacia	abajo
		dec	hl
		dec	hl
		dec	hl
		ld	(hl), 3		; Estado: Escaleras
		xor	a
		cp	0		; Set Z, NC
		ret

;----------------------------------------------------
; Comprueba si choca contra un muro o puerta giratoria al andar
; No hace la comprobacion si no	se pulsad DERECHA o IZQUIERDA
; Si la	X del elemento es multiplo de 8	comprueba si choca contra una puerta giratoria
; Si la	X esta en los 4	pixeles	de la derecha del tile comprueba los muros
; Out:
;    Z = No choca
;    C = Choca
;----------------------------------------------------

chkChocaAndar:
		ld	hl, protaControl ; 1 = Arriba, 2 = Abajo, 4 = Izquierda, 8 = Derecha, #10 = Boton A, #20 =Boton	B

chkChocaAndar2:
		ld	a, (hl)
		and	1100b		; Esta pulsado DERECHA o IZQUIERDA?
		ret	z		; No

		inc	hl

chkChocaAndar3:
		ld	b, (hl)		; Sentido

chkChocaAndar4:
		inc	hl		; Y
		ld	d, h
		ld	e, l
		call	getMapOffset00	; Obtiene en HL	el puntero al mapa de las coodenadas apuntada por HL
		inc	de
		inc	de
		ld	a, (de)		; X
		and	7
		ld	c, 50h		; Puerta giratoria (tipo de tiles)
		jr	z, chkChocaAndar5 ; Es multiplo	de 8

		cp	4
		ld	c, 10h		; Plataformas (tipo de tiles)
		jr	nz, noChocaAndar

chkChocaAndar5:
		bit	0, b		; Sentido: 1 = Izquierda, 2 = derecha
		jr	nz, chkChocaAndar6 ; Va	a la izquierda

		inc	hl		; X tile mapa +	1
		and	a		; La coordenada	X del elemento es multiplo de 8
		jr	z, chkChocaAndar6

		inc	hl		; Incrementa en	1 la X del tile	del mapa a comprobar

chkChocaAndar6:
		ld	a, (hl)		; Tile del mapa
		and	0F0h		; Se queda con la familia o tipo de tile
		cp	c		; Es una puerta	giratoria o muro?
		jr	z, chocaAndar	; Choca

		ld	a, 60h		; Distancia al tile que	esta justo debajo (Y + 1)
		call	ADD_A_HL
		ld	a, (hl)		; Obtiene tile del mapa
		and	0F0h		; Se queda con el tipo de tile
		cp	c
		jr	nz, noChocaAndar ; No choca

chocaAndar:
		scf
		ret

noChocaAndar:
		and	a
		ret



;----------------------------------------------------
;
; Sprite prota sin nada	en las manos
;
;----------------------------------------------------
GFX_Prota:	db 0, 18h, 86h,	0, 1, 3, 0, 7, 8, 3, 0,	8Dh, 1,	2, 2, 1	; ...
		db 0, 0, 1, 0, 0C0h, 0E0h, 0, 0F0h, 8, 3, 0, 87h, 0C0h
		db 60h,	0, 0C0h, 0, 0, 0C0h, 3,	0, 8Ch,	3, 0, 3, 7, 3
		db 1, 0, 1, 1, 0, 1, 1,	4, 0, 93h, 0E0h, 0, 0F0h, 0E0h
		db 0F0h, 0C0h, 0, 80h, 0E0h, 0,	80h, 80h, 0, 0,	1, 3, 0
		db 7, 8, 3, 0, 3, 3, 2,	9, 3, 0, 85h, 0C0h, 0E0h, 0, 0F0h
		db 8, 3, 0, 87h, 0C0h, 0, 0C0h,	0C0h, 0, 0, 0E0h, 3, 0
		db 86h,	3, 0, 3, 7, 3, 1, 3, 0,	2, 6, 5, 0, 93h, 0E0h
		db 0, 0F0h, 0F0h, 0E0h,	0C0h, 0, 0E0h, 0, 0, 0C0h, 0C0h
		db 0, 0, 1, 3, 0, 7, 8,	3, 0, 2, 3, 2, 1, 89h, 0, 0Ch
		db 8, 0, 0C0h, 0E0h, 0,	0F0h, 8, 3, 0, 86h, 60h, 0C0h
		db 0C0h, 0C8h, 88h, 18h, 4, 0, 8Ch, 3, 0, 3, 7,	3, 1, 4
		db 0Ch,	4, 2, 7, 2, 4, 0, 8Bh, 0E0h, 0,	0F0h, 0F0h, 0E0h
		db 0C0h, 80h, 30h, 20h,	0, 70h,	1, 0, 0

;----------------------------------------------------
;
; Sprite prota con cuchillo
;
;----------------------------------------------------
GFX_ProtaKnife:	db 0, 18h, 86h,	0, 1, 3, 0, 7, 8, 3, 0,	8Ch, 1,	3, 3, 1	; ...
		db 0, 0, 1, 0, 0C0h, 0E4h, 0Ch,	0FCh, 4, 0Ch, 87h, 0D6h
		db 0F0h, 84h, 0CAh, 0, 0, 0C0h,	3, 0, 86h, 3, 0, 3, 7
		db 3, 1, 4, 0, 2, 1, 4,	0, 93h,	0E0h, 0, 0F0h, 0F0h, 0E0h
		db 0C0h, 8, 0Ch, 70h, 0, 80h, 80h, 0, 0, 1, 3, 0, 7, 8
		db 3, 0, 3, 3, 2, 9, 3,	0, 84h,	0C8h, 0D8h, 18h, 0F8h
		db 4, 18h, 87h,	7Ch, 0,	0D4h, 0C0h, 0, 0, 0E0h,	3, 0, 86h
		db 3, 0, 3, 7, 3, 1, 3,	0, 2, 6, 5, 0, 82h, 0E0h, 0, 3
		db 0E0h, 8Eh, 0C0h, 80h, 0F8h, 0, 0, 0C0h, 0C0h, 0, 0
		db 1, 3, 0, 7, 8, 3, 0,	2, 3, 2, 1, 92h, 0, 0Ch, 8, 0
		db 0C2h, 0E6h, 6, 0F6h,	0Eh, 6,	6, 0Fh,	60h, 0E5h, 0C0h
		db 0C8h, 88h, 18h, 4, 0, 8Ch, 3, 0, 3, 7, 3, 1,	4, 0Ch
		db 8, 2, 7, 2, 4, 0, 96h, 0E0h,	0, 0F0h, 0F0h, 0E0h, 0C0h
		db 9Eh,	18h, 0,	0, 70h,	0, 0, 0C0h, 0E1h, 77h, 30h, 3
		db 20h,	4, 2, 1, 3, 3, 3, 0, 91h, 0Eh, 0, 0C0h,	0E0h, 0
		db 0F0h, 88h, 50h, 20h,	0, 0E0h, 0C0h, 80h, 80h, 0, 0
		db 38h,	3, 0, 86h, 0Bh,	1Ch, 0Fh, 1Bh, 1Dh, 0Eh, 3, 0
		db 83h,	3, 7, 6, 4, 0, 8Ch, 0E0h, 0, 70h, 0A0h,	0C0h, 0E0h
		db 0, 0, 60h, 70h, 30h,	30h, 3,	0, 8Ah,	1, 3, 4, 8, 4
		db 0, 3, 2, 7, 3, 3, 0,	8Dh, 0Eh, 0, 0,	0C0h, 0E0h, 10h
		db 8, 10h, 20h,	40h, 0,	80h, 40h, 3, 0,	81h, 70h, 4, 0
		db 8Bh,	3, 7, 3, 1, 0, 1, 0, 4,	6, 6, 0Ch, 5, 0, 8Ch, 0E0h
		db 0F0h, 0E0h, 0C0h, 80h, 0E0h,	70h, 90h, 0E0h,	60h, 60h
		db 0, 0

;----------------------------------------------------
;
; Sprite prota con el pico
;
;----------------------------------------------------
GFX_ProtaPico:	db 0, 18h, 96h,	0, 1, 3, 0, 67h, 4, 18h, 0Ch, 6, 1, 3
		db 3, 1, 0, 0, 1, 0, 0C0h, 0E0h, 0, 0F0h, 8, 3,	0, 2, 0C0h
		db 8Fh,	80h, 0C0h, 0, 0, 0C0h, 0, 8, 10h, 3, 10h, 33h
		db 27h,	23h, 21h, 2, 3,	0, 2, 1, 4, 0, 96h, 0E0h, 0, 0F0h
		db 0F0h, 0E0h, 0C0h, 20h, 10h, 78h, 0, 80h, 80h, 0, 0
		db 1, 3, 0, 7, 60h, 20h, 8, 4, 3, 3, 2,	9, 3, 0, 85h, 0C0h
		db 0E0h, 0, 0F0h, 8, 3,	0, 95h,	0C0h, 0, 0C0h, 0C0h, 0
		db 0, 0E0h, 0, 0, 8, 1Bh, 10h, 13h, 17h, 63h, 41h, 40h
		db 0, 0, 6, 6, 5, 0, 97h, 0E0h,	0, 0F0h, 0F0h, 0E0h, 0C0h
		db 0, 0E0h, 0, 0, 0C0h,	0C0h, 0, 0, 1, 3, 0, 7,	48h, 80h
		db 18h,	0Eh, 3,	3, 1, 89h, 0, 0Ch, 8, 0, 0C0h, 0E0h, 0
		db 0F0h, 8, 3, 0, 86h, 60h, 0E8h, 0C0h,	0C8h, 88h, 18h
		db 3, 0, 8Dh, 10h, 33h,	20h, 23h, 67h, 0E3h, 81h, 84h
		db 8Ch,	8, 2, 7, 2, 4, 0, 8Bh, 0E0h, 0,	0F0h, 0F0h, 0E0h
		db 0C0h, 90h, 10h, 0, 0, 70h, 3, 0, 85h, 1, 3, 0, 7, 8
		db 3, 0, 3, 3, 3, 0, 91h, 0Eh, 0, 0, 0F0h, 10h,	0F0h, 10h
		db 10h,	0, 20h,	0A0h, 40h, 80h,	80h, 0,	0, 1Ch,	3, 0, 86h
		db 3, 0, 3, 0Fh, 7, 3, 3, 0, 93h, 3, 7,	6, 0, 10h, 0F8h
		db 4, 0E2h, 0, 0E0h, 0E0h, 0F0h, 0D0h, 40h, 80h, 60h, 60h
		db 30h,	18h, 3,	0, 9Eh,	1, 3, 4, 8, 4, 0, 3, 2,	7, 3, 0
		db 0, 8, 0Eh, 0, 0, 0C0h, 0E0h,	10h, 8,	10h, 20h, 80h
		db 40h,	0A0h, 50h, 18h,	8, 0, 60h, 4, 0, 8Bh, 3, 7, 3
		db 1, 0, 1, 0, 4, 6, 4,	4, 5, 0, 8Ch, 0E0h, 0F0h, 0E0h
		db 0C0h, 0, 80h, 40h, 0A2h, 0C2h, 42h, 46h, 0Ch, 0

;----------------------------------------------------
; Graficos de la momia
;----------------------------------------------------
GFX_MOMIA:	db 40h,	19h, 82h, 0, 3,	4, 7, 86h, 3, 3, 7, 4, 7, 7, 4
		db 3, 92h, 0, 0C0h, 0E0h, 40h, 0E0h, 0E0h, 0C0h, 80h, 0E0h
		db 80h,	60h, 80h, 80h, 0, 0, 80h, 0, 3,	4, 7, 8Eh, 3, 3
		db 7, 4, 7, 7, 1Fh, 1Eh, 11h, 1, 0, 0C0h, 0E0h,	40h, 3
		db 0E0h, 8Bh, 0C0h, 80h, 0E0h, 0B0h, 0C0h, 0C0h, 80h, 80h
		db 0C0h, 0, 3, 4, 7, 9Ah, 3, 3,	7, 6, 5, 1, 3, 7, 0Eh
		db 8, 0, 0C0h, 0E0h, 40h, 0E0h,	0, 0E0h, 0C0h, 0E0h, 78h
		db 48h,	0C0h, 0E8h, 0F8h, 18h, 0, 0

;----------------------------------------------------------------------------
;
; Sprites secundarios:
; Destello, muro, exploxion, cuchillo
;
;----------------------------------------------------------------------------
GFX_SPRITES2:	db 0A0h, 1Eh, 2, 0, 8Dh, 20h, 0, 8, 4, 0, 0, 0B0h, 0, 0	; ...
		db 4, 8, 0, 20h, 3, 0, 8Dh, 82h, 0, 88h, 90h, 0, 0, 0Dh
		db 0, 0, 90h, 88h, 0, 82h, 0Ah,	0, 2, 44h, 85h,	7Eh, 10h
		db 10h,	7Eh, 44h, 18h, 0, 8, 0FFh, 10h,	0, 8Fh,	44h, 7Eh
		db 10h,	10h, 7Eh, 44h, 44h, 7Eh, 10h, 10h, 7Eh,	44h, 44h
		db 7Eh,	10h, 11h, 0, 10h, 0FFh,	12h, 0,	8Ch, 1,	0Ah, 1Fh
		db 1Fh,	0Fh, 17h, 3Fh, 1Fh, 7, 0Fh, 0Bh, 6, 4, 0, 8Ch
		db 80h,	0E0h, 0F0h, 0F0h, 0E0h,	0F0h, 0E8h, 0F8h, 0F8h
		db 0D0h, 0F0h, 0C0h, 6,	0, 87h,	2, 7, 3, 5, 7, 3, 1, 9
		db 0, 86h, 0C0h, 0A0h, 0F0h, 0D0h, 0E0h, 0A0h, 6, 0, 87h
		db 0C0h, 0E0h, 74h, 38h, 1Ch, 2Eh, 4, 19h, 0, 87h, 3, 7
		db 2Eh,	1Ch, 38h, 74h, 20h, 19h, 0, 87h, 40h, 0E8h, 70h
		db 38h,	5Ch, 0Eh, 6, 19h, 0, 87h, 2, 17h, 0Eh, 1Ch, 3Ah
		db 70h,	60h, 19h, 0, 0

;----------------------------------------------------------------------------
;
; Graficos del juego (plataformas, escaleras, cuchillo,	gemas...)
;
;----------------------------------------------------------------------------
GFX_InGame:	db 3, 0FEh, 81h, 0, 3, 0EFh, 83h, 0, 0FFh, 0FFh, 6, 0
		db 3, 0FFh, 5, 0, 84h, 80h, 0C1h, 63h, 0, 3, 0F7h, 82h
		db 0, 81h, 4, 0, 89h, 0C1h, 0E3h, 0, 0C0h, 0E0h, 74h, 38h
		db 1Ch,	28h, 6,	0, 92h,	5, 3, 7, 2, 0, 0, 60h, 0E0h, 0C0h
		db 80h,	0, 80h,	50h, 0E0h, 70h,	0B8h, 1Ch, 0Ch,	4, 0, 8Ch
		db 1, 0, 1, 3, 7, 6, 0,	0, 40h,	0E0h, 0C0h, 0A0h, 3, 0
		db 84h,	24h, 18h, 18h, 7Eh, 3, 18h, 88h, 20h, 18h, 0Ch
		db 0Ch,	1Ah, 33h, 61h, 0C0h, 26h, 0, 0A2h, 49h,	2Ah, 2
		db 1, 4, 2, 0, 6, 0, 0,	40h, 80h, 20h, 40h, 0, 60h, 0
		db 0, 0FFh, 80h, 0EEh, 0EEh, 80h, 0BBh,	0BBh, 80h, 0FFh
		db 1, 0EFh, 0EFh, 1, 0BBh, 0BBh, 1, 30h, 0, 82h, 7Eh, 81h
		db 3, 18h, 2, 3Ch, 85h,	18h, 7Eh, 0E7h,	0C3h, 0C3h, 3
		db 0E7h, 83h, 0FFh, 81h, 7Eh, 6, 0, 5, 0F0h, 83h, 0B0h
		db 10h,	0D0h, 4, 0Fh, 2, 0Eh, 84h, 8, 0Bh, 70h,	70h, 6
		db 0F0h, 8, 0Fh, 81h, 0FFh, 4, 0, 87h, 0FCh, 0F0h, 0C0h
		db 0FFh, 0FCh, 0F0h, 0C0h, 8, 0, 2, 1, 2, 0Fh, 2, 0, 3
		db 1Fh,	8Dh, 0FFh, 0, 0, 0FFh, 0, 0FFh,	0, 0, 0FFh, 0
		db 0, 0Ah, 0Ah,	4, 0Eh,	2, 0Ah,	2, 0E0h, 4, 0A0h, 2, 0E0h
		db 8, 3Fh, 8, 70h, 0B0h, 0FFh, 0DDh, 0DDh, 81h,	0F7h, 0F7h
		db 81h,	0DDh, 0DDh, 81h, 0F7h, 0F7h, 81h, 0DDh,	0DDh, 81h
		db 0F7h, 0F7h, 81h, 0DDh, 0DDh,	81h, 0F7h, 0FFh, 0Fh, 0Dh
		db 0Dh,	8, 0Fh,	0Fh, 8,	0Dh, 0Dh, 8, 0Fh, 0Fh, 8, 0Dh
		db 0Dh,	8, 0D0h, 10h, 70h, 70h,	10h, 0D0h, 0D0h, 10h, 3
		db 0Fh,	9Dh, 8,	0Dh, 0Dh, 8, 0Fh, 0F9h,	3, 0, 6Eh, 2Eh
		db 0, 0Eh, 6, 0F9h, 3, 0, 0F0h,	0, 0E0h, 0E0h, 0EFh, 0
		db 0EEh, 6Eh, 2Eh, 0, 0Eh, 6, 2, 3, 0, 85h, 0F0h, 0, 0E0h
		db 0E0h, 0EFh, 0


GFX_GEMA:	db 88h,	0, 3Ch,	7Eh, 0BFh, 9Fh,	0DFh, 7Eh, 3Ch,	0
;----------------------------------------------------
;
; Colores de los patrones del juego
;
;----------------------------------------------------
COLOR_InGame:	db 3, 0F0h, 5, 0A0h, 5,	0F0h, 3, 0A0h, 7, 0F0h,	4, 0A0h	; ...
		db 5, 0F0h, 5, 0A0h, 3,	0F0h, 5, 0A0h, 3, 0F0h,	5, 0A0h
		db 3, 0F0h, 4, 90h, 4, 60h, 20h, 0, 18h, 0A0h, 40h, 50h
		db 82h,	90h, 96h, 3, 0F6h, 3, 0A6h, 81h, 60h, 3, 6Ah, 4
		db 6Fh,	81h, 96h, 7, 90h, 81h, 3Eh, 4, 3Ah, 3, 30h, 81h
		db 3Eh,	3, 3Ah,	6, 30h,	8Eh, 3Eh, 3Fh, 3Fh, 3Eh, 3Fh, 3Fh
		db 3Eh,	3Fh, 3Eh, 3Fh, 3Fh, 3Eh, 3Fh, 3Fh, 5, 0EAh, 3
		db 0A0h, 81h, 0EAh, 7, 0A0h, 5,	0F0h, 83h, 0E0h, 0F0h
		db 0E0h, 3, 0F0h, 2, 0E0h, 0Bh,	0FEh
;----------------------------------------------------
; Colores de los patrones invertidos (el mismo que los normales)
;----------------------------------------------------
COLOR_Flipped:	db 8, 50h, 8, 0F0h, 8, 50h, 8, 0F0h, 38h, 30h, 82h, 0EAh
		db 0F9h, 6, 0F0h, 82h, 0EAh, 0EFh, 16h,	0F0h, 0

COLOR_GEMAS:	db 8, 40h, 8, 70h, 8, 0D0h, 8, 0A0h, 8,	20h, 8,	0E0h, 0	; ...

;--------------------------------------------------------------------------------------------------------
;
; Logica de los	cuchillos
;
;--------------------------------------------------------------------------------------------------------

AI_Cuchillos:
		xor	a
		ld	(knifeEnProceso), a

AI_Cuchillos2:
		ld	hl, chkLastKnife
		push	hl		; Mete en la pila la rutina que	comprueba si se	han procesado todos los	cuchillos

		xor	a		; Offset al status del cuchillo
		call	getKnifeData	; Obtiene el indice del	cuchillo que se	esta procesando
		call	jumpIndex

		dw initCuchillo		; 0 - Inicializacion del cuchillo. Guarda tile de fondo
		dw doNothing_		; 1 - Posado en	el suelo
		dw doNothing_		; 2 - Lo lleva el prota	en la mano
		dw doNothing_
		dw lanzaCuchillo	; 4 - Lanza un cuchillo
		dw movKnife		; 5 - Cuchillo por el aire
		dw knifeChoca		; 6 - Acaba de chocar el cuchillo
		dw knifeRebota		; 7 - Esta rebotando
		dw knifeCae		; 8 - Esta cayendo
	IF	(!VERSION2)
		dw updateKnifeAtt	; 9 - Actualiza	los atributos RAM del sprite del cuchillo
	ENDIF


;----------------------------------------------------
; Knife	Status 0: Comprueba el tile que	tiene de fondo y lo guarda
; Si esta sobre	un peldaño de escalera lo cambia por un	tile de	cuchillo especial que indica que hay escalera detras
; Pasa al siguiente estado (1)
;----------------------------------------------------

initCuchillo:
		xor	a
		call	getKnifeData	; Obtiene puntero a los	datos del cuchillo
		inc	(hl)		; Lo pasa al status 1
		inc	hl
		inc	hl		; Apunta a la Y	del cuchillo
		call	getMapOffset00	; Obtiene el tile del mapa sobre el que	esta el	cuchillo
		ex	de, hl
		ld	a, 0Ah		; Offset tile backup
		call	getKnifeData
		ld	a, (de)		; Tile que hay en el mapa RAM
		ld	b, a
		and	0F0h
		cp	30h		; Comprueba si se trata	de un cuchillo
		jr	z, initCuchillo2
		ld	(hl), b		; Guarda el tile que hay detras	del cuchillo

initCuchillo2:
		ld	a, b
	IF	(VERSION2)
		sub	#31		; Cuchillo sobre peldaño?
		cp	2		; Dos posibles direcciones de las escaleras (cuchillo sobre peldaño hacia la derecha y sobre peldaño a la izquierda)
		ld	a,b
		jr	c,initCuchillo5
		
		ld	a,b		; (!?) No hace falta ponerlo! A ya es igual a B
		sub	#21		; Peldaño de escalera que sube a la izquierda
		cp	2		; Comprueba los dos tipos de peldaño (derecha e izquierda)
		jr	nc,initCuchillo4
		
		ld	a,b
	ELSE
		cp	31h		; Cuchillo sobre peldaño?
		jr	z, initCuchillo6

		cp	21h		; Peldaño escalera que sube a la izquierda
		jr	z, initCuchillo3

		cp	22h		; Peldaño escalera que sube a la derecha
		jr	nz, initCuchillo4
	ENDIF
initCuchillo3:
		add	a, 10h		; Convierte el tile de cuchillo	en "cuchillo sobre peldaño"
		jr	initCuchillo5

initCuchillo4:
		ld	a, 30h		; ID tile cuchillo suelo

initCuchillo5:
		ld	(de), a		; Actualiza el mapa RAM
		xor	a
		call	getKnifeData
		ld	a, 4Bh		; Patron de cuchillo posado
		jp	drawTile

	IF	(!VERSION2)
initCuchillo6:
		ld	a, 31h
		jr	initCuchillo5
	ENDIF

doNothing_:
		ret

;--------------------------------------------------------------------------------------------------------
;
; Lanza	un cuchillo
; Reproduce sonido de lanzar
; Coloca el cuchillo en	las coordendas del prota
; Guarda los tiles del mapa sobre los que se pinta
;
;--------------------------------------------------------------------------------------------------------

lanzaCuchillo:
		ld	a, 6
		call	setMusic	; Sonido lanzar

		ld	a, 6
		call	getKnifeData	; Obtiene puntero a la velocidad decimal
		ex	de, hl
		ld	hl, knifeDataInicio
		ld	bc, 0Bh
		ldir			; Inicializa los valores de este cuchillo

		call	knifeNextStatus	; Pasa al siguiente estado
		inc	hl
		ld	de, sentidoProta ; 1 = Izquierda, 2 = Derecha
		ex	de, hl
		ld	a, (hl)		; Sentido del lanzamiento
		ld	bc, 5
		ldir			; Copia	el sentido y coordenadas del prota

		dec	de
		dec	de		; Cuchillo X
		dec	hl
		dec	hl		; Prota	X
		ld	b, 8		; Desplazamiento X cuando se lanza a la	derecha
		rr	a		; 1 = Izquierda, 2 = Derecha
		jr	nc, lanzaCuchillo2
		ld	b, 0		; Desplazamiento cuando	se lanza a la izquierda

lanzaCuchillo2:
		ld	a, (hl)
		add	a, b		; Suma desplazamiento a	la X
		and	0F8h		; Lo ajusta a patrones (multiplo de 8)
		set	2, a		; Le suma 4
		ld	(de), a		; Actualiza X del cuchillo
		dec	de
		dec	de		; Y cuchillo
		ex	de, hl		; HL apunta a las coordenadas del cuchillo
		call	getMapOffset00	; Obtiene en HL	el puntero al mapa de las coodenadas apuntada por HL
		ex	de, hl
		ld	a, 0Ah		; Offset backup	fondo
		call	getKnifeData
		ex	de, hl
		ldi
		ldi			; Guarda tiles del mapa	sobre los que se pinta el cuchillo
		ret

;----------------------------------------------------
; Obtiene el frame del cuchillo	segun su posicion X en pantalla
;----------------------------------------------------

getFrameKnife:
		ld	a, 4		; Offset X cuchillo
		call	getKnifeData
		rra
		rra
		and	3		; Cambia el frame cada cuatro pixeles
		ld	de, framesCuchillo
		call	ADD_A_DE
		ld	a, (de)
		ret


;----------------------------------------------------
; Patrones usados para pintar el cuchillo
;----------------------------------------------------
framesCuchillo:	db 45h
					; Girando NO
		db 46h			; Girando NE
		db 48h			; Girando SE
		db 49h			; Girando SO
		db 4Bh			; Clavado en el	suelo

;--------------------------------------------------------------------------------------------------------
; Mueve	al cuchillo lanzado
; Comprueba si choca contra una	puerta giratoria
; Copia	y restaura el fondo sobre el que va pasando
;--------------------------------------------------------------------------------------------------------

movKnife:
		ld	a, 6		; Offset velocidad cuchillo
		call	getKnifeData
		ld	e, (hl)
		inc	hl
		ld	d, (hl)		; DE = velocidad del cuchillo
		ld	a, 3		; Offset X decimales
		call	getKnifeData
		call	mueveElemento	; Actualiza coordenadas	del cuchillo segun su velocidad

		ld	a, d		; X cuchillo
		and	3
		ret	nz		; No es	multiplo de 4

		ld	a, d
		and	7
		jr	z, movKnife3	; Es multiplo de 8

; Multiplo de 4

		ld	a, d
		cp	8
		ret	c		; Menor	de 8. Pegado al	limite izquierdo de la pantalla

		cp	252
		ret	nc		; Mayor	o igual	a 252. Pegado al limite	derecho	de la pantalla

		call	getFrameKnife	; Obtiene frame	actual de la animacion del cuchillo
		dec	hl
		dec	hl
		dec	hl
		dec	hl
		call	drawTile	; Dibuja primer	tile del cuchillo

	IF	(VERSION2)
		jr	nz,movKnife1	; Si no esta en pantalla no lo pinta
	ENDIF
	
		inc	a
		inc	hl
		call	WRTVRM		; segundo tile del cuchillo
movKnife1:
		ld	a, 1		; Offset sentido
		call	getKnifeData
		push	hl		; Apunta al sentido
		ld	a, (hl)		; Sentido
		inc	hl		; Apunta a la Y
		push	af
		call	getMapOffset00	; Obtiene un puntero HL	a la posicion del cuchillo en el mapa RAM
		pop	af
		rra
		jr	c, movKnife2	; Izquierda
		inc	hl		; Tile de la derecha

; Restaura una puerta giratoria	si el cuchillo choca contra ella

movKnife2:
		ld	a, (hl)		; Tile del mapa
		and	0F0h		; Se queda con la familia o tipo de tile
		cp	50h		; Puerta giratoria
		pop	hl		; Apunta al sentido
		ret	nz		; No ha	chocado	con una	puerta

		dec	hl		; Apunta al estado
		inc	(hl)		; Pasa al siguiente estado del cuchillo	(5)
		push	hl
		ld	a, 0Ah		; Offset tile de fondo
		call	getKnifeData
		ex	de, hl
		pop	hl
		push	de
		call	getTileFromID
		call	drawTile	; Restaura el tile de fondo 1
		pop	de
		ret	nz		; No esta en la	pantalla actual

		inc	hl		; Siguiente posicion VRAM (ocupa dos tiles)
		inc	de		; Siguiente tile backup	del cuchillo
		ld	a, (de)
		call	getTileFromID	; Identifica tile que le corresponde
		jp	WRTVRM		; Lo pinta

; Multiplo de 8

movKnife3:
		ld	a, 1		;  Offset sentido
		call	getKnifeData
		push	hl
		pop	ix

		call	getFrameKnife	; Frame	que le corresponde al cuchillo
		ld	b, a

		xor	a
		call	getKnifeData	; Puntero a los	datos del cuchillo

		ld	a, b		; Frame	del cuchillo
		call	drawTile

		ld	a, 2		; Offset Y
		call	getKnifeData
		call	getMapOffset00	; Obtiene en HL	el puntero al mapa de las coodenadas apuntada por HL

		ld	a, (ix+0)	; Sentido
		inc	hl		; Tile de la derecha del cuchillo
		rr	a
		push	af
		jr	nc, movKnife4	; Derecha
		dec	hl
		dec	hl		; Tile de la izquierda

movKnife4:
		pop	af
		ld	a, (hl)		; Tile del mapa	de fondo
		jr	nc, movKnife5	; Derecha

		ld	d, (ix+0Ah)	; tile de fondo	2
		ld	c, (ix+9)	; tile de fondo	1
		ld	(ix+0Ah), c
		ld	(ix+9),	a	; Actualiza la copia de	los tiles de fondo
		jr	movKnife6

movKnife5:
		ld	d, (ix+9)	; Tile backup 1
		ld	c, (ix+0Ah)	; Tile backup 2
		ld	(ix+9),	c
		ld	(ix+0Ah), a	; Actualiza la copia de	los tiles de fondo

movKnife6:
		ld	b, (ix+4)	; Pantalla en la que esta el cuchillo (xHigh)
		ld	a, (ProtaRoom)	; Pantalla del prota
		cp	b
		jr	nz, movKnife8	; No estan en la misma,	no hace	falta pintarlo

		ld	a, d		; Tile de fondo	a restaurar
		call	getTileFromID
		push	af
		ld	a, 2		; Offset Y
		call	getKnifeData
		ld	d, (hl)		; Y
		inc	hl
		inc	hl		; X
		ld	e, (hl)		; DE = YX
		call	coordVRAM_DE	; Obtiene puntero a la VRAM correspondiente a las coordenadas del cuchillo

		dec	hl		; Puntero VRAM
		ld	a, (ix+0)	; Sentido
		rra
		jr	nc, movKnife7	; Derecha
		inc	hl
		inc	hl

movKnife7:
		pop	af
		call	WRTVRM		; Restaura fondo

movKnife8:
		push	ix
		push	de
		call	chkKnifeMomia	; Comprueba si choca con una momia
		pop	de
		pop	ix
		jr	nc, movKnife9	;  No ha chocado contra	una momia

		xor	a
		call	getKnifeData
		jr	movKnife11

movKnife9:
		ld	a, 2		; Y
		call	getKnifeData
		push	hl
		call	getMapOffset00	; Obtiene en HL	el puntero al mapa de las coodenadas apuntada por HL
		dec	hl
		ld	a, (ix+0)	; Sentido
		rra
		jr	c, movKnife10	; Izquierda
		inc	hl
		inc	hl

movKnife10:
		ld	a, (hl)
		ld	b, a
		pop	hl		; Y
		call	chkKnifeChoca	; Comprueba si el tile es una plataforma, cuchillo, pico o gema
		jr	nz, knifeNoChoca ; No choca contra nada

		ld	a, b
		cp	40h		; Gemas
		jr	z, knifeNoChoca	; Contra las gemas no choca el cuchillo

		dec	hl
		dec	hl		; Apunta al status

movKnife11:
		inc	(hl)		; Pasa al siguiente estado del cuchillo: choca
		inc	hl
		ld	b, (hl)		; Sentido
		inc	hl
		inc	hl
		inc	hl

movKnife12:
		inc	hl
		ld	a, (ProtaRoom)	; Parte	alta de	la coordenada X. Indica	la habitacion de la piramide
		cp	(hl)		; esta en la misma pantalla el cuchillo	y el prota?
		ret	nz		; No esta en la	pantalla actual. No se ve

		ld	a, 5
		call	ADD_A_HL	; Puntero a los	tiles de backup	de fondo
		rr	b		; Sentido
		jr	nc, knifeRestaura ; Derecha
		inc	hl

knifeRestaura:
		ld	a, (hl)		; Backup tile
		call	getTileFromID	; Obtiene patron que le	corresponde
		call	coordVRAM_DE	; D = Y, E = X
		jp	WRTVRM		; Pinta	el patron en pantalla

knifeNoChoca:
		dec	hl
		ld	b, (hl)
		inc	hl
		inc	hl
		inc	hl
		xor	a
		cp	(hl)
		jr	z, movKnife12
		ld	a, 0F8h
		cp	(hl)
		jr	z, movKnife12
		ret

;----------------------------------------------------
;
; Cuchillo choca
; Pasa al estado de rebotando, invierte	el sentido y lo	mueve 4	pixeles	hacia atras
;----------------------------------------------------

knifeChoca:
		call	knifeNextStatus	; Pasa al estado de rebotando
		inc	hl
		ld	a, (hl)
		xor	3
		ld	(hl), a		; Invierte el sentido
		inc	hl
		inc	hl
		inc	hl
		rra
		ld	a, (hl)		; X
		jr	c, knifeChoca2	; Izquierda
		add	a, 4

knifeChoca2:
		and	0F8h
		ld	(hl), a
		ld	a, 5
		call	ADD_A_HL
		ld	(hl), 0
		ret

;----------------------------------------------------
;
; Cuchillo rebotando
; Realiza una parabola que simula un rebote.
; Comprueba si choca contra algo mientras rebota.
; Al terminar pasa al siguiente	estado:	caer
;----------------------------------------------------

knifeRebota:
		ld	a, (timer)
		and	3
		jp	nz, updateKnifeAtt ; Actualiza las coordenadas 1 de cada 4 frames. El resto los	atributos del sprite

		ld	a, 1		; Offset sentido
		call	getKnifeData
		push	hl
		ld	a, (hl)		; Sentido
		inc	hl
		inc	hl
		inc	hl
		inc	(hl)		; Incrementa la	X
		rra
		jr	nc, knifeRebota2 ; Derecha

		dec	(hl)
		dec	(hl)		; Decrementa la	X (rebota hacia	la izquierda)

knifeRebota2:
		pop	hl
		call	chkPasaRoom	; Comprueba si pasa a otra habitacion

		ld	a, 9
		call	getKnifeData
		ld	a, (hl)		; Contador de movimiento

		ld	hl, parabolaKnife
		call	ADD_A_HL
		ld	b, (hl)		; Desplazamiento Y del rebote para simular una parabola

		ld	a, 2		; Y
		call	getKnifeData
		ld	a, (hl)		; Y del	cuchillo
		add	a, b		; Le suma el desplazamiento de la parabola
		ld	(hl), a		; Actualiza la Y del cuchillo

		push	hl
		ld	bc, 408h	; Offset X+4, Y+8
		call	getMapOffset	; Lee tile del mapa
		ld	a, (hl)		; Obtiene el tile que hay justo	debajo del cuchillo
		call	chkKnifeChoca	; Comprueba si el tile es una plataforma, cuchillo, pico o gema
		pop	hl
		jr	nz, knifeRebota3 ; No choca con	nada

		ld	a, b		; Tile del mapa
		cp	41h		; Brillo gema izquierda
		jr	z, knifeRebota3

		cp	42h		; Brillo gema derecha
		jr	z, knifeRebota3

		and	0F0h
		cp	10h		; Es una plataforma, muro o ladrillo?
		jr	nz, setReboteKnife ; Da	otro rebote para no caer sobre el objeto

		jr	knifeEnd

knifeRebota3:
		ld	a, 7
		call	ADD_A_HL
		inc	(hl)		; Incrementa contador de movimiento

		ld	a, (hl)
		cp	8		; Ha terminado la parabola del rebote? (8 frames)
		jp	z, knifeNextStatus ; Si, pasa a	estado de caer
		jp	updateKnifeAtt


;----------------------------------------------------
; Valores de la	parabola del rebote del	cuchillo
;----------------------------------------------------
parabolaKnife:	db -5
		db -2
		db -1
		db 0
		db 0
		db 1
		db 2
		db 5

;----------------------------------------------------
; Status cuchillo = Caer
;----------------------------------------------------

knifeCae:
		ld	a, (timer)
		and	3
		jp	nz, updateKnifeAtt ; Actualiza las coordenadas 1 de cada 4 frames

		ld	a, 2		; Offset Y
		call	getKnifeData
		ld	a, (hl)		; Y del	cuchillo
		and	0FCh		; Lo ajusta a multiplo de 4
		ld	(hl), a

		ld	d, (hl)		; (!?) Por que no hace un LD D,A
		ld	a, d
		and	3		; (!?) Si acaba	de hacer un AND	#FC como va a haber un NZ con un AND 3?
		jp	nz, caeKnife4

		call	getMapOffset00	; Obtiene en HL	el puntero al mapa de las coodenadas apuntada por HL
		ld	a, 60h		; Offset al tile que esta debajo del cuchillo
		call	ADD_A_HL
		ld	a, (hl)		; Tile del mapa	bajo el	cuchillo
		call	chkKnifeChoca	; Comprueba si el tile es una plataforma, cuchillo, pico o gema
		jp	nz, caeKnife4	; No choca con nada

		ld	a, b
		cp	41h		; Brillo izquierdo
		jp	z, caeKnife4

		cp	42h		; Brillo derecho
		jp	z, caeKnife4	; Si cae sobre los brillos no pasa nada

		and	0F0h
		cp	10h		; Es ladrillo?
		jr	nz, setReboteKnife ; Rebota si cae sobre un obstaculo que no es	un brillo o ladrillo

knifeEnd:
		call	hideKnifeSpr
		xor	a
		call	getKnifeData
	
	IF	(VERSION2)
		jr	setReboteKnife2	; Apaño para ahorrar un byte
	ELSE
		ld	(hl), 0
		ret
	ENDIF
;----------------------------------------------------
; Reinicia el rebote del cuchillo
;----------------------------------------------------

setReboteKnife:
		xor	a
		call	getKnifeData
		ld	(hl), 7		; Status 7 = Rebote
		ld	a, 9
		call	ADD_A_HL
setReboteKnife2:
		ld	(hl), 0		; Contador de movimiento/rebote	= 0
		ret

;----------------------------------------------------
; Le suma 4 a la Y del cuchillo	y lo ajusta a multiplo de 4
;----------------------------------------------------

caeKnife4:
		ld	a, 2		; Y
		call	getKnifeData
	
	IF	(VERSION2)
		ld	a,(hl)
		add	a,4
	ELSE	
		inc	(hl)
		inc	(hl)
		inc	(hl)
		inc	(hl)		; Y+4
		ld	a, (hl)
	ENDIF
		and	0FCh
		ld	(hl), a
		jp	updateKnifeAtt

;----------------------------------------------------
; Comprueba si el tile es una plataforma, gema,	cuchillo o gema
; Out:
;   Z =	Si es uno de esos elementos
;   B =	Tile de	entrada
;----------------------------------------------------

chkKnifeChoca:
		ld	b, a		; Comprueba si el tile es una plataforma, cuchillo, pico o gema
		and	0F0h
		cp	10h		; Plataformas
		ret	z

		cp	30h		; Cuchillo
		ret	z

		cp	80h		; Pico
		ret	z

		cp	40h		; Gemas
		ret


;----------------------------------------------------
; Actualiza los	atributos RAM del sprite del cuchillo
;----------------------------------------------------

updateKnifeAtt:
		ld	a, 5		; Offset pantalla en la	que esta el cuchillo
		call	getKnifeData
		ld	a, (ProtaRoom)	; Parte	alta de	la coordenada X. Indica	la habitacion de la piramide
		cp	(hl)
		jr	nz, hideKnifeSpr ; No esta en la pantalla actual, asi que lo oculta

		dec	hl
		dec	hl
		dec	hl		; Y
		push	hl
		call	getKnifeAttib
		ex	de, hl
		pop	hl
		ld	a, (hl)		; Y
		ld	(de), a		; Atributo Y
		inc	hl
		inc	hl
		ld	a, (hl)		; X
		inc	de
		ld	(de), a		; Atributo X
		inc	de
		ld	a, (timer)
		and	0Ch		; Se queda con 4 sprites de 16x16 (0, 4, 8, 12)
		add	a, 0F0h		; Primer sprite	del cuchillo
		ex	de, hl
		ld	(hl), a		; Sprite del cuchillo
		inc	hl
		ld	(hl), 0Fh	; Color	blanco
		ret

;----------------------------------------------------
; Comprueba si se han procesado	todos los cuchillos
;----------------------------------------------------

chkLastKnife:
		ld	hl, knifeEnProceso
		inc	(hl)
		ld	a, (hl)
		inc	hl
		cp	(hl)
		jp	nz, AI_Cuchillos2
		ret

;----------------------------------------------------
; Quita	al cuchillo del	area visible
;----------------------------------------------------

hideKnifeSpr:
		call	getKnifeAttib
		ld	(hl), 0E0h
		ret


;----------------------------------------------------
; Pasa el cuchillo al siguiente	estado
;----------------------------------------------------

knifeNextStatus:
		xor	a
		call	getKnifeData
		inc	(hl)
		ret


;----------------------------------------------------
; Obtiene puntero a los	datos del cuchillo actual
; In: A	= Offset a la variable de la estructura
; Out:
;   HL = Puntero a los datos del cuchillo (variable indicada en	A)
;    A = Valor de la variable
;----------------------------------------------------

getKnifeData:
		push	bc
		ld	hl, knifesData	; 0 = Status (1	= suelo, 2 = Cogido, 4 = Lanzamiento?, 5= lanzado, 7 =Rebotando)
					; 1 = Sentido (1 = izquierda, 2	= Derecha)
					; 2 = Y
					; 3 = X	decimales
					; 4 = X
					; 5 = Habitacion
					; 6 = Velocidad	decimales
					; 7 = Velocidad	cuchillo
					; 8 = Velocidad	cambio habitacion
					; 9 = Contador movimiento
					; A = Tile backup 1 (fondo)
					; B = Tile backup 2 (guarda dos	tiles al lanzarlo)
		call	ADD_A_HL
		ld	a, (knifeEnProceso)
		ld	b, a
		add	a, a
		call	getIndexX8_masB
		pop	bc
		ret


;----------------------------------------------------
; Calcula la direccion de la tabla de nombres a	la que apunta DE
; In:
;   D =	Y
;   E =	X
; Out:
;   HL = Puntero VRAM
;----------------------------------------------------

coordVRAM_DE:
		push	af		; D = Y, E = X
		ld	h, d
		ld	l, e
		ld	a, h
		rra
		rra
		rra
		rra
		rr	l
		rra
		rr	l
		rra
		rr	l
		and	3
		add	a, 38h		; Tabla	de nombre en #3800
		ld	h, a
		pop	af
		ret


;----------------------------------------------------
; Obtiene un puntero a los atributos del cuchillo en proceso
;----------------------------------------------------

getKnifeAttib:
		ld	a, (knifeEnProceso)
		ld	hl, knifeAttrib
		jp	getMomiaAtrib2



;----------------------------------------------------
;
; Comprueba si el cuchillo choca contra	una momia
; Out:
;   NC,	Z = No ha chocado
;   C =	Ha chocado
;----------------------------------------------------

chkKnifeMomia:
		ld	c, 0		; Primera momia	a procesar = 0

chkKnifeMomia2:
		ld	a, c		; Momia	a procesar
		call	getMomiaDat

		ld	a, (ix+ACTOR_STATUS) ; Status de la momia
		cp	4		; Esta en el limbo, apareciendo	o explotando?
		jr	c, chkKnifeMomia3

		cp	7		; Esta pensando?
		jr	nz, chkKnifeMomia4 ; Esta en un	estado que no hay que comprobar	la colision

chkKnifeMomia3:
		ld	a, 2		; Offset Y
		call	getKnifeData
		ld	d, (hl)		; Y
		inc	hl
		inc	hl
		ld	e, (hl)		; X
		inc	hl
		ld	a, (hl)		; habitacion
		cp	(ix+ACTOR_ROOM)
		jr	nz, chkKnifeMomia4 ; No	estan en la misma habitacion

		push	bc
		ld	c, (ix+ACTOR_Y)	; Y momia
		ld	b, (ix+ACTOR_X)	; X momia
		ld	hl, areaSizeMomia
		call	chkArea
		pop	bc
		jr	c, chkKnifeMomia5

chkKnifeMomia4:
		inc	c
		ld	hl, numMomias
		ld	a, c
		cp	(hl)		; Ha comprobado	todas las momias?
		jp	nz, chkKnifeMomia2
		and	a
		ret

chkKnifeMomia5:
	IF	(VERSION2)
		push	ix
		ld	de, 100h
		call	SumaPuntos
		ld	a, 8		; SFX explota momia
		call	setMusic
		pop	ix
	ELSE
		ld	de, 100h
		call	SumaPuntos
		ld	a, 8		; SFX explota momia
		call	setMusic
	ENDIF	
		ld	(ix+ACTOR_STATUS), 6 ; Estado: Destello
		ld	(ix+ACTOR_CONTROL), 4 ;	Control: IZQUIERDA
		ld	a, (ix+ACTOR_Y)	; Y momia
		and	0F8h
		ld	(ix+ACTOR_Y), a	; Ajusta la Y a	multiplo de 8
		ld	(ix+ACTOR_TIMER), 22h ;	Timer
		scf
		ret


;----------------------------------------------------
; Area a comprobar el impacto del cuchillos
;----------------------------------------------------
areaSizeMomia:	db 8, 18h
		db 8, 18h


;----------------------------------------------------
; Comprueba si el prota	coge un	cuchillo
; En caso de cogerlo, restaura en el mapa y en pantalla	el tile	sobre el que estaba el cuchillo
;----------------------------------------------------

chkCogeKnife:
		ld	a, (objetoCogido) ; #10	= Cuchillo, #20	= Pico
		and	a
		ret	nz		; Ya lleva algo

		ld	hl, knifeEnProceso
		ld	(hl), a
		inc	hl
		cp	(hl)
		ret	z		; No hay cuchillos en esta piramide

chkCogeKnife2:
		xor	a
		call	getKnifeData	; Datos	del cuchillo
		call	getLocationDE	; Comprueba si esta en la misma	habitacion que el prota
		jr	nz, chkCogeKnife3 ;  No	estan en la misma habitacion

		cp	1		; Esta en reposo en el suelo? (Status =	1)
		jr	nz, chkCogeKnife3 ; No,	comprueba el siguiente cuchillo

		call	chkAreaItem	; Comprueba si el prota	esta en	contacto con el	cuchillo
		jr	c, chkCogeKnife4 ; Si!

chkCogeKnife3:
		ld	hl, knifeEnProceso
		inc	(hl)
		ld	a, (hl)
		inc	hl
		cp	(hl)
		jr	nz, chkCogeKnife2
		ret

chkCogeKnife4:
		ld	a, (knifeEnProceso)
		ld	(IDcuchilloCoge), a ; Cuchillo que coge	el prota

		ld	a, 4		; SFX coge objeto
		call	setMusic

		ld	a, 10h		; Cuchillo
		call	cogeObjeto	; Carga	los sprites del	prota con el cuchillo

		xor	a
		call	getKnifeData
		inc	(hl)		; Pasa el cuchillo al siguiente	estado (2 = Lo lleva el	prota)

		ld	d, h
		ld	e, l
		push	hl
		ld	bc, 0Ah		; Offset tile backup del mapa
		add	hl, bc
		ld	b, (hl)		; Tile sobre el	que estaba el cuchillo
		pop	hl		; Apunta al estado

		inc	hl
		inc	hl		; Apunta a la Y
		call	getMapOffset00	; Obtiene en HL	el puntero al mapa de las coodenadas apuntada por HL
		ld	(hl), b		; Restaura el tile del mapa
		ld	h, d
		ld	l, e		; Recupe puntero a los datos del cuchillo (status)
		ld	a, b		; Tile del mapa
		call	getTileFromID	; Obtiene patron que le	corresponde al tile
		jp	drawTile	; Lo dibuja en pantalla


;----------------------------------------------------
; Obtiene las coordenadas del elemento y comprueba si esta en la misma habitacion que el prota
; In: HL = Puntero a Y,	X, habitacion
; Out:
;    Z = Esta en la habitacion del prota
;    D = Y
;    E = X
;----------------------------------------------------

getLocationDE:
		inc	hl

getLocationDE2:
		inc	hl

getLocationDE3:
		ld	d, (hl)		; Y
		inc	hl
		inc	hl
		ld	e, (hl)		; X
		inc	hl
		ld	b, a
		ld	c, (hl)		; Habitacion
		ld	a, (ProtaRoom)	; Parte	alta de	la coordenada X. Indica	la habitacion de la piramide
		cp	c		; Esta en la misma pantalla que	el prota?
		ld	a, b
		ret


;----------------------------------------------------
; Dibuja un cuchillo
; In: HL = Puntero a status, sentido, Y, X, habitacion
;----------------------------------------------------

drawTile:
		call	getLocationDE
		ret	nz		; No esta en la	habitacion visible

		call	coordVRAM_DE	; Pasa coordenadas en DE a direccion de	VRAM
	IF	(VERSION2)
		call	WRTVRM
		ld	b,1
		dec	b
		ret
	ELSE
		jp	WRTVRM		; Escribe un dato en la	VRAM
	ENDIF

;----------------------------------------------------
;
; Comprueba si el prota	coge una gema
;
;----------------------------------------------------

chkCogeGema:
		xor	a
		ld	(ElemEnProceso), a ; Empezamos por la primera gema

chkCogeGema2:
		xor	a
		call	getGemaDat	; Puntero a los	datos de la gema
		call	getLocationDE	; Esta en la pantalla del prota?
		jr	nz, chkCogeGema3

		and	0Fh		; A = Color de la gema
		jr	z, chkCogeGema3	; Color	0

		call	chkAreaItem	; Comprueba si el prota	esta tocando la	gema
		jr	nc, chkCogeGema3 ; No

		ld	de, 500h
		call	SumaPuntos	; Suma 500 puntos

		ld	a, 9		; SFX coger gema
		call	setMusic

		ld	a, 1		; Offset status
		call	getGemaDat
		ld	(hl), 2		; Status = Gema	cogida.	Hay que	borrarla

chkCogeGema3:
	IF	(VERSION2)
		call	chkLastGema2
		jr	nz,chkCogeGema2
		ret
	ELSE
		ld	hl, ElemEnProceso ; Usado para saber la	gema o puerta que se esta procesando
		inc	(hl)		; Siguiente gema
		ld	a, (hl)
		dec	hl		; Puntero a gemas totales en la	piramide
		cp	(hl)		; Quedan gemas por comprobar?
		jr	nz, chkCogeGema2
		ret
	ENDIF
;----------------------------------------------------
; Offset X al centro del objeto, ancho area a comprobar	(ancho prota)
; Offset Y al centro del objeto, alto area (parte superior del prota)
; Para colisiones con objetos se comprueba la parte superior del prota
; con el centro	superior del objeto
;----------------------------------------------------
itemHitArea:	db 5, 11h
		db 1, 9


;----------------------------------------------------
; Comprueba si el prota	coge un	pico
;----------------------------------------------------

chkCogePico:
		ld	a, (objetoCogido) ; #10	= Cuchillo, #20	= Pico
		and	a
		ret	nz		; Ya lleva algo


		ld	hl, numPicos
		ld	a, (hl)
		or	a
		ret	z		; No hay picos

		xor	a
		ld	(ElemEnProceso), a ; Comienza a	comprobar desde	el primer pico

	IF	(!VERSION2)
		inc	hl		; (!?) No se usa!
	ENDIF

chkNextPico:
		xor	a
		call	getPicoData	; Obtiene puntero a los	datos del pico
		call	getLocationDE2	; Comprueba si esta en la misma	habitacionq ue el prota
		jr	nz, chkLastPico	; No, pasa al siguiente	pico

		and	a		; Esta activo o	ya ha sido cogido?
		jr	z, chkLastPico	; No esta activo. Pasa al siguiente

		call	chkAreaItem	; Comprueba si el prota	toca el	pico
		jr	nc, chkLastPico	; No, pasa al siguiente

		ld	a, 4		; SFX Coger objeto
		call	setMusic

		xor	a
		call	getPicoData	; Puntero a los	datos del pico

		ld	(hl), 0		; Marca	pico como usado	(lo desactiva)
		push	hl
		inc	hl		; Apunta a la Y
		call	getMapOffset00	; Obtiene en HL	el puntero al mapa de las coodenadas apuntada por HL

		xor	a
		ld	(hl), a		; Borra	el pico	del mapa
		pop	hl
		dec	hl
		call	drawTile	; Borra	el pico	de la pantalla

		ld	a, (ElemEnProceso) ; Usado para	saber la gema o	puerta que se esta procesando
		ld	(idxPicoCogido), a ; Indice del	pico cogido por	el prota
		ld	a, 20h		; Pico
		jp	cogeObjeto	; Carga	los sprites del	prota llevando el pico

chkLastPico:
		ld	hl, ElemEnProceso ; Usado para saber la	gema o puerta que se esta procesando
		inc	(hl)
		ld	a, (numPicos)
		cp	(hl)
		jr	nz, chkNextPico
		ret

;----------------------------------------------------
; Obtiene un puntero a los datos del pico en proceso
;----------------------------------------------------

getPicoData:
		ld	a, (ElemEnProceso) ; Usado para	saber la gema o	puerta que se esta procesando
		ld	hl, picosData	; Datos	de los picos
		ld	b, a
		jp	getIndexX4_masB


;----------------------------------------------------
; Comprueba si el prota	toca a una momia
; La momia tiene que estar viva	y en un	estado activo
; Si el	prota o	la momia esta en una escalera, ambos tendran que estar en escaleras para que se	compruebe la colision
;----------------------------------------------------

chkTocaMomia:
		ld	c, 0		; Comienza por la primera momia

chkNextMomia:
		ld	a, c
		call	getMomiaDat	; Obtiene puntero a los	datos de la momia
		ld	hl, (pMomiaProceso) ; Puntero a	los datos de la	momia en proceso
		ld	a, (hl)
		cp	4		; Esta andando,	saltando, cayendo o en unas escaleras?
		jr	c, chkTocaMomia2 ; Si

		cp	7		; Esta pensando?
		jr	nz, chkLastACTOR_ ; No,	pasa a la siguiete momia

chkTocaMomia2:
		ld	a, (protaStatus) ; Status del prota
		ld	b, a
		cp	3		; Esta en unas escaleras?
		jr	z, chkTocaMomia3 ; si

		ld	a, (hl)		; Status de la momia
		cp	3		; Esta la momia	en unas	escaleras?
		jr	nz, chkTocaMomia4 ; No

chkTocaMomia3:
		ld	a, b
		cp	(hl)		; Estan	ambos en unas escaleras?
		jr	nz, chkLastACTOR_ ; No,	entonces no se comprueba si se tocan

chkTocaMomia4:
		ld	a, (ProtaRoom)	; Habitacion en	la que esta el prota
		cp	(ix+ACTOR_ROOM)	; Habitacion en	la que esta la momia
		jr	nz, chkLastACTOR_ ; No estan en	la misma habitacion

		ld	d, (ix+ACTOR_Y)	; Y momia
		ld	e, (ix+ACTOR_X)	; X momia
		ld	hl, mummyHitArea
		call	chkTocaProta	; Comprueba si el prota	toca a la momia
		jr	c, momiaMataProta ; Si,	se tocan. El prota muere

chkLastACTOR_:
		inc	c		; Siguiente momia
		ld	hl, numMomias	; Numero de momias de la piramide
		ld	a, c
		cp	(hl)		; Ha comprobado	todas las momias?
		jp	nz, chkNextMomia ; No

		and	a
		ret

momiaMataProta:
		ld	a, 1Dh		; Musica muere prota
		call	setMusic
		xor	a
		ld	(flagVivo), a	; Mata al prota
		ret


;----------------------------------------------------
; Offset X al centro de	la momia, ancho	del area a comprobar (ancho prota)
; Offset Y al centro de	la momia, alto del area	(alto prota)
; Para colisiones con momias se	comprueba el area total	del prota
; con el centro	de la momia
;----------------------------------------------------
mummyHitArea:	db 5, 0Ah
		db 8, 10h


;----------------------------------------------------
; Comprueba si el prota	esta tocando las coordenadas
; del objeto DE
;----------------------------------------------------

chkAreaItem:
		ld	hl, itemHitArea

chkTocaProta:
		push	bc
		ld	a, (ProtaY)
		ld	c, a
		ld	a, (ProtaX)
		ld	b, a
		call	chkArea
		pop	bc
		ret

;----------------------------------------------------
; Comprueba si las coordendas DE estan dentro de una
; determinada area
;
; DE indica las	coordenadas del	punto a	comprobar
; E = X	punto
; D = Y	punto
; A DE se le aplica un desplazamiento para indicar que
; punto	exacto del elemento se quiere comprobar	(por ejemplo el	centro de una momia)
;
; BC incia las coordenadas del area a comprobar
; B = X	area
; C = Y	area
; El Tamaño del	area viene indicado por	HL+1 y HL+3

; HL:
; +0 = Offset X1
; +1 = Ancho area
; +2 = Offset Y1
; +3 = Alto area
;
;----------------------------------------------------

chkArea:
		ld	a, b		; X area
		sub	e		; X punto
		sub	(hl)		; Offset X del punto
		inc	hl
		add	a, (hl)		; Ancho	del area
		jr	nc, chkArea2	; No esta dentro

		ld	a, c		; Y area
		sub	d		; Y punto
		inc	hl
		sub	(hl)		; Offset Y del punto
		inc	hl
		add	a, (hl)		; Alto del area

chkArea2:
		ret

;----------------------------------------------------
;
; Mueve	el scroll 4 posiciones dependiendo del sentido del protagonista
;
; Si ha	movido una pantalla completa o cambia el 'flagScrolling' termina.
;
;----------------------------------------------------

tickScroll:
		ld	hl, waitCounter
	IF	(VERSION2)
		ld	a,(hl)
		sub	4
		ld	(hl),a
	ELSE
		dec	(hl)
		dec	(hl)
		dec	(hl)
		dec	(hl)		; Mueve	el scroll 4 posiciones
		ld	a, (hl)
	ENDIF
		cp	0FCh
		ret	z		; Ha llegado al	final

		ld	a, (sentidoProta) ; 1 =	Izquierda, 2 = Derecha
		rra
		ld	a, (hl)
		jr	c, tickScroll2
		sub	20h
		neg

tickScroll2:
		call	tickScroll3
		ld	a, (flagScrolling)
		and	a
		ret	z
		scf
		ret

tickScroll3:
		ld	b, a		; Desplazamiento relativo a la habitacion actual
		ld	hl, ProtaRoom	; Parte	alta de	la coordenada X. Indica	la habitacion de la piramide
		ld	a, (sentidoProta) ; 1 =	Izquierda, 2 = Derecha
		cp	3
		jr	nz, tickScroll4
		ld	a, 1

tickScroll4:
		add	a, (hl)
		cp	3
		ld	a, 20h
		jr	z, tickScroll5
		xor	a

tickScroll5:
		add	a, b
		ld	de, MapaRAM
		call	ADD_A_DE	; Aplica desplazamiento


;----------------------------------------------------
; Dibuja la habitacion actual
; In:
;  DE =	Puntero	al mapa	de la habitacion
;----------------------------------------------------

drawRoom:
		ld	hl, 3820h	; Segunda fila de la pantalla (la primera esta reservada para el marcador)
		call	setVDPWrite
		ld	b, 16h		; Numero de filas (alto	en tiles)

drawRoom2:
		push	bc
		push	de
		ld	b, 20h		; Numero de columnas (ancho en tiles)

drawRoom3:
		ld	a, (de)		; ID tile
		call	getTileFromID
		exx
		out	(c), a
		exx
		inc	de
		djnz	drawRoom3

		pop	de
		ld	a, 60h		; Desplazamiento a la siguiente	fila (3*32)
		call	ADD_A_DE
		pop	bc
		djnz	drawRoom2	; Dibuja siguiente fila
		ret

;----------------------------------------------------
;
; Obtiene el patron/tile que corresponde al "ID" del mapa
; In:  A = Map ID
; Out: A = Tile	ID
;
;----------------------------------------------------

getTileFromID:
		push	hl
		ld	c, a
		rra
		rra
		rra
		and	1Eh		; El nibble alto indica	el grupo de tiles
		ld	hl, indexTiles
		call	getIndexHL_A
		ld	a, c
		and	0Fh		; El nibble bajo indica	el indice dentro del grupo
		call	ADD_A_HL
		ld	a, (hl)		; Obtiene el patron que	corresponde con	ese ID del mapa
		pop	hl
		ret



indexTiles:	dw tilesNULL
		dw tilesPlataforma	; #10
		dw tilesEscalera	; #20
		dw tilesCuchillo	; #30
		dw tilesGemas		; #40
		dw tilesGiratoria	; #50
		dw tilesSalida		; #60
		dw tilesSalida2		; #70
		dw tilePico		; #80
	
	IF	(!VERSION2)
		dw byte_5DC3		; #90 (!?) Estos bloques no se usan!
		dw byte_5DC4		; #A0
		dw byte_5DC6		; #B0
		dw byte_5DC7		; #C0
	ENDIF
		dw tilesAgujero		; #D0

tilesNULL:	db    0
		db    0

tilesPlataforma:db    0
		db    0			; Vacio
		db 40h
		db 40h			; Ladrillo
		db 41h			; Limite inferior
		db 73h			; Inicio de escalera que baja hacia la derecha (parte izquierda)
		db 74h			; Inicio de escalera que baja hacia la derecha (Parte derecha)
		db 83h			; Inicio de escalera que baja hacia la izquierda (parte	derecha)
		db 82h			; Inicio de escalera que baja hacia la izquierda (parte	izquierda)
		db 40h			; Ladrillo completo muro trampa
		db 42h			; Ladrillo simple muro trampa
		db 43h			; Ladrillo semiroto 1
		db 44h			; Ladrillo semiroto 2
		db 44h


tilesEscalera:	db 75h
		db 76h			; Peldaños bajan derecha
		db 85h
		db 84h			; Peldaños bajan izquierda


tilesCuchillo:	db 4Bh
		db 4Bh
		db 4Bh			; Cuchillo suelo


tilesGemas:	db 51h
					; Brillo superior
		db 52h			; Brillo gema izquierda
		db 53h			; Brillo gema derecha
		db 86h			; Gema azul oscuro
		db 87h			; Gema azul claro
		db 88h			; Gema magenta
		db 89h			; Gema amarilla
		db 8Ah			; Gema verde
		db 8Bh			; Gema gris


tilesGiratoria:	db 68h
		db 69h			; Puerta giratoria izquierda->derecha
		db 78h
		db 77h			; Puerta giratoria derecha->izquierda


tilesSalida:	db 6Ch
		db 7Bh
		db 6Dh
		db 7Ch
		db 6Eh
		db 7Dh
		db 63h			; Interior superior amarillo salida 1
		db 64h			; Interior superior amarillo salida 2
		db 65h
		db 66h
		db 67h			; Escaleras
		db 6Fh			; Ladrillos cerrandose
		db 5Fh
		db 60h
		db 7Eh
		db 70h


tilesSalida2:	db 71h
		db 80h
		db 7Fh
		db 72h
		db 61h
		db 62h
		db 81h
		db 5Ch			; Palanca abajo
		db 5Dh			; Palanca arriba
		db 5Eh			; Parte	inferior palanca

tilePico:	db 4Ch

	IF	(VERSION2)
tilesAgujero:	db	#4e	
	ELSE
	
byte_5DC3:	db 4Eh

byte_5DC4:	db 4Fh
		db 50h

byte_5DC6:	db 0

byte_5DC7:	db 0

tilesAgujero:	db 43h
		db 44h			; Ladrillo semiroto2
	ENDIF


halfMap1:	db 0C0h, 0, 80h, 0, 80h, 0, 81h, 0FFh, 0FFh, 0,	80h, 0,	80h, 0,	0FFh, 0C0h, 80h, 0, 80h, 0, 80h, 0, 9Fh, 0FFh, 80h, 0, 80h, 0, 80h, 0, 80h, 0, 8Fh, 0F0h, 80h, 3, 80h, 0, 0F0h,	0, 0FCh, 0, 0FFh, 0FFh
		db 0C0h, 0, 80h, 0, 80h, 0, 0FFh, 0FFh,	0C0h, 0, 0C0h, 0, 0C0h,	0FFh, 0F8h, 0FFh, 80h, 0Fh, 80h, 0Fh, 80h, 0F1h, 80h, 0F1h, 80h, 0Fh, 80h, 0Fh,	80h, 0FFh, 80h,	0FFh, 80h, 0F8h, 0FCh, 0F8h, 80h, 0FFh,	80h, 0,	80h, 0,	80h, 0
		db 0C0h, 0, 80h, 0, 80h, 0, 0FFh, 0F8h,	80h, 0,	80h, 0,	0FCh, 0, 80h, 0, 80h, 0FFh, 80h, 0FFh, 0FFh, 0FFh, 80h,	0FFh, 80h, 0F0h, 80h, 0F0h, 0FFh, 0FFh,	80h, 0,	80h, 0,	80h, 0,	0FFh, 0FFh, 80h, 0, 80h, 0, 80h, 0
		db 0C0h, 0, 80h, 0, 80h, 0, 0FFh, 0FFh,	0C0h, 0, 0C0h, 0, 0C0h,	0, 0FFh, 0F0h, 80h, 0, 80h, 0, 0F0h, 0,	80h, 0,	80h, 0,	80h, 0,	0FFh, 0FFh, 0FFh, 80h, 80h, 80h, 80h, 80h, 9Ch,	0FFh, 80h, 0, 80h, 0, 0F0h, 0

halfMap2:	db 0, 0, 0, 0, 0, 0, 0FFh, 0C0h, 0, 0, 0, 0Fh, 0FEh, 0,	0C0h, 0, 0C0h, 0, 0FFh,	0FFh, 0, 0, 0, 0, 0, 0,	0, 0, 0FFh, 0F0h, 0, 0,	0, 0, 0Fh, 0FFh, 0, 0, 0, 0, 0,	0, 0Fh,	0FFh
		db 0, 0, 0, 0, 0, 0, 0FFh, 0, 3, 0C0h, 3, 0FFh,	0, 80h,	0, 80h,	0F0h, 80h, 0F0h, 0FFh, 0F0h, 0,	0F0h, 0, 0F0h, 0, 0F3h,	0F0h, 0F0h, 0, 0, 0, 0,	0, 0, 1Fh, 0FFh, 80h, 0, 0, 0, 0, 1, 0FFh
		db 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 3, 0FFh, 0FCh,	0, 0FCh, 0, 0FCh, 0, 0FCh, 0FFh, 0, 0FCh, 0, 0FCh, 0FCh, 0FCh, 0FCh, 0FCh, 0FCh, 0, 0FCh, 0, 0,	0, 0, 7Fh, 0FFh, 0C0h, 0, 0, 0,	0, 0, 0Fh

halfMap3:	db 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0FFh, 0FCh, 0,	0, 0, 0, 0, 0, 0FFh, 0FFh, 0, 0, 0, 0, 3Ch, 0Fh, 0, 3Fh, 0, 0FFh, 3, 0F1h, 0Fh,	0F1h, 0FFh, 0FFh, 0, 0,	0, 0, 0, 0, 0FFh, 0FFh
		db 0, 0, 0, 0, 0, 0, 0,	0Fh, 0,	0F0h, 0FFh, 0, 0, 0, 0,	1Fh, 1,	0F8h, 0FFh, 0F8h, 0Fh, 0FFh, 0Ch, 0, 0Ch, 0, 0Ch, 0, 0Fh, 0FFh,	3, 0FFh, 0, 3, 0F0h, 3,	3, 0F0h, 0, 0, 0, 0, 0FFh, 0FFh
		db 0, 0, 0, 0, 0, 0, 1,	0FFh, 1, 0, 0FFh, 0, 0,	1Fh, 0,	0, 0, 0, 0F0h, 0, 3, 0FFh, 0, 0, 0, 0, 0, 0, 7,	0FFh, 0, 0, 0, 0, 0FCh,	0, 0, 0FFh, 0, 0, 0, 0,	0FFh, 0F8h

halfMap4:	db 0, 3, 0, 1, 0, 1, 0,	1, 7, 0FFh, 0, 1, 0, 1,	0, 1, 0, 1, 0FFh, 0FFh,	0, 1, 0, 1, 0, 1, 0, 1,	0, 1, 0, 1, 0, 1, 0FFh,	0FFh, 0, 1, 0, 1, 0, 1,	0FFh, 0FFh
		db 0, 3, 0, 1, 0, 1, 0FFh, 0FFh, 0, 1, 0, 1, 0FFh, 0F1h, 0, 1, 0, 1, 0,	1, 0FFh, 0FFh, 0, 1, 0,	1, 0, 1, 0, 1, 0, 1, 3Fh, 0FFh,	0, 1, 0, 1, 0, 1, 0, 1,	0FFh, 0FFh
		db 0, 3, 0, 1, 0, 1, 0FFh, 0F1h, 0, 21h, 0, 21h, 0FFh, 0F9h, 0,	11h, 0,	11h, 0,	11h, 0FFh, 0F1h, 0, 11h, 0, 11h, 0, 11h, 0FFh, 0F1h, 0,	11h, 0,	11h, 0,	11h, 0FFh, 91h,	0, 1Fh,	0, 1Fh,	0, 1Fh
		db 0, 3, 0, 1, 0, 1, 0FFh, 81h,	0, 0FFh, 0, 1, 0, 1, 3,	0FFh, 0, 1, 0, 1, 0, 1,	0FFh, 0F9h, 0, 1, 0, 1,	0, 1, 0, 1, 0Fh, 0F1h, 0C0h, 1,	0, 1, 0, 0Fh, 0, 3Fh, 0FFh, 0FFh

;----------------------------------------------------
;
; Mapas: Piramides 1-15
;
;----------------------------------------------------
MapStage1:	db 0, 33h, 0FFh, 0FFh, 0FFh, 48h, 78h, 24h, 2, 48h, 48h	; ...
		db 0, 48h, 0B0h, 2, 4, 70h, 18h, 18h, 31h, 18h,	0E0h, 42h
		db 0A0h, 10h, 54h, 78h,	0D0h, 1, 80h, 78h, 0, 0, 0, 8
		db 30h,	28h, 30h, 0C9h,	50h, 28h, 50h, 0C9h, 78h, 41h
		db 78h,	0B0h, 0A0h, 50h, 0A0h, 0A1h



MapStage2:	db 0, 11h, 21h,	30h, 0FFh, 0FFh, 70h, 30h, 18h,	78h, 0D1h
		db 34h,	3, 18h,	0D0h, 0, 30h, 88h, 4, 60h, 61h,	1, 5, 55h
		db 50h,	90h, 77h, 60h, 0B8h, 88h, 18h, 49h, 69h, 30h, 61h
		db 43h,	68h, 51h, 3, 10h, 38h, 0A0h, 0C0h, 18h,	0D1h, 7
		db 10h,	0B8h, 40h, 18h,	40h, 0C8h, 80h,	70h, 90h, 8, 48h
		db 69h,	90h, 0D1h, 2, 2, 20h, 76h, 2, 28h, 46h,	2, 78h
		db 79h,	80h, 91h, 0Dh, 30h, 41h, 50h, 30h, 60h,	0D1h, 78h
		db 51h,	80h, 0E0h, 0A0h, 50h, 0A8h, 91h, 40h, 13h, 40h
		db 0D2h, 80h, 93h, 0A0h, 22h, 0A0h, 52h, 0A0h, 0B3h



MapStage5:	db 2, 30h, 0FFh, 0FFh, 0A0h, 68h, 68h, 78h, 0E0h, 44h
		db 2, 10h, 0B8h, 3, 80h, 38h, 0, 4, 30h, 18h, 0D8h, 87h
		db 50h,	48h, 79h, 50h, 78h, 48h, 68h, 70h, 1, 0A0h, 80h
		db 5, 18h, 0F0h, 38h, 10h, 78h,	10h, 90h, 0E8h,	0A8h, 8
		db 0, 1, 0A0h, 18h, 0Ah, 28h, 19h, 40h,	99h, 48h, 28h
		db 68h,	28h, 80h, 0A9h,	88h, 28h, 88h, 51h, 0A0h, 0A0h
		db 0A0h, 0C9h, 0A8h, 31h



MapStage4:	db 0, 10h, 20h,	30h, 38h, 51h, 38h, 0FFh, 98h, 0D8h, 58h
		db 0FFh, 2, 10h, 18h, 0, 78h, 0D9h, 1, 6, 30h, 30h, 10h
		db 52h,	80h, 78h, 77h, 98h, 10h, 48h, 18h, 0E1h, 61h, 78h
		db 51h,	53h, 80h, 69h, 3, 68h, 0B0h, 18h, 0A9h,	80h, 0B9h
		db 9, 40h, 38h,	40h, 90h, 50h, 78h, 68h, 28h, 18h, 0F1h
		db 58h,	29h, 70h, 0B9h,	90h, 11h, 90h, 0E9h, 1,	0, 28h
		db 22h,	0, 10h,	28h, 98h, 30h, 41h, 40h, 0D1h, 50h, 50h
		db 68h,	89h, 78h, 40h, 80h, 0D0h, 0A0h,	48h, 0A8h, 89h
		db 40h,	1Bh, 40h, 0ABh,	58h, 1Bh, 58h, 62h, 80h, 9Bh, 0A0h
		db 2Ah,	0A0h, 0CBh



MapStage3:	db 3, 33h, 0FFh, 0FFh, 60h, 28h, 28h, 48h, 0B0h, 41h, 2	; ...
		db 8, 90h, 0, 60h, 10h,	2, 5, 34h, 18h,	0D8h, 47h, 50h
		db 0E0h, 78h, 48h, 10h,	86h, 88h, 58h, 75h, 0A8h, 18h
		db 2, 30h, 0B0h, 78h, 0A0h, 3, 10h, 8, 20h, 10h, 58h, 8
		db 0, 1, 78h, 80h, 7, 30h, 19h,	30h, 0C9h, 50h,	90h, 50h
		db 0C9h, 68h, 50h, 78h,	0C8h, 0A0h, 89h



MapStage6:	db 2, 11h, 22h,	32h, 0FFh, 0FFh, 80h, 58h, 74h,	80h, 0A1h
		db 54h,	3, 10h,	0C0h, 2, 78h, 0E0h, 1, 40h, 39h, 0, 6
		db 33h,	20h, 0D8h, 48h,	40h, 0D8h, 56h,	58h, 58h, 70h
		db 68h,	68h, 64h, 28h, 0E1h, 75h, 48h, 91h, 2, 0A8h, 8
		db 68h,	29h, 0Ah, 10h, 8, 38h, 8, 58h, 8, 60h, 78h, 78h
		db 30h,	98h, 40h, 58h, 39h, 68h, 0C9h, 90h, 0E1h, 0A8h
		db 0E1h, 1, 2, 58h, 7Eh, 2, 0A0h, 18h, 80h, 0A0h, 10h
		db 28h,	19h, 38h, 60h, 38h, 71h, 48h, 28h, 60h,	0C1h, 68h
		db 11h,	88h, 11h, 0A0h,	0C9h, 0A8h, 58h, 28h, 6Ah, 48h
		db 0ABh, 68h, 52h, 68h,	0B3h, 88h, 5Ah,	0A0h, 3Bh, 0A8h
		db 0A2h



MapStage8:	db 0, 12h, 22h,	31h, 0FFh, 0FFh, 0A0h, 98h, 78h, 98h, 0D1h
		db 91h,	3, 18h,	0B0h, 4, 98h, 0E0h, 2, 60h, 71h, 0, 5
		db 30h,	58h, 0A0h, 45h,	80h, 70h, 57h, 18h, 18h, 79h, 40h
		db 11h,	83h, 68h, 59h, 4, 10h, 70h, 78h, 58h, 48h, 0B1h
		db 88h,	41h, 7,	40h, 20h, 40h, 0E0h, 68h, 28h, 20h, 31h
		db 38h,	69h, 38h, 0B1h,	90h, 0B1h, 1, 2, 58h, 36h, 3, 48h
		db 50h,	70h, 0A1h, 78h,	21h, 0Ch, 30h, 11h, 50h, 38h, 78h
		db 40h,	0A0h, 48h, 0A8h, 0C1h, 28h, 0CAh, 48h, 4Bh, 48h
		db 93h,	78h, 0E2h, 0A0h, 2Ah, 0A0h, 93h, 0A8h, 6Ah



MapStage11:	db 3, 32h, 0FFh, 0FFh, 0A0h, 38h, 0C4h,	0A0h, 98h, 0A4h	; ...
		db 2, 20h, 0A0h, 2, 0A0h, 78h, 3, 5, 52h, 28h, 0E0h, 68h
		db 30h,	58h, 86h, 68h, 58h, 40h, 90h, 0E8h, 35h, 0A0h
		db 10h,	1, 68h,	38h, 4,	38h, 0B8h, 58h,	8, 58h,	98h, 0A8h
		db 0E0h, 2, 2, 78h, 62h, 2, 78h, 9Ah, 0, 0Ah, 28h, 88h
		db 30h,	41h, 48h, 11h, 48h, 99h, 68h, 20h, 68h,	79h, 68h
		db 0B8h, 88h, 79h, 0A8h, 60h, 0A8h, 0C0h



MapStage7:	db 3, 30h, 0FFh, 0FFh, 60h, 48h, 64h, 78h, 0D0h, 84h, 2	; ...
		db 10h,	0A8h, 2, 28h, 18h, 0, 5, 30h, 18h, 0D8h, 45h, 30h
		db 48h,	69h, 48h, 10h, 52h, 88h, 20h, 71h, 88h,	58h, 2
		db 10h,	70h, 80h, 0E8h,	3, 10h,	8, 18h,	0F0h, 58h, 30h
		db 0, 0, 8, 30h, 31h, 40h, 0E0h, 68h, 11h, 68h,	69h, 80h
		db 91h,	88h, 68h, 0A0h,	0D8h, 0A8h, 31h



MapStage9:	db 1, 32h, 40h,	0B8h, 88h, 0FFh, 0A0h, 20h, 0A8h, 0FFh
		db 1, 20h, 90h,	2, 4, 61h, 48h,	50h, 42h, 68h, 98h, 57h
		db 80h,	18h, 74h, 88h, 50h, 2, 30h, 18h, 88h, 88h, 6, 10h
		db 0D8h, 48h, 0D0h, 58h, 68h, 58h, 70h,	58h, 0A8h, 98h
		db 78h,	0, 0, 7, 28h, 58h, 28h,	0B8h, 48h, 89h,	68h, 0C0h
		db 88h,	0A0h, 0A8h, 59h, 0A8h, 0C0h



MapStage10:	db 2, 12h, 20h,	31h, 0FFh, 0FFh, 0A0h, 70h, 0B8h, 98h
		db 0B1h, 94h, 3, 78h, 90h, 3, 18h, 49h,	3, 98h,	91h, 4
		db 6, 41h, 40h,	88h, 53h, 68h, 18h, 37h, 68h, 68h, 64h
		db 10h,	0E1h, 75h, 40h,	11h, 86h, 58h, 71h, 3, 0A8h, 8
		db 48h,	0E9h, 80h, 69h,	6, 10h,	10h, 30h, 0E8h,	58h, 8

	IF	(VERSION2)
		db 78h,	28h, 30h, 31h, 38h, 0B1h, 0, 3,	0A0h, #18, 38h	; Muro trampa con coordenadas (#18, #a0) Al coger el cuchillo de abajo a la izquierda
	ELSE
		db 78h,	28h, 30h, 31h, 38h, 0B1h, 0, 3,	0A0h, 21h, 38h	; Muro trampa mal puesto en (#120,#a0) Hay que hacer un par de agujeros bajo la escalera para que aparezca.
	ENDIF

		db 21h,	40h, 0E1h, 0Dh,	38h, 40h, 40h, 0C9h, 48h, 20h
		db 88h,	40h, 0A8h, 38h,	0A8h, 0C1h, 28h, 0CAh, 40h, 4Ah
		db 48h,	93h, 58h, 1Bh, 78h, 9Bh, 0A0h, 2Ah, 0A0h, 0E2h



MapStage15:	db 1, 31h, 40h,	0B8h, 0E2h, 0FFh, 78h, 18h, 18h, 0FFh
		db 2, 20h, 90h,	0, 78h,	10h, 3,	6, 30h,	30h, 18h, 45h
		db 40h,	60h, 69h, 58h, 68h, 78h, 78h, 60h, 61h,	80h, 48h
		db 34h,	88h, 70h, 2, 28h, 0C0h,	0A8h, 10h, 6, 10h, 8, 10h
		db 0F0h, 28h, 40h, 48h,	40h, 50h, 70h, 68h, 0D8h, 0, 0
		db 8, 28h, 68h,	28h, 0A9h, 48h,	98h, 48h, 0E0h,	78h, 0B9h
		db 0A0h, 0B8h, 0A8h, 30h, 0A8h,	51h



MapStage12:	db 3, 10h, 21h,	31h, 0FFh, 0FFh, 60h, 0A0h, 0B4h, 70h
		db 0E1h, 0D4h, 3, 18h, 0E0h, 2,	28h, 50h, 4, 98h, 89h
		db 0, 6, 30h, 40h, 98h,	45h, 48h, 10h, 69h, 88h, 20h, 78h
		db 18h,	49h, 71h, 68h, 39h, 54h, 80h, 71h, 3, 68h, 0D0h
		db 88h,	31h, 10h, 0A1h,	8, 10h,	0F1h, 20h, 10h,	20h, 48h
		db 68h,	40h, 0A0h, 18h,	38h, 91h, 88h, 59h, 0A0h, 0F1h

	IF	(VERSION2)
		db 2, 0, 38h, 0AAh, 2, 58h, 5Eh, 1, 98h, #e9, 0Ch, 30h		; Mueve el muro trampa 8 pixeles a la derecha (!?) Estaba mejor en el original
	ELSE
		db 2, 0, 38h, 0AAh, 2, 58h, 5Eh, 1, 98h, 0E1h, 0Ch, 30h		; Muro trampa en (#1e0, #98) Aparece al coger el pico de abajo a la derecha
	ENDIF

		db 29h,	40h, 0D0h, 68h,	19h, 80h, 0C0h,	88h, 71h, 0A0h
		db 0C1h, 0A8h, 70h, 28h, 0BBh, 48h, 0AAh, 78h, 0B3h, 0A0h
		db 52h,	0A0h, 0BBh



MapStage13:	db 2, 33h, 0FFh, 0FFh, 80h, 18h, 0C8h, 70h, 0C8h, 0E4h
		db 2, 28h, 0D0h, 3, 80h, 60h, 1, 5, 30h, 18h, 0D8h, 42h
		db 28h,	28h, 57h, 50h, 68h, 68h, 58h, 50h, 74h,	68h, 68h
		db 1, 0A8h, 40h, 8, 10h, 8, 20h, 8, 38h, 10h, 58h, 8, 78h
		db 30h,	88h, 0D0h, 98h,	8, 98h,	50h, 0,	0, 0Ah,	28h, 11h
		db 30h,	0B0h, 48h, 28h,	50h, 0D1h, 68h,	19h, 78h, 0A0h
		db 88h,	48h, 0A0h, 0A9h, 0A8h, 20h, 0A8h, 68h



MapStage14:	db 1, 12h, 21h,	33h, 0FFh, 98h,	71h, 0F1h, 38h,	0D8h, 0D8h
		db 0FFh, 2, 0A0h, 80h, 3, 20h, 10h, 2, 6, 30h, 48h, 50h
		db 43h,	68h, 50h, 68h, 88h, 80h, 81h, 38h, 49h,	44h, 68h
		db 49h,	57h, 88h, 49h, 2, 0A8h,	48h, 80h, 89h, 0Ch, 10h
		db 8, 10h, 10h,	10h, 18h, 10h, 68h, 28h, 0A0h, 30h, 10h
		db 58h,	60h, 40h, 40h, 10h, 0B1h, 30h, 31h, 48h, 69h, 68h
		db 0A9h, 1, 0, 80h, 0A2h, 0, 0Bh, 28h, 68h, 30h, 19h, 0A8h
		db 30h,	0A8h, 0C9h, 30h, 6Bh, 30h, 0C3h, 40h, 13h, 50h
		db 0CBh, 78h, 0C2h, 0A0h, 2Ah, 0A0h, 8Bh

;----------------------------------------------------
; Marca	la piramide como pasada
; HL = Piramides pasadas
; DE = Mascara de la piramide actual
;----------------------------------------------------

setPiramidClear:
		ld	c, (hl)
		inc	hl
		ld	b, (hl)
		ld	a, b
		or	d
		ld	(hl), a
		dec	hl
		ld	a, c
		or	e
		ld	(hl), a
		ret


;----------------------------------------------------
; Devuelve en DE el bit	activo que corresponde a la piramide actual
;----------------------------------------------------

calcBitMask:
		ld	de, 1		; Devuelve en DE el bit	activo que corresponde a la piramide actual
		ld	a, (piramideActual)
		ld	b, a

calcBitMask2:
		dec	b
		ret	z
		sla	e
		rl	d
		jr	calcBitMask2

;----------------------------------------------------
; AI Gemas
;----------------------------------------------------

AI_Gemas:
		xor	a		; Empezamos por	la primera
		ld	(ElemEnProceso), a ; Usado para	saber la gema o	puerta que se esta procesando

nextGema:
		xor	a
		call	getGemaDat	; Obtiene puntero a los	datos de la gema en proceso
		inc	hl
		ld	a, (hl)		; Status
		call	jumpIndex
		dw gemaDoNothing
		dw gemaDoNothing
		dw gemaCogida		; 2 = Borra la gema de la pantalla y del mapa e	incrementa el numero de	gemas cogidas
		dw gemaDoNothing	; 3 = Inactiva

gemaDoNothing:
		jp	chkLastGema


;----------------------------------------------------
; Borra	la gema	y los brillos tanto de la pantalla como	del mapa
; Incrementa el	numero de gemas	cogidas
; Indica a los cuchillos que tienen que	actualizar el fondo sobre el que estan
;----------------------------------------------------

gemaCogida:
		xor	a
		call	getGemaDat	; Obtiene puntero a los	datos de la gema en proceso
		ld	a, (hl)
		and	0F0h
		ld	(hl), a		; Desactiva gema del mapa

		inc	hl
		inc	(hl)		; Pasa al siguiente estado

		inc	hl
		ld	a, (hl)		; Y
		sub	8
		ld	d, a		; Coordenada Y del brillo de arriba de la gema
		inc	hl
		inc	hl
		ld	e, (hl)		; X
		call	coordVRAM_DE	; Obtiene direccion de la VRAM de esas coordenadas en la tabla de nombres
		xor	a		; Tile vacio
		call	WRTVRM		; Borra	el brillo superior

		ld	bc, 1Fh		; Distancia al brillo de la izquierda (tile de abajo a la izquierda)
		add	hl, bc
		ld	de, eraseData	; Tiles	vacios
		ld	bc, 103h	; Ancho	de 3 tiles
		call	DEtoVRAM_NXNY	; Borra	de la pantalla el brillo de la izquierda, la gema y el brillo de la derecha

		ld	a, 2		; Offset variable Y
		call	getGemaDat
		call	getMapOffset00	; Obtiene en HL	el puntero al mapa de las coodenadas apuntada por HL
		ld	de, eraseData
		call	putBrillosMap	; Borra	los brillos del	mapa

		ld	hl, gemasCogidas
		inc	(hl)		; Incrementa el	numero de gemas	cogidas

		call	knifeUpdateBack	; Fuerza a los cuchillos a actualizar el tile de fondo sobre el	que estan
					; Podia	estar sobre el brillo de la gema y ahiora que se ha quitado hay	que actualizarlo
		jp	chkLastGema

;----------------------------------------------------
; Valores iniciales del	cuchillo al lanzarse
; Velocidad decimal, velocidad X...
;----------------------------------------------------
knifeDataInicio:db    0
		db    2			; Velocidad del	cuchillo

eraseData:	db 0, 0, 0
		db 0, 0, 0
		db 0, 0, 0


;----------------------------------------------------
; Patrones usados para dibujar como se hace un agujero con el pico
; Para calcular	el indice se suma a esta lista el valor	del contador de	animacion
; Este contador	se decrementa de 3 en 3	y empieza en #15
; El primer valor que se usa es	#12 (tile = #43)
; La animacion es #43, #44, 0, #43, #44, 0, 0
;----------------------------------------------------
tilesAnimCavar:	db 0
		db 0, 0, 0
		db 0, 0, 44h
		db 0, 0, 43h
		db 0, 0, 0
		db 0, 0, 44h
		db 0, 0, 43h

;----------------------------------------------------
; Comprueba si ha procesado todas las gemas
;----------------------------------------------------
	IF	(VERSION2)
	
chkLastGema:
		call	chkLastGema2	; Se han procesado todas las gemas?
		ret	z		; Si
		jp	nextGema	; No, sigue con otra
chkLastGema2:		
		ld	hl, ElemEnProceso ; Usado para saber la	gema o puerta que se esta procesando
		inc	(hl)		; Siguiente gema
		ld	a, (hl)
		dec	hl
		cp	(hl)		; Ha procesado todas?
		ret
	ELSE
	
chkLastGema:
		ld	hl, ElemEnProceso ; Usado para saber la	gema o puerta que se esta procesando
		inc	(hl)		; Siguiente gema
		ld	a, (hl)
		dec	hl
		cp	(hl)		; Ha procesado todas?
		ret	z		; Si, termina
		jp	nextGema	; No, procesa la siguiente
	ENDIF
	
;----------------------------------------------------
; Devuelve en HL el puntero a los datos	de la gema y en	A la variable indicada
; In:
;   A =	Offset a la variable de	la estructura
; Out:
;  HL =	Puntero	a la variable indicada de la gema en proceso
;   A =	Valor de la variable
;----------------------------------------------------


getGemaDat:
		ld	hl, datosGemas	; 0 = Color/activa. Nibble alto	indica el color. El bajo si esta activa	(1) o no (0)
					; 1 = Status
					; 2 = Y
					; 3 = decimales	X
					; 4 = X
					; 5 = habitacion
					; 6-8 =	0, 0, 0
		call	ADD_A_HL
		ld	a, (ElemEnProceso) ; Usado para	saber la gema o	puerta que se esta procesando

getIndexX9:
		ld	b, a

getIndexX8_masB:
		add	a, a

getIndexX4_masB:
		add	a, a
		add	a, a
		add	a, b
		call	ADD_A_HL
		ld	a, (hl)
		ret
;----------------------------------------------------
;
; Envia	a la VRAM los datos apuntados por DE.
; B = Alto
; C = Ancho
;
;----------------------------------------------------

DEtoVRAM_NXNY:
		push	bc
		ld	b, 0
		call	DEtoVRAMset
		ld	a, 20h		; Siguiente fila (incrementa coordenada	Y)
		call	ADD_A_HL
		pop	bc
		djnz	DEtoVRAM_NXNY
		ret


;----------------------------------------------------
; Pone en el mapa los destellos	de una gema
; HL = Puntero a la posicion de	la gema	en el mapa
; DE = Puntero a patrones para brillos
;----------------------------------------------------


putBrillosMap:
		ld	bc, -60h	; Tamaño de una	fila del mapa (3 pantallas de 32 tiles)
		add	hl, bc		; Fila superior
		ex	de, hl
		ldi			; Pone brillo superior de la gema
		ld	bc, 5Eh		; Distancia al brillo de la izquierda
		ex	de, hl
		add	hl, bc
		ex	de, hl
		ld	c, 3
		ldir			; Copia	brillo de la izquierda,	espacio, brillo	de la derecha
		ex	de, hl
		ret

;----------------------------------------------------------------
;
; Logica de las	puertas	de entrada y salida de la piramide
;
; La puerta por	la que se entra	en la piramide tiene status 1 (#10)
; Las puertas por las que se sale tienen status	0 si no	se ha pasado previamente la piramide
; Si ya	se habian cogido las gemas, las	puertas	tienen status 8	(#80)
; Comprueba si se han cogido todas las gemas
; Anima	las puertas al entrar y	salir de la piramide
; Comprueba si se toca la palanca que abre la salida al	terminar una fase
; Si la	piramide ya se ha visitado, no oculta la salida
;
;----------------------------------------------------------------

AI_Salidas:
		xor	a
		ld	(ElemEnProceso), a ; Usado para	saber la gema o	puerta que se esta procesando
		ld	(puertaCerrada), a ; Vale 1 al cerrarse	la salida

chkNextExit:
		ld	hl, chkLastExit	; Comprueba si ya ha comprobado	las cuatro salidas
		push	hl		; Mete esta funcion en la pila para que	se ejecute al salir

		xor	a
		call	getExitDat	; Obtiene un puntero a la salida que se	esta procesando
		inc	a		; Es #ff su estatus?
		ret	z		; No existe esa	salida

		inc	hl
		inc	hl
		inc	hl
		inc	hl
		ld	a, (hl)		; Status de la puerta
		rra
		rra
		rra
		rra
		and	0Fh		; El nibble alto indica	el status. El bajo se usa como contador	de animacion o substatus
		call	jumpIndex


		dw chkAllGemas		; 0 = Comprueba	si se han cogido todas las gemas
		dw paintEntrada		; 1 = Dibuja la	puerta de entrada a la piramide
		dw chkOpenExit		; 2 = Comprueba	si toca	la palanca que abre la puerta
		dw openCloseExit	; 3 = Abriendo salida
		dw chkSalePiram		; 4 = Puerta abierta. Espera a que salga de la piramide
		dw openCloseExit	; 5 = Cerrando salida
		dw doNothing3		; 6 = No hace nada. Mantiene la	puerta esperando a la cortinilla
		dw finAnimEntrar	; 7 = Quita o deja la puerta dependiendo de si ya ha estado en la piramide
		dw paintCerrada		; 8 = La puerta	permanece visible y cerrada

;----------------------------------------------------------------
;
; Comprueba si se han cogido todas las gemas de	la fase
;
; Esta comprobacion la hace cada puerta	existente (normalmente la de entrada y	la de salida)
; Con lo que ambas puertas pasan a estado 1 al pasarse la fase.
;
; Cuando se cogen todas:
; - se marca la	fase como terminada
; - suena la musica de "stage clear"
; - quita las puertas giratorias
; - pasa la puerta al status 1 (#10)
;----------------------------------------------------------------

chkAllGemas:
		ld	hl, gemasCogidas ; Comprueba si	ha cogido todas	la gemas
		ld	a, (hl)		; Gemas	recogidas
		inc	hl
		cp	(hl)		; Numero de gemas que hay en esta piramide
		ret	nz		; No las ha cogido todas

		ld	a, 1
		ld	(flagStageClear), a

		ld	a, 94h
		call	setMusic	; Musica de "stage clear"

		call	quitaGiratorias	; Quita	las puerta giratorias
		ld	a, 4		; Offset al byte de status de la puerta
		call	getExitDat	; Obtiene un puntero a la salida que se	esta procesando
		ld	(hl), 10h	; Status = #10

doNothing3:
		ret


;----------------------------------------------------------------
;
; Dibuja la puerta abierta si se esta entrando en la piramide
; o cerrada si acaba de	aparecer tras coger las	gemas
; Pasa la puerta al status 2 (#20) que comprueba si el prota toca la palanca que abre la puerta
;----------------------------------------------------------------

paintEntrada:
		ld	a, (GameStatus)
		cp	4		; Esta entrando	en la piramide?
		push	af
		ld	a, 2		; Frame	salida abierta
		jr	z, paintEntrada2
		pop	af

paintCerrada:
		push	af
		xor	a		; Frame	salida cerrada

paintEntrada2:
		call	getAnimExit	; Devuelve en DE un puntero a los tiles	que forman la salida
		ld	a, 4		; Offset al estado de la puerta
		call	getExitDat	; Obtiene un puntero a la salida que se	esta procesando
		ld	(hl), 20h	; Cambia el estado a #20
		call	drawPuerta	; En DE	se pasa	el puntero a los tiles que forman la salida
		pop	af
		ret	z		; Esta entrando	en la piramide (animacion bajar	escaleras)

;----------------------------------------------------
; Fuerza a los cuchillos para que guarden el fondo sobre el que	estan
; Asi se evita que se corrompa el fondo	mientras se abre o cierra una puerta
; o cuando se coge una gema
;----------------------------------------------------

knifeUpdateBack:
		ld	hl, knifeEnProceso ; Indica a los cuchillos que	hay en el suelo	que guarden el tile de fondo sobre el que estan
		ld	(hl), 0
		inc	hl
		ld	b, (hl)		; Numero de cuchillos de la fase

status0Knife2:
		xor	a		; Offset status	cuchillo
		call	getKnifeData
		ld	a, (hl)		; Status
		dec	a		; Es igual a 1 (en reposo)
		jr	nz, status0Knife3
		ld	(hl), a		; Lo pasa a 0

status0Knife3:
		ld	hl, knifeEnProceso
		inc	(hl)		; Siguiente cuchillo
		djnz	status0Knife2
		ret

;----------------------------------------------------------------
; Comprueba si toca la palanca que abre	la salida
; El prota tiene que estar saltando y tocando la palanca con la	parte superior de su cuerpo (mano?)
; Al abrir la puerta esta pasa al estado 3 (#30) = Abriendo la puerta
;----------------------------------------------------------------

chkOpenExit:
		ld	a, (protaStatus) ; Estado del prota
		cp	1		; Esta saltando?
		ret	nz		;  No

		call	chkSameScreenS	; Comprueba si la salida esta en la pantalla del prota
		ret	nz		; No

		ld	a, d		; Y
		sub	8		; Y - 8
		ld	d, a
		ld	a, e		; X
		sub	10h		; X - 16
		ld	e, a
		push	hl
		ld	hl, palancaArea
		call	chkTocaProta	; Comrpeuba si el prota	toca la	palanca
		pop	hl
		ret	nc		; No toca la palanca que abre la puerta

		ld	a, 1
		ld	(flagStageClear), a

		ld	a, 14h
		ld	(timer), a
		inc	hl
		ld	(hl), 30h	; Estado de abriendo la	puerta
		jr	openCloseExit2


;----------------------------------------------------------------
;
; Abre o cierra	la puerta de la	piramide
;
; Al terminar de abrirse tras accionar la palanca:
; - pasa al estado 4 = Espera a	que el prota salga de la piramide
;
; Al terminar de cerrarse:
; - cuando se entra en la piramide pasa	al estado 7 (#70) = puede dejar	la puerta cerrada si ya	se han cogido las gemas	o quitarla si aun no esta pasada la fase
; - cuando se sale pasa	al estado 6 (#60) = espera a la	cortinilla negra
;----------------------------------------------------------------

openCloseExit:
		ld	a, (timer)
		and	1Fh
		ret	nz		; Procesa uno de cada 32 frames. Espera	0.5s aprox.

openCloseExit2:
		call	knifeUpdateBack	; Indica a los cuchillos que hay en el suelo que guarden el tile de fondo sobre	el que estan
		ld	a, 4		; Offset al status de la puerta
		call	getExitDat	; Obtiene un puntero a la salida que se	esta procesando
		inc	(hl)		; Incrementa el	substatus de la	puerta

		ld	a, (hl)		; Contador de animacion
		and	0Fh
		cp	4		; Ha terminado la animacion de abrir o cerrar?
		jr	nz, openCloseExit5 ; Aun no

		ld	a, (GameStatus)
		cp	4		; Esta entrando	en la piramide?
		jr	nz, openCloseExit3 ; No, esta saliendo.

		ld	(hl), 70h	; Estado puerta: Ha terminado de cerrarse. Mira	si hay que dejarla o quitarla
		jr	openCloseExit4

openCloseExit3:
		ld	a, (hl)		; Status puerta
		add	a, 10h		; Pasa al siguiente estado
		ld	(hl), a		; Si se	esta abriendo para salir, tras accionar	la palanca, pasa al estado 4
					; Si se	ha cerrado tras	salir, pasa al estado 6, que deja la puerta cerrada esperando a	la cortinilla

openCloseExit4:
		ld	hl, puertaCerrada ; Vale 1 al cerrarse la salida
		inc	(hl)
		ret

openCloseExit5:
		ld	a, (hl)		; Status
		and	0F0h
		cp	50h		; Esta cerrando	la puerta?
		ld	a, (hl)
		jr	nz, abreSalida	; No, se esta abriendo

		and	0Fh		; Se queda con el contador de la animacion
		sub	4
		neg			; Los subestados van de	0 a 3 al cerrar

abreSalida:
		and	0Fh
		dec	a
		cp	1
		jr	nz, pintaSalida

		push	af
		ld	a, 8Dh		; SFX abriendo/cerrando	puerta
		call	setMusic	; Musica que suena al abrirse o	cerrarse la puerta (si esta entrando no	se oye porque tiene preferencia	la que ya esta sonando)
		pop	af

pintaSalida:
		call	getAnimExit	; Devuelve en DE un puntero a los tiles	que forman la salida
		jp	drawPuerta


;----------------------------------------------------------------
;
; Puerta abierta y lista para que el prota salga de la piramide
; Espera a que toque las escaleras para	salir
; Dependiendo por la puerta por	la que se sale,	se toma	una direccion (norte, sur, este	u oeste)
; La puerta/direccion por la que se entra en la	piramide es la opuesta a la que	se ha salido en	la anterior
; (Ej: Si se sale por la puerta	norte de una piramide, se entra	por la sur de la siguiente)
; Pone 4 sprites en parejas solapadas (16x32) para dibujar la parte derecha de la puerta y que el prota	pase por detras
;----------------------------------------------------------------

chkSalePiram:
		call	chkSameScreenS	; Comprueba si la salida esta en la pantalla del prota
		ret	nz		; La puerta no esta en la misma	habitacion que el prota
; DE = YX

		ld	hl, salidaArea
		call	chkTocaProta
		ret	nc		; No ha	entrado	en la salida

		call	quitaMomias	; Oculta las momias

		exx
		ld	a, 4		; Offset status	puerta
		call	getExitDat	; Obtiene un puntero a la salida que se	esta procesando
		ld	(hl), 50h	; Cambia el status a 5 (#50) = Cerrando	puerta

		inc	hl
		ld	bc, 2
		ld	de, piramideDest
		ldir			; Copia	la piramide de destino y la puerta por la que se entra (flecha del mapa)
		exx

		ld	a, (ElemEnProceso) ; Usado para	saber la gema o	puerta que se esta procesando
		inc	a
		cp	1		; Arriba?
		jr	z, setFlechaSalida

		dec	a
		add	a, a
		cp	6
		jr	nz, setFlechaSalida
		ld	a, 8

setFlechaSalida:
		ld	(puertaSalida),	a ; 1 =	Arriba,	2 = Abajo, 4 = Izquierda, 8 = Derecha


; Pone los sprites de la parte derecha de la puerta que	tapan al prota al entrar por las escaleras

		ld	hl, sprAttrib	; Tabla	de atributos de	los sprites en RAM (Y, X, Spr, Col)
		ld	a, 10h
		add	a, e		; X + 16
		ld	e, a
		ld	a, d
		sub	11h
		ld	d, a		; Y - 17

		ld	b, 2		; 16x32	Dos sprites consecutivos en Y

setSprPuerta:
		ld	c, 2		; 2 sprites solapados

setSprPuerta2:
		ld	(hl), d		; Y del	sprite
		inc	hl
		ld	(hl), e		; X del	sprite
		inc	hl
		inc	hl
		inc	hl		; Puntero a los	atributos del siguiente	sprite
		dec	c
		jr	nz, setSprPuerta2 ; Segundo sprite solapado

		ld	a, d
		add	a, 10h
		ld	d, a		; Y = Y	+ 16
		djnz	setSprPuerta

		ld	a, 20h
		call	setMusic	; Silencio

		xor	a
		ld	(statusEntrada), a ; Status de la entrada a 0 =	Saliendo en la piramide
		inc	a
		ld	(flagEntraSale), a ; 1 = Entrando o saliendo de	la piramide. Ejecuta una logica	especial para este caso
		inc	a
		ld	(sentidoProta),	a ; Sentido a la derecha
		pop	hl
		pop	hl
		ret

;----------------------------------------------------
;
; Al entrar en una piramide nueva, quita la puerta
; Si ya	ha estado la deja para poder salir
;
;----------------------------------------------------

finAnimEntrar:
		call	chkPiramPasada	; Comprueba si la piramide en la que entra ya ha estado
		push	af
		ld	a, 4		; Offset status
		call	getExitDat	; Obtiene un puntero a la salida que se	esta procesando
		pop	af
		ld	(hl), 0		; Estado que oculta la puerta y	comprueba si se	cogen todas las	gemas
		jr	z, borraSalida

		ld	(hl), 20h	; Estado que deja la puerta visible y espera a que el prota toque la palanca para abrirla
		ret

borraSalida:
		ld	de, eraseData
		jr	drawPuerta

;----------------------------------------------------
; Obtiene un puntero a la estructura de	la salida que se esta procesando
;----------------------------------------------------

getExitDat:
		ld	hl, pyramidDoors ; Obtiene un puntero a	la salida que se esta procesando
		call	ADD_A_HL
		ld	a, (ElemEnProceso) ; Usado para	saber la gema o	puerta que se esta procesando
		jp	getHL_Ax7	; Devuelve HL +	A*7 y A=(HL)

chkLastExit:
		ld	hl, ElemEnProceso ; Comprueba si ya ha comprobado las cuatro salidas
		inc	(hl)
		ld	a, 4
		cp	(hl)
		jp	nz, chkNextExit
		ret


;----------------------------------------------------
; Dibuja una puerta de salida/entrada
; In:
;  DE =	Tiles que forman la puerta
;----------------------------------------------------

drawPuerta:
		xor	a
		call	getExitDat	; Obtiene un puntero a la salida que se	esta procesando
		ld	bc, 0F0F8h	; Offset X-16, Y-8
		push	de
		call	getMapOffset	; Obtiene en HL	la direccion del mapa que corresponde a	las coordenadas
		pop	de
		ex	de, hl
		push	hl

		ld	b, 3		; Alto en patrones de la puerta

drawPuerta2:
		push	bc
		ld	bc, 5		; Ancho	en patrones de la puerta
		ldir

		ld	a, 5Bh		; Desplazamiento a la fila inferior de la puerta en el mapa RAM
		call	ADD_A_DE
		pop	bc
		djnz	drawPuerta2

		xor	a
		call	getExitDat	; Obtiene un puntero a la salida que se	esta procesando
		dec	hl
		call	getLocationDE2	; Esta en la misma pantalla que	el prota? (se ve?)
		pop	hl
		ret	nz		; No hace falta	pintarla

		push	hl
		call	coordVRAM_DE	; Calcula puntero a la tabla de	nombres	de las coordenadas en DE
		pop	de
		ld	bc, -22h
		add	hl, bc

		ld	b, 3		; Patrones alto

drawPuerta3:
		ld	c, 5		; Patrones ancho

drawPuerta4:
		push	bc
		ld	a, (de)		; Tile de la puerta
		call	getTileFromID	; Obtiene patron que le	corresponde
		call	WRTVRM		; Lo dibuja en pantalla
		inc	hl
		inc	de
		pop	bc
		dec	c
		dec	c
		inc	c
		jr	nz, drawPuerta4

		ld	a, 1Bh		; Distancia en VRAM a la fila inferior de la puerta (#20 - 5)
		call	ADD_A_HL
		djnz	drawPuerta3
		ret


;----------------------------------------------------
; Comprueba si la salida esta en la habitacion actual
; y obtiene sus	coordenadas.
; Out:
;  D = Y
;  E = X
;----------------------------------------------------

chkSameScreenS:
		xor	a		; Comprueba si la salida esta en la pantalla del prota
		call	getExitDat	; Obtiene un puntero a la salida que se	esta procesando
		dec	hl
		jp	getLocationDE2



;----------------------------------------------------
; Devuelve en DE un puntero a los patrones que forman
; el framde la puerta indicado en A
;----------------------------------------------------

getAnimExit:
		add	a, a		; Devuelve en DE un puntero a los tiles	que forman la salida
		ld	hl, idxAnimExit
		call	getIndexHL_A
		ex	de, hl
		ret


;----------------------------------------------------
; Offset X coordenada palanca, ancho del prota a comprobar
; Offset Y palanca, alto del prota a comprobar
;
; Solo comprueba la parte de arriba del	prota. Asi parece que le da con	la mano	al saltar
;----------------------------------------------------
palancaArea:	db 8, 10h
		db 3, 5

;----------------------------------------------------
; Punto	que se comprueba para saber si se ha salido de la piramide
;----------------------------------------------------
salidaArea:	db 1, 2
		db 4, 6

idxAnimExit:	dw animExitClosed	; ...
		dw animExitClosing
		dw animExitOpen

animExitClosed:	db  77h,   0, 60h, 61h,	  0
		db  79h,   0, 62h, 63h,	  0
		db    0,   0, 64h, 65h,	  0

animExitClosing:db  78h, 6Bh, 6Ch, 6Dh,	6Eh
		db  79h, 6Fh, 70h, 71h,	72h
		db    0, 73h, 74h, 75h,	76h

animExitOpen:	db  78h, 60h, 66h, 67h,	61h
		db  79h, 62h,	0, 68h,	63h
		db    0, 64h, 69h, 6Ah,	65h


;----------------------------------------------------
; Logica de los	muros trampa
; Cuando la trampa no se ha activado se	comprueba si el	prota pasa por la posicion de esta para	activarla
; Una vez activada, se busca un	techo desde el que comienza a cerrarse el muro.
; El muro baja de 4 en 4 pixeles por lo	que pinta ladrillos completos o	solo la	parte de arriba	dependiendo de su posicion
; Si choca contra un objeto, se	detiene	hasta que puede	continuar
; Si choca contra un muro, se da por terminada la trampa
;----------------------------------------------------

MurosTrampa:
		ld	hl, muroTrampProces
		ld	(hl), 0		; Empieza por el primero :P
		inc	hl
		ld	a, (hl)		; Numero de muros trampa de la piramide
		or	a
		ret	z		; No hay ninguno

chkNextTrampa:
		ld	hl, chkLastMuro
		push	hl		; Guarda en la pila la rutina que comprueba si ya se han procesado todos los muros trampa

		xor	a
		call	getMuroDat
		and	a		; Esta activado	este muro trampa?
		jp	z, chkActivaTrampa ; No	comprueba si el	prota lo activa

		dec	a
		ret	nz		; Este muro ya se ha cerrado por completo

		ld	a, (timer)
		and	1Fh
		ret	nz		; El muro se mueve cada	#20 iteraciones

		inc	hl
		ld	a, (hl)		; Y muro
		add	a, 4		; Se mueve 4 pixeles hacia abajo
		ld	(hl), a		; Actualiza Y del muro
		and	7		; Su Y es multiplo de 8? (pinta	medio ladrillo o uno entero?)
		ld	c, 19h		; Map ID ladrillo completo
		jr	nz, murosTrampa2

		inc	c		; Map ID ladrillo simple (4 pixeles alto)

murosTrampa2:
		push	hl
		call	getMapOffset00	; Obtiene en HL	el puntero al mapa de las coodenadas apuntada por HL
		ex	de, hl
		pop	hl
		ld	a, (hl)		; Y del	muro
		and	7		; Ha bajado un tile completo o medio?
		jr	nz, murosTrampa3 ; Medio

		ld	a, (de)		; Tile del mapa
		and	a		; Esta vacio?
		jr	nz, trampaChoca	; No, comprueba	con lo que choca

murosTrampa3:
		call	drawTrampa
		ld	hl, protaStatus	; Datos	del prota
		ld	a, (hl)		; Status prota
		or	a		; Esta realizando alguna accion	especial?
		ret	nz		; Si

		ld	hl, ProtaY
		ld	bc, 500h	; Offset X+5, Y+0
		call	chkAplastaMuro	; Comprueba si el muro aplasta al prota
		jr	c, trampaMataProta ; Si, lo aplasta

		ld	b, 0Bh		; Offset X+11, Y+0
		call	chkAplastaMuro	; Comprueba si aplasta al prota
		ret	nc		; No

trampaMataProta:
		ld	a, 1Dh		; Musica muere prota
		call	setMusic
		xor	a
		ld	(flagVivo), a	; Mata al prota
		ret

;----------------------------------------------------
; Comprueba si el muro choca contra una	plataforma o contra un objeto
; Si choca contra un objeto se detiene hasta que este desaparece
; Si choca contra una plataforma, se da	por terminada la trampa
;----------------------------------------------------

trampaChoca:
		ld	a, (de)		; Tile del mapa

	IF	(VERSION2)
		cp	1
		jr	z,trampaLimite
	ENDIF

		and	0F0h		; Se queda con la familia/grupo
		cp	10h		; Es una plataforma o muro?
		jr	z, trampaLimite	; Si

	IF	(!VERSION2)
		inc	hl		; (!?) Si incrementa HL	pasa a los decimales de	X. Deberia quedarse en la Y,
	ENDIF

		ld	a, (hl)		; Y muro
		sub	4		; Decrementa 4 su Y, con lo que	detiene	su avance (deja	de bajar)
		ld	(hl), a		; Actualiza la Y
		ret

;----------------------------------------------------
; Si el	muro choca contra el limite inferior de	la pantalla pinta el tile de ladrillo "limite inferior"
; Si choa contra una plataforma	o muro,	pinta el tile de ladrillo normal
;----------------------------------------------------

trampaLimite:
		dec	hl		; Apunta al status del muro
		inc	(hl)		; Pasa al siguiente status = Muro cerrado por completo
		inc	hl		; Apunta a la Y
		ld	a, (de)		; Map ID con el	que ha chocado
		cp	14h		; Limite inferior de la	pantalla?
		ld	c, 13h		; Tile de ladrillo normal
		jr	nz, drawTrampa_

		inc	c		; Tile de limite inferior de la	pantalla

drawTrampa_:
	IF	(!VERSION2)
		call	drawTrampa	; (!?) Para que	pone un	CALL y luego un	RET?
		ret
	ENDIF
drawTrampa:
		ld	a, c
		ld	(de), a		; Modifica el tile del mapa
		push	hl		; Apunta a la Y
		call	getTileFromID	; Obtiene el patron que	le corresponde a ese tile del mapa
		dec	hl
		dec	hl		; Apunta a la Y	menos 2	bytes, necesario para que "drawTile" recoja las coordenadas
		call	drawTile	; Dibuja el patron en pantalla
		pop	hl
		ret


;----------------------------------------------------
; Comprueba si el prota	activa un muro trampa
; Cuando el prota pasa por la posicion de la trampa esta se activa
; En ese momento se hace una busqueda vertical desde esa posicion
; hasta	que se encuentra un muro o el limite superior de la pantalla
; Ese punto es el que se toma como inicio del muro que se cierra
;----------------------------------------------------

chkActivaTrampa:
		inc	hl
		ld	d, h
		ld	e, l
		inc	hl
		inc	hl
		ld	c, (hl)		; X trampa
		inc	hl
		ld	b, (hl)		; Habitacion trampa
		ld	hl, (ProtaX)
		and	a
		sbc	hl, bc
		ret	nz		; El prota no esta en la misma X que la	trampa

		ld	a, (de)		; Y trampa
		ld	hl, ProtaY
		cp	(hl)
		ret	nz		; No estan en la misma Y

		ld	h, d
		ld	l, e
		call	getMapOffset00	; Obtiene en HL	el puntero al mapa de las coodenadas apuntada por HL
		ld	b, 0

trampaTecho:
		push	hl		; Puntero a la posicion	en el mapa de la trampa
		push	de		; Puntero a la Y de la trampa
		and	a
		ld	de, MapaRAM
		sbc	hl, de		; Se sale del mapa por arriba?
		pop	de
		jr	c, trampaOrigen	; Si, tomamos esta posicion como inicio	del muro trampa

		pop	hl
		ld	a, (hl)		; Tile del mapa	en el que esta la trampa
		and	a		; Esta vacio?
		jr	nz, trampaOrigen2 ; No

		inc	b
		ld	a, l
		sub	60h		; distancia a la fila superior del mapa
		ld	l, a
		jr	nc, trampaTecho2 ; No hay acarreo en la	resta

		dec	h		; Resta	el acarreo a HL

trampaTecho2:
		jr	trampaTecho	; Sigue	buscando donde poner el	origen del muro	que se cierra

trampaOrigen:
		pop	hl
		ld	(hl), 12h	; Map ID ladrillo/muro

trampaOrigen2:
		ld	a, b
		add	a, a
		add	a, a
		add	a, a		; Numero de tiles de distancia hasta el	techo *	8
	IF	(!VERSION2)
		sub	4
	ENDIF
		ld	b, a
		ex	de, hl

		ld	a, (hl)		; Y de la trampa
		sub	b		; Le resta la distacia en pixeles al techo u origen de la trampa
		ld	(hl), a
		dec	hl		; Apunta al status de la trampa
		inc	(hl)		; La trampa pasa al estado 1 = Bajando muro

	IF	(!VERSION2)
		xor	a
		ld	(timer), a	;(!?) Para que sirve?
	ENDIF
		ret

;----------------------------------------------------
; Obtiene un puntero a los datos del muro trampa en proceso
;----------------------------------------------------

getMuroDat:
		ld	hl, muroTrampaDat ; Y, decimales X, X, habitacion
		call	ADD_A_HL
		ld	a, (muroTrampProces)
		ld	b, a
		jp	getIndexX4_masB

chkLastMuro:
		ld	hl, muroTrampProces
		inc	(hl)		; Siguiente muro
		ld	a, (hl)		; Muro actual
		inc	hl
		cp	(hl)		; Numero de muro totales
		jp	nz, chkNextTrampa
		ret



;----------------------------------------------------
; Comprueba si el prota	es aplastado por un muro trampa
; In:
;   BC = Offset	XY a la	cabeza del prota
; Out:
;   Carry = Es aplastado
;----------------------------------------------------

chkAplastaMuro:
		push	bc
		call	chkTocaMuro	; Z = choca
		ld	a, (de)		; Tile del mapa
		sub	19h		; #19 =	Ladrillo completo muro trampa, #1A = Ladrillo simple muro trampa
		cp	2		; Es uno de esos dos tiles del muro trampa?
		pop	bc
		ret



;----------------------------------------------------
; Dibuja la animacion de como se rompen	los ladrillos al picar
; y borra del mapa RAM los rotos. Comprueba si lo que va a picar es una	platarforma.
; Para llevar el control de la animacion se usa	"agujeroCnt"
; Esta variable	tiene un valor inicial y se decrementa en 3 a cada
; golpe	del pico. Sus valores son #12, #0F, #0C, #09, #06, #03
; y los	tiles de la animacion son #44 (semiroto), #43 (roto), #00 (vacio), #44,	#43, #00
;----------------------------------------------------

drawAgujero:
		ld	hl, agujeroCnt	; Al comenzar a	pica vale #15
		ld	a, (hl)
		and	a
		ret	z		; Ha terminado de hacer	el agujero

		ld	a, (hl)
		cp	12h		; Es el	primer golpe de	pico?
		inc	hl
		jr	z, drawAgujero2	; Si, no hace falta incrementar	la Y del agujero

		inc	(hl)
		inc	(hl)
		inc	(hl)		; Incrementa la	Y del agujero en 3

drawAgujero2:
		ld	b, a
		push	hl
		call	getMapOffset00	; Obtiene en HL	el puntero al mapa de las coodenadas apuntada por HL
		ex	de, hl
		pop	hl
		ld	a, b
		cp	9
		jr	nz, drawAgujero3

		ld	a, (de)		; Lee tile del mapa que	se va a	picar
		call	AL_C__AH_B	; Copia	el nibble alto de A en B y el bajo en C
		ld	a, b		; se queda con el nibble alto, que es la familia de tiles o tipo
		cp	1		; es una plataforma?
		jr	nz, endAgujero	; No, finaliza el agujero. Esto	no se puede picar

		ld	a, c
		cp	4		; Es plataforma	o vacio? (Map IDs #10-#13 = #00	(tile vacio), #00, #40 (tile ladrillo),	#40)
		jr	c, drawAgujero3

		cp	9		; Map ID #19 = Tile #40
		jr	nz, endAgujero

; Comprueba si hay que borrar el ladrillo picado del mapa de la	RAM

drawAgujero3:
		dec	hl
		ld	a, (hl)		; agujeroCnt
		inc	hl
		cp	0Ch		; Valor	de la animacion	en el momento de romper	totalmente el ladrillo de arriba
		jr	z, drawAgujero4	; Quita	el ladrillo del	mapa

		cp	3		; Valor	de la animacion	en el momento de romper	totalmente el ladrillo de abajo
		jr	nz, drawAgujero5

drawAgujero4:
	IF	(VERSION2)
		ld	a,1
	ELSE
		xor	a
	ENDIF
		ld	(de), a		; Borra	tile del mapa RAM

drawAgujero5:
		ld	a, (agujeroCnt)	; Al comenzar a	pica vale #15
		ld	de, tilesAnimCavar ; Tiles usados en la	animacion del agujero
		call	ADD_A_DE	; Calcula indice
		ld	a, (de)		; Tile de la animacion (ladrillo semiroto, roto	o vacio)
		dec	hl
		dec	hl		; Apunta a la Y	del agujero
		call	drawTile	; Dibuja en pantalla el	tile de	la animacion del agujero
		ld	a, 45h		; SFX Pico
		jp	setMusic

endAgujero:
		xor	a
		ld	(agujeroCnt), a	; Al comenzar a	picar vale #15
		ret


;----------------------------------------------------
; Puertas giratorias
; Si estan en movimiento la anima (5 frames)
; Dependiendo del sentido de giro hara la animacion hacia un lado o el otro
;----------------------------------------------------

spiningDoors:
		ld	hl, doorGiraData ; 0 = Status (bit 0 = Girando,	bits 2-1 = altura + 2)
					; 1 = Y
					; 2 = X	decimal
					; 3 = X
					; 4 = Habitacion
					; 5 = Sentido giro
					; 6 = Contador giro
		ld	a, (numDoorGira)
		ld	b, a
		or	a
		ret	z		; No hay puertas giratorias en esta piramide

spiningDoors2:
		bit	0, (hl)		; Esta girando esta puerta?
		jr	nz, spiningDoors3 ; Si

		ld	de, 7		; Tamaño de la estructura de cada puerta giratoria
		add	hl, de		; Puntero a la siguiente puerta
		djnz	spiningDoors2
		ret

spiningDoors3:
		ld	a, (timer)
		and	7
		ret	nz		; La puerta solo se mueve cada 8 frames

		push	hl
		pop	ix
		ld	a, (ix+SPINDOOR_TIMER) ; Counter
		inc	(ix+SPINDOOR_TIMER) ; Incrementa contador
		cp	5		; Ha girado completamente?
		jr	z, spiningDoorEnd ; Si,	desactiva giro en puerta

		add	a, a
		add	a, a
		add	a, a		; x8 (patrones de la tabla que ocupa cada frame	de giro	de la puerta)
		ld	b, a
		ld	a, (ix+SPINDOOR_SENT) ;	Sentido	del giro
		cp	8		; Gira a la derecha o a	la izquierda?
		ld	a, b
		jr	z, spiningDoor4

		ld	a, 20h		; Invierte la animacion	para el	giro a la izquierda
		sub	b

spiningDoor4:
		ld	de, tilesGiroDoor
		call	ADD_A_DE

		ld	c, 2		; Altura por defecto y ancho fijo
		ld	a, (ix+SPINDOOR_STATUS)
		srl	a		; Se queda con la altura
		add	a, c		; Altura base +	altura extra
		ld	b, a		; B = Altura puerta
		ld	h, (ix+SPINDOOR_X) ; X
		ld	l, (ix+SPINDOOR_Y) ; Y

		ld	a, (ProtaRoom)	; Parte	alta de	la coordenada X. Indica	la habitacion de la piramide
		cp	(ix+SPINDOOR_ROOM) ; Esta la puerta en la misma	habitacion que el prota?
		ret	nz		; No

		call	coordVRAM_HL	; Obtiene direccion VRAM de la tabla de	nombres	a donde	apunta HL
		jp	DEtoVRAM_NXNY	; Dibuja puerta	en la pantalla

spiningDoorEnd:
		res	0, (ix+SPINDOOR_STATUS)	; Quita	flag de	girando
		ld	a, 1100b
		xor	(ix+SPINDOOR_SENT) ; Invierte sentido de la puerta
		ld	(ix+SPINDOOR_SENT), a ;	Actualiza sentido de la	puerta

;----------------------------------------------------
; Pone un apuerta giratoria en el mapa
;----------------------------------------------------

putGiratMap:
		push	ix		; Pone puerta giratoria	en el mapa
		pop	hl
		inc	hl
		push	hl
		pop	de
		call	getMapOffset00	; Obtiene en HL	el puntero al mapa de las coodenadas apuntada por HL
		dec	de
		ld	a, (de)		; Los bits 2-1 indican la altura extra
		rra
		and	3
		add	a, 2		; Le añade la altura minima de la puerta (2)
		ld	b, a		; Altura de la puerta
		ld	a, 5
		call	ADD_A_DE
		ld	a, (de)		; Sentido de giro
		bit	2, a
		ld	a, 50h		; Map ID puerta	izquierda
		jr	z, putGiratMap2
		inc	a
		inc	a		; Map ID puerta	derecha

putGiratMap2:
		ld	c, a

putGiratMap3:
		ld	(hl), c		; Parte	izquierda de la	puerta giratoria
		inc	hl
		inc	c
		ld	(hl), c		; Parte	derecha
		ld	a, 5Fh		; Offset a la fila inferior del	mapa
		call	ADD_A_HL
		dec	c
		djnz	putGiratMap3	; Repite tantas	veces como alta	sea la puerta
		ret


;----------------------------------------------------
; Comprueba cual es la puerta que esta empujando el prota
;----------------------------------------------------

chkGiratorias:
		xor	a
		ld	(GiratEnProceso), a

chkGiratorias2:
		xor	a
		call	getGiratorData
		push	hl
		inc	hl		; Apunta a la Y
		add	a, a
		add	a, a
		and	11000b
		add	a, (hl)		; Y puerta
		ld	d, a

		ld	a, (sentidoProta) ; 1 =	Izquierda, 2 = Derecha
		rra
		ld	a, 8		; 8 pixeles a la derecha
		jr	c, chkGiratorias3 ; A la izquierda
		neg			; 8 pixeles a la izquierda

chkGiratorias3:
		inc	hl
		inc	hl
		add	a, (hl)		; X puerta
		ld	e, a

		ld	hl, ProtaY
		ld	a, (hl)		; Y prota
		inc	hl
		inc	hl
		ld	l, (hl)		; X Prota
		ld	h, a
		and	a
		sbc	hl, de		; Resta	las coordenadas	del prota y las	de la puerta
		pop	hl		; Recupera status puerta
		jr	nz, chkLastGirat

		set	0, (hl)		; Activa el bit	0 del estado de	la puerta
		ld	a, 6
		call	ADD_A_HL
		ld	(hl), 0
		ret

chkLastGirat:
		ld	hl, GiratEnProceso
		inc	(hl)
		ld	a, (hl)
		inc	hl
		cp	(hl)
		jr	nz, chkGiratorias2
		ret


;----------------------------------------------------
; Obtiene en HL	el puntero a los datos de la puerta giratoria en proceso
; Out:
;   A =	Estado
;----------------------------------------------------


getGiratorData:
		ld	hl, doorGiraData ; 0 = Status (bit 0 = Girando,	bits 2-1 = altura + 2)
					; 1 = Y
					; 2 = X	decimal
					; 3 = X
					; 4 = Habitacion
					; 5 = Sentido giro
					; 6 = Contador giro
		call	ADD_A_HL
		ld	a, (GiratEnProceso)

getHL_Ax7:
		ld	b, a		; Devuelve HL +	A*7 y A=(HL)
		sla	b
		add	a, b
		sla	b
		add	a, b
		call	ADD_A_HL
		ld	a, (hl)
		ret

;----------------------------------------------------
;
; Quita	las puertas giratorias del mapa
; Si estan en la misma habitacion que el prota las borra de la pantalla
;
;----------------------------------------------------

quitaGiratorias:
		xor	a
		ld	hl, numDoorGira
		cp	(hl)
		ret	z		; No hay puertas giratorias

		ld	(GiratEnProceso), a ; Empieza por la primera
		inc	hl

quitaGiratoria2:
		push	hl
		ld	a, (hl)		; Tamaño de la puerta giratoria
		rra
		and	3
		add	a, 2
		ld	b, a		; Altura en patrones
		push	bc
		inc	hl
		push	hl
		call	getMapOffset00	; Obtiene en HL	el puntero al mapa de las coodenadas apuntada por HL
		ld	c, 0
		call	putGiratMap3
		pop	hl
		call	getLocationDE3	; Comprueba si la puerta esta en la misma pantalla que el prota
		pop	bc
		ld	c, 2
		jr	nz, quitaGiratoria3 ; No lo esta
		call	coordVRAM_DE	; D = Y, E = X
		ld	de, eraseData
		call	DEtoVRAM_NXNY	; Borra	la puerta de la	pantalla

quitaGiratoria3:
		pop	hl
		ld	de, 7
		add	hl, de
		exx
		ld	hl, GiratEnProceso
		inc	(hl)		; Incrementa el	contador de puerta giratoria en	proceso
		ld	a, (hl)
		inc	hl
		cp	(hl)		; Ha comprobado	todas las puertas giratorias?
		exx
		jr	nz, quitaGiratoria2
		ret


;----------------------------------------------------
; Calcula la direccion de la tabla de nombres a	la que apunta HL
; In:
;   H =	X
;   L =	Y
; Out:
;  HL =	Direccion VRAM de la tabla de nombres
;----------------------------------------------------

coordVRAM_HL:
		push	de
		ex	de, hl
		ld	a, d
		ld	d, e
		ld	e, a
		call	coordVRAM_DE	; D = Y, E = X
		pop	de
		ret


;----------------------------------------------------
; Patrones usados para pintar una puerta giratoria en movimiento
; Tiene	5 posiciones posibles y	una altura maxima de 32	pixeles	(4 patrones)
; El ancho es de 16 pixeles (2 patrones)
;----------------------------------------------------
tilesGiroDoor:	db 68h,	69h, 68h, 69h, 68h, 69h, 68h, 69h
		db 6Ah,	6Bh, 6Ah, 6Bh, 6Ah, 6Bh, 6Ah, 6Bh ; Azul/Blanco	girado ->
		db 54h,	55h, 54h, 55h, 54h, 55h, 54h, 55h ; Muro azul
		db 7Ah,	79h, 7Ah, 79h, 7Ah, 79h, 7Ah, 79h ; Blanco/azul	girado <-
		db 78h,	77h, 78h, 77h, 78h, 77h, 78h, 77h ; Blanco/azul


;----------------------------------------------------
;
; Descomprime la piramide actual y sus elementos:
; Plataformas, salidas,	momias, gemas, cuchillos,
; picos, puertas giratorias, muros trampa y escaleras
;
;----------------------------------------------------

setupStage:
		xor	a
		ld	(flagMuerte), a
		ld	(UNKNOWN), a	; (!?) Se usa?
		call	BorraMapaRAM
		inc	a
		ld	(flagVivo), a
		call	hideSprAttrib	; Limpia los atributos de los sprites (los oculta)

		ld	hl, piramideDest
		ld	a, (hl)
		dec	hl
		ld	(hl), a		; Piramide actual igual	a la de	destino
		call	ChgStoneColor	; Cada 4 fases cambia el color de las piedras

		ld	hl, indexPiramides ; Indice de las piramides
		ld	a, (piramideActual)
		dec	a
		add	a, a
		call	getIndexHL_A	; Obtiene el puntero al	mapa de	la piramide actual
		ex	de, hl
		ld	b, 4
		ld	ix, MapaRAMRoot	; La primera fila del mapa no se usa (ocupada por el marcador).	Tambien	usado como inicio de la	pila

unpackMap:
		ld	a, (de)
		push	bc
		push	de
		ld	hl, indexHalfMap
		ld	c, a
		rra
		rra
		rra
		and	1Eh
		call	getIndexHL_A
		ld	a, c
		and	0Fh
		push	hl
		ld	h, 0
		ld	l, a
		add	hl, hl
		add	hl, hl		; x4
		ld	d, h
		ld	e, l
		add	hl, hl
		add	hl, hl		; x16
		ld	b, h
		ld	c, l
		add	hl, hl		; x32
		add	hl, bc		; x48
		ld	b, h
		ld	c, l
		pop	hl
		add	hl, bc
		and	a
		sbc	hl, de		; x44
		push	ix
		pop	de
		exx
;
; Descomprime un cacho de mapa
; 22 filas x 16	columnas (media	pantalla)
; Cada bit indica si hay ladrillo o esta vacio
;
		ld	b, 16h		; Numero de filas por pantalla (22)

unpackMap2:
		exx
		ld	b, 2		; Dos bytes

unpackMap3:
		push	bc
		ld	b, 8		; Ocho bits
		ld	c, (hl)

unpackMap4:
		rl	c		; Rota el byte para mirar si el	bit esta a 0 o a 1
		ld	a, 0		; Tile vacio
		jr	nc, unpackMap5
		ld	a, 12h		; Tile ladrillo

unpackMap5:
		ld	(de), a		; Pone el tile en el buffer del	mapa
		inc	de
		djnz	unpackMap4

		inc	hl		; Siguiente byte (8 tiles)
		pop	bc
		djnz	unpackMap3

		ld	a, 50h		; Distancia a la siguiente fila. Hay tres pantallas en horizontal
		call	ADD_A_DE
		exx
		djnz	unpackMap2

		exx
		ld	bc, 10h		; Distancia a la segunda mitad de la pantalla
		add	ix, bc
		pop	de
		pop	bc
		ld	a, (de)
		inc	de
		and	0F0h
		cp	30h
		jr	z, getDoors
		djnz	unpackMap


;----------------------------------------------------
; Comprueba las	puertas	de salida de la	piramide
; Si la	Y (primer byte)	es #FF la salida no existe
; La puerta por	la que se entra	a la piramide la pone a	status #10 (1)
; Si ya	se han cogido las gemas	de esta	piramide mantiene las puertas visibles y cerradas (status #80)
; Si no	se han cogido, deja la puerta en status	0 (comprobando si se cogen todas las gemas)
;----------------------------------------------------

getDoors:
		ld	hl, numPuertas
		ld	(hl), 4		; Maximo numero	de puertas que puede haber
		inc	hl
		ex	de, hl
		exx
		ld	b, 0		; Contador de salidas

getNextDoor:
		exx
		ld	a, (hl)		; Y de la puerta
		inc	a		; Es #FF (Existe esta salida?)
		jr	nz, getDoors3	; Si, existe

		dec	a
		ld	(de), a		; Marca	salida como no disponible
		inc	hl
		ld	a, 7		; Tamaño de la estructura de cada salida
		call	ADD_A_DE	; DE apunta al buffer de la siguiente salida
		jr	chkLastDoor	; Comprueba si ya se han procesado todas las puertas

getDoors3:
		call	transfCoords	; Transfiere coordenadas desde HL a DE (Y, X)

		ld	a, (puertaEntrada)
		srl	a
		cp	4
		jr	nz, getDoors4
		dec	a

getDoors4:
		exx
		cp	b		; Esta puerta es por la	que se entra en	la piramide?
		exx
		ld	a, 10h		; Status: Dibuja la puerta de entrada
		jr	z, getDoors6

		push	de
		call	chkPiramPasada	; Comprueba si la piramide ya ha sido pasada para dejar	o quitar la puerta de salida
		ld	a, 0		; Quita	la puerta y deja el estado que comprueba si se cogen todas las gemas
		jr	z, getDoors5
		ld	a, 80h		; Mantiene la puerta cerrada visible

getDoors5:
		pop	de

getDoors6:
		ld	(de), a		; Status de la puerta
		inc	de
		ld	a, (hl)
		call	AL_C__AH_B	; Copia	el nibble alto de A en B y el bajo en C
		ld	a, b
		ld	(de), a		; Piramide a la	que lleva esta puerta
		inc	de
		ld	a, c
		ld	(de), a		; Direccion de la flecha del mapa / puerta de entrada /	direccion de la	salida
		inc	de
		inc	hl

chkLastDoor:
		exx
		inc	b
		ld	a, 4		; Numero maximo	de salidas
		cp	b
		jr	nz, getNextDoor	; Aun quedan puertas por comprobar



;----------------------------------------------------
;Actualiza momias de la	piramide
;----------------------------------------------------
		exx
		ld	a, (hl)
		ld	(numMomias), a
		inc	hl
		ld	b, a
		add	a, a
		add	a, b		; 3 bytes por momia (y,	x, tipo)
		ld	b, 0
		ld	c, a
		ld	de, momiasPiramid ; Datos de las momias	que hay	en la piramide actual: y, x (%xxxxx--p), tipo
		ldir


;----------------------------------------------------
; Actualiza gemas
;----------------------------------------------------
		ld	de, gemasTotales
		ld	a, (hl)		; Numero de gemas de la	piramide
		ldi
		inc	de
		ld	b, a		; Numero de gemas

readGemas:
		push	bc
		ld	a, (hl)		; Color
		and	0F0h
		or	1		; Activa gema
		ld	(de), a		; Tipo / color de la gema

		inc	hl
		inc	de
		ld	a, 1
		ld	(de), a		; Status 1

		inc	de
		call	transfCoords	; Transfiere coordenadas desde HL a DE (Y, X)
		inc	de
		inc	de
		inc	de		; 9 bytes por gema
		pop	bc
		djnz	readGemas


		push	hl
		xor	a
		ld	(ElemEnProceso), a ; Empezamos a pintar	las gemas desde	la primera

putNextGema:
		xor	a
		call	getGemaDat	; Puntero a la gema en proceso
		call	chkPiramPasada	; Hay que poner	las gemas de esta piramide o ya	se han cogido antes?
		jr	z, putNextGema2	; Hay que ponerlas

		ld	a, (hl)
		and	0F0h
		ld	(hl), a		; Desactiva gema
		inc	hl
		ld	(hl), 3		; Status 3 de la gema
		jr	chkLastGema_

putNextGema2:
		inc	hl
		inc	hl
		call	getMapOffset00	; Obtiene en HL	el puntero al mapa de las coodenadas apuntada por HL
		push	hl
		ld	de, brillosGema	; Patrones que forman los destellos de la gema
		call	putBrillosMap	; Pone los destellos de	la gema	en el mapa

		xor	a
		call	getGemaDat
		call	AL_C__AH_B	; Copia	el nibble alto de A en B y el bajo en C
		ld	a, b		; Color	de la gema
		add	a, 40h		; Map ID gemas
		pop	hl
		ld	(hl), a		; Pone gema

chkLastGema_:
		ld	hl, ElemEnProceso ; Usado para saber la	gema o puerta que se esta procesando
		inc	(hl)		; siguiente gema
		ld	a, (hl)
		dec	hl
		cp	(hl)		; Numero total de gemas
		jr	nz, putNextGema	; Faltan gemas por procesar
		pop	hl



;----------------------------------------------------
; Actualiza cuchillos
;----------------------------------------------------
		ld	de, numKnifes
		ld	a, (hl)		; Numero de cuchillos
		ld	(de), a		; Actualiza el numero de cuchillos de la piramide
		inc	hl
		inc	de
		or	a
		jr	z, getPicos	; No hay ninguno

		ld	b, a

setKnifeCoords:
		push	bc
		inc	de
		inc	de
		call	transfCoords	; Transfiere coordenadas desde HL a DE (Y, X)
		ld	a, 0Bh
		call	ADD_A_DE
		pop	bc
		djnz	setKnifeCoords

;----------------------------------------------------
; Actualiza picos
;----------------------------------------------------

getPicos:
		ld	de, numPicos
		ld	a, (hl)		; Numero de picos
		ld	(de), a		; Actualiza el numero de picos de esta piramide
		inc	de
		inc	hl
		and	a
		jr	z, getGiratorias ; No hay picos

		ld	b, a		; Numero de picos

getPicos2:
		push	bc
		ld	a, 1
		ld	(de), a		; Status = 1
		inc	de
		call	transfCoords	; Transfiere coordenadas desde HL a DE (Y, X)
		pop	bc
		djnz	getPicos2

		push	hl
		ld	hl, numPicos
		ld	b, (hl)		; Numero de picos que hay en el	mapa
		inc	hl
		inc	hl		; Apunta a la Y	del pico

getPicos3:
		push	bc
		push	hl
		call	getMapOffset00	; Obtiene en HL	el puntero al mapa de las coodenadas apuntada por HL
		ld	(hl), 80h	; Pone pico en el mapa
		pop	hl
		ld	a, 5
		call	ADD_A_HL	; Pasa datos del pico para apuntar a las coordenadas del siguiente
		pop	bc
		djnz	getPicos3
		pop	hl


;----------------------------------------------------
; Actualiza puertas giratorias
;----------------------------------------------------

getGiratorias:
		ld	a, (hl)		; Numero de puertas giratorias
		inc	hl
		ld	de, numDoorGira
		ld	(de), a		; Actualiza numero de puertas giratorias de la piramide
		or	a
		jr	z, getMuroTrampa ; No hay puertas giratorias

		inc	de
		ld	b, a

getGiratorias2:
		push	bc
		ldi			; Altura puerta	(luego se divide entre 2 y se le suma 2)
		ldi			; Y
		inc	de		; Pasa decimales X

		ld	a, (hl)		; Coordenada X
		and	0F8h		; bits 7-3
		ld	(de), a		; X ajustada a patrones

		inc	de
		ld	a, (hl)
		rra
		rra			; bit 2
		and	1
		ld	(de), a		; Habitacion

		inc	de
		ld	a, (hl)
		rla
		rla			; bits 0-1
		and	0Ch
		ld	(de), a		; Sentido de giro
		inc	de
		inc	de
		inc	hl
		pop	bc
		djnz	getGiratorias2

		push	hl
		ld	ix, doorGiraData ; 0 = Status (bit 0 = Girando,	bits 2-1 = altura + 2)
					; 1 = Y
					; 2 = X	decimal
					; 3 = X
					; 4 = Habitacion
					; 5 = Sentido giro
					; 6 = Contador giro

getGiratorias3:
		call	putGiratMap	; Pone puerta giratoria	en el mapa
		ld	de, 7
		add	ix, de
		ld	hl, GiratEnProceso
		inc	(hl)
		ld	a, (hl)
		inc	hl
		cp	(hl)		; Comprueba si estan todas puestas
		jr	nz, getGiratorias3 ; Aun quedan	puertas	giratorias por poner en	el mapa
		pop	hl


;----------------------------------------------------
; Actualiza muros trampa
;----------------------------------------------------

getMuroTrampa:
		ld	de, numMuroTrampa ; Numero de muros trampa que hay en la piramide
		ld	a, (hl)
		ldi			; Copia	el numero de muros trampa que hay en esta piramide
		or	a
		jr	z, getStairs	;  No hay muros	trampa

		ld	b, a

getMuroTrampa2:
		push	bc		; Numero de muros trampa
		inc	de
		call	transfCoords	; Transfiere coordenadas desde HL a DE (Y, X)
		pop	bc
		djnz	getMuroTrampa2


;----------------------------------------------------
; Procesa escaleras
;----------------------------------------------------

getStairs:
		ex	de, hl
		ld	a, (de)		; Numero de escaleras
		ld	b, a
		inc	de
		and	a
		ret	z		; No hay escaleras

getStairs2:
		push	bc
		ld	hl, escaleraData
		ex	de, hl
		push	de
		ldi			; Y escalera

		xor	a
		ld	(de), a		; Decimales X

		inc	de
		ld	a, (hl)		; X
		and	0F8h
		ld	(de), a		; Ajusta la X a	multiplo de 8

		ld	a, (hl)		; Bit 0	= Sentido. Bit 1 = Habitacion
		and	1
		ld	b, a		; Sentido

		inc	de
		ld	a, (hl)
		rra
		and	1
		ld	(de), a		; Habitacion

		pop	de		; Datos	escaleras
		ex	de, hl
		push	de
		call	getMapOffset00	; Obtiene en HL	el puntero al mapa de las coodenadas apuntada por HL

getStairs3:
		ld	a, (hl)		; Hay algo en ese lugar	del mapa?
		and	a
		jr	nz, getStairs5	; Si, la escalera ha llegado a una plataforma

		ld	c, 20h
		call	putPeldanoMap
		and	a		; Sentido?
		push	bc
		ld	bc, -62h	; Desplazamiento a la fila superior del	mapa si	la escalera que	sube hacia la izquierda
		jr	z, getStairs4
		inc	bc
		inc	bc		; Hacia	la derecha

getStairs4:
		add	hl, bc
		pop	bc
		jr	getStairs3

getStairs5:
		ld	c, 15h
		call	putPeldanoMap	; Pone peldaño especial	de inicio/fin escalera
		pop	de
		inc	de
		pop	bc
		djnz	getStairs2
		ret

putPeldanoMap:
		ld	a, b		; Sentido
		and	a
		jr	z, putPeldanoMap2
		inc	c
		inc	c		; Peldaños hacia la izquierda

putPeldanoMap2:
		ld	(hl), c
		inc	c
		inc	hl
		ld	(hl), c
		ret



;----------------------------------------------------
;
; Pinta	la pantalla, los sprites, cuchillos y coloca las momias
;
;----------------------------------------------------

setupRoom:
		ld	a, 1
		ld	(flagScrolling), a
		ld	a, (ProtaRoom)	; Habitacion del prota (xHigh)
		add	a, a
		add	a, a
		add	a, a
		add	a, a
		add	a, a		; x32 (ancho de	una pantalla)
		ld	de, MapaRAM
		call	ADD_A_DE	; DE = Puntero a la pantalla en	la que se encuentra el prota (puede haber 3 en horizontal)
		call	drawRoom	; Dibuja la habitacion en la que se encuentra el prota
		call	updateSprites	; Pone los sprites
		call	AI_Cuchillos	; Pone los cuchillos
		xor	a
		ld	(momiaEnProceso), a

initMomias:
		call	initMomia
		ld	hl, momiaEnProceso
		inc	(hl)
		ld	a, (hl)
		dec	hl
		cp	(hl)		; Se han procesado todas las momia?
		jr	nz, initMomias
		ret


;----------------------------------------------------
;
; Inicializa la	momia en proceso
;
; Pasa los datos de la momia a su estructura
; Pone el estado 4 que es el de	aparecer
; Fija su velocidad y color dependiendo	del tipo de momia
; El tipo de momia se ve incrementado por el numero de veces que se ha terminado el juego
;----------------------------------------------------

initMomia:
		call	getMomiaProcDat
		push	ix
		pop	hl		; Puntero a la estructura de la	momia
		ld	(hl), 4		; Accion momia aparecer
		inc	hl
		inc	hl
		inc	hl
		ld	de, momiasPiramid ; Datos de las momias	que hay	en la piramide actual: y, x (%xxxxx--p), tipo
		ld	a, (momiaEnProceso)
		ld	c, a
		add	a, a
		add	a, c		; x3
		call	ADD_A_DE
		ex	de, hl		; HL apunta a la definicion de momia

	IF	(VERSION2)
		call	transfCoords	; Transfiere coordenadas de la momia
	ELSE
		ldi			; Copia	la Y

		inc	de		; Pasa decimales X

		ld	a, (hl)
		and	0F8h		; Ajusta la coordenada X a multiplo de 8
		ld	(de), a		; X

		inc	de
		ld	a, (hl)
		and	1
		ld	(de), a		; Habitacion de	inicio (xHigh)

		inc	de
		inc	hl
	ENDIF

		ld	a, (hl)		; Tipo de momia
		ld	c, a
		ld	a, (numFinishGame) ; Numero de veces que se ha terminado el juego
		add	a, c		; Suma al tipo de momia	las veces que se ha terminado el juego
		cp	5		; Comprueba si se sale del rango de tipos de momias existentes
		jr	c, initMomia2

		ld	a, 4		; Tipo de momia	mas inteligente

initMomia2:
		ld	c, a		; Tipo de momia
		ex	de, hl
		ld	de, tiposMomia	; Caracteristicas de cada tipo de momia	(color y velocidad)
		call	ADD_A_DE
		ld	a, (de)
		ld	b, a
		and	0F0h		; El nibble alto indica	la velocidad de	la momia
		ld	(hl), a		; Velocidad

		ld	a, 0Ah
		call	ADD_A_HL
		ld	(hl), 10h	; Timer	(tiempo	que tarda en aparecer)
		inc	hl
		inc	hl
		inc	hl
		ld	(hl), c		; Tipo de momia
		inc	de
		call	getMomiaAtrib	; Attributos del sprite	de la momia
		inc	hl
		inc	hl
		inc	hl
		ld	a, b
		call	AL_C__AH_B	; Copia	el nibble alto de A en B y el bajo en C
		ld	(hl), c		; Color
		ret

;----------------------------------------------------
; Tipos	de momia
; Nibble bajo =	Color
; Nibble alto =	Velocidad
;----------------------------------------------------
tiposMomia:	db 5Fh
		db 59h
		db 0A4h
		db 0A8h
		db 0BAh

;----------------------------------------------------
; Get index HL,	A
;
; In: HL = Index pointer
;      A = Index
; Out: HL = (HL	+ A)
;----------------------------------------------------

getIndexHL_A:
		call	ADD_A_HL
		ld	a, (hl)
		inc	hl
		ld	h, (hl)
		ld	l, a
		ret


;----------------------------------------------------
; Comprueba si la piramide actual ya ha	sido terminada
; Out: NZ = Pasada
;	Z = No pasada
;----------------------------------------------------

chkPiramPasada:
		ld	bc, (PiramidesPasadas) ; Cada bit indica si la piramide	correspondiente	ya esta	pasada/terminada
		push	bc
		call	calcBitMask	; Devuelve en DE el bit	activo que corresponde a la piramide actual
		pop	bc
		ld	a, b
		and	d
		ld	b, a
		ld	a, c
		and	e
		add	a, b
		ret


;----------------------------------------------------
; Transfiere coordenadas desde HL a DE (Y, X)
; In:
;   HL = Y, X (XXXXXxxP) X = Coordenada	X, P = Pantalla
;----------------------------------------------------

transfCoords:
		ldi			; Copia	coordenada Y
		inc	de		; Pasa los decimales de	la X
		ld	a, (hl)
		and	0F8h		; Ajusta coordenada X a	multiplos de 8 (patrones)
		ld	(de), a		; Guarda coordenada X

		inc	de		; Apunta al segundo byte de la coordenada X (habitacion)
		ld	a, (hl)		; Vuelve a leer	la coordenada X
		and	1		; Se queda con el bit 0	(!?) Solo pueden ponerse la gemas en la	pantalla 0 o 1
		ld	(de), a		; Interpreta el	bit 0 como pantalla de destino (coordenada + 256*bit0)
		inc	de
		inc	hl
		ret



;----------------------------------------------------
; Mapas	de las piramides
;----------------------------------------------------
indexPiramides:	dw MapStage1
		dw MapStage2
		dw MapStage3
		dw MapStage4
		dw MapStage5
		dw MapStage6
		dw MapStage7
		dw MapStage8
		dw MapStage9
		dw MapStage10
		dw MapStage11
		dw MapStage12
		dw MapStage13
		dw MapStage14
		dw MapStage15

indexHalfMap:	dw halfMap1
		dw halfMap2
		dw halfMap3
		dw halfMap4


;----------------------------------------------------
; Patrones que forman el destello de las gemas
;----------------------------------------------------
brillosGema:	db 40h			; Superior
		db 41h			; Izquierda
		db 0			; Espacio para la gema
		db 42h			; Derecha


;----------------------------------------------------
; Borra	el mapa	de la RAM
;----------------------------------------------------

BorraMapaRAM:
		ld	hl, MapaRAM
		ld	de,  MapaRAM+1
		ld	bc, 8A0h
		ld	(hl), 14h
		ldir
		ret

;----------------------------------------------------
;
; Cambia el color de los ladrillos cada	4 fases
;
;----------------------------------------------------

ChgStoneColor:
		ld	a, (piramideActual)
		dec	a
		rra
		rra
		and	3
		ld	hl, ColoresPiedra
		call	getIndexX9
		ex	de, hl
		ld	hl, 200h	; Destino = Patron #40 (Piedras/ladrillos)
		ld	b, 5		; Numero de patrones a pintar

ChgStoneColor2:
		push	bc
		push	de
		push	hl
		call	UnpackPatterns
		pop	hl
		ld	de, 8
		add	hl, de
		pop	de
		pop	bc
		djnz	ChgStoneColor2
		ret

;----------------------------------------------------
; Colores de los ladrillos
; Formato: numero de filas, color
;----------------------------------------------------
ColoresPiedra:	db    2,0A0h,	2, 60h,	  2,0A0h,   2, 60h,   0
		db    2, 40h,	2, 70h,	  2, 40h,   2, 70h,   0
		db    2, 60h,	2,0A0h,	  2, 60h,   2,0A0h,   0
		db    2,0C0h,	2,0B0h,	  2,0C0h,   2, 30h,   0


;----------------------------------------------------
;
; Logica del prota en las escaleras cuando entra o sale	de la piramide
; Comprueba si las sube	o las baja y actualiza las coordenadas del prota
; Si sale, comprueba si	hay que	dar un bonus
;
;----------------------------------------------------

escalerasEntrada:
		ld	a, (statusEntrada) ; Status del	prota en las escaleras de la entrada/salida
		call	jumpIndex

		dw entraSale		; Subiendo o bajando por las escaleras
		dw quietoFinEsc		; Ha llegado al	final de las escaleras.	Espera un rato
		dw chkBonusStage	; Comprueba si hay que dar un bonus por	pasarse	la piramide
		dw haSalido		; Ha salido de la piramide. Pasa al pergamino

entraSale:
		ld	hl, protaMovCnt	; (!?) Donde se	usa HL?
		ld	a, (timer)
		and	3
		ret	nz		; Procesa una de cada cuatro iteraciones

		ld	hl, 1E0h
		ld	(protaSpeed), hl ; Velocidad X mientras	entra en la piramide
		call	mueveProta	; Actualiza la posicion	del prota

		ld	a, (GameStatus)
		cp	4		; Entrando o saliendo de la piramide?
		jr	nz, salePiramide

		ld	hl, ProtaY
		inc	(hl)		; Incrementa la	Y del prota
		ld	a, (hl)
		and	7		; Ha terminado de bajar	las escaleras? (solo baja 1 tile)
		jr	nz, animProta	; Siguiente frame de la	animacion del prota

		ld	a, 1
		ld	(protaFrame), a	; Pone frame de	quieto
		call	setAttribProta	; Actualiza atributos de los sprites del prota
		jr	finEntraSale

salePiramide:
		ld	hl, ProtaY
		dec	(hl)		; Decrementa la	Y del prota
		inc	hl
		inc	hl
		ld	a, (hl)		; X prota
		add	a, 8
		ld	hl, puertaXspr	; X sprite puerta (parte derecha)
		cp	(hl)		; Esta medio cuerpo del	prota tapado por la puerta derecha?
		jr	c, animProta	; No

		call	hideSprAttrib	; Oculta todos los sprites (prota, puerta derecha...)
		jr	finEntraSale

animProta:
		ld	hl, protaFrame
		inc	(hl)		; siguiente frame
		and	7		; rango	0-7
		ld	(hl), a
		jp	setAttribProta	; Actualiza atributos de los sprites del prota

finEntraSale:
		ld	bc, 0A8h
		ld	(protaSpeed), bc ; El byte bajo	indica la parte	"decimal" y el alto la entera
		ld	b, 4		; Numero de sprites a quitar
		call	hideSprAttrib2	; Oculta los sprites de	la puerta

		ld	hl, statusEntrada ; Status del prota en	las escaleras
		inc	(hl)		; Pasa al siguiente estado: quieto al pie de las escaleras

		ld	a, 20h
		ld	(timer), a
		ret


;----------------------------------------------------
; El prota ha llegado al final de las escaleras
; al entrar o al salir de la piramide
;----------------------------------------------------

quietoFinEsc:
		call	AI_Salidas
		ld	a, (puertaCerrada) ; Vale 1 al cerrarse	la salida
		or	a
		ret	z		; La puerta no se ha cerrado aun

		ld	a, (GameStatus)
		cp	4		; Entrando o saliendo de la piramide?
		jr	z, estaDentro	; Entrando

		ld	a, 20h		; Silencio
		call	setMusic

		ld	hl, statusEntrada
		inc	(hl)		; Pasa al siguiente estado de las escaleras: comprueba si hay que dar un bonus por pasarse la fase

		xor	a
		ld	(ElemEnProceso), a ; Usado para	saber la gema o	puerta que se esta procesando
		ret


;----------------------------------------------------
; Ya esta dentro de la piramide	y la puerta se ha cerrado.
; Pasa al siguiente substado que inicia	la fase
;----------------------------------------------------

estaDentro:
		ld	a, 28h
		ld	(waitCounter), a
		ld	hl, subStatus
		inc	(hl)		; Inicia la fase
		ret

;----------------------------------------------------
;
; Comprueba si hay que dar un bonus por	pasarse	la piramide
; Si ya	se ha pasado no	hay bonus
;
;----------------------------------------------------

chkBonusStage:
		ld	hl, waitCounter
		dec	(hl)
		ret	p

		call	chkPiramPasada
		jr	nz, chkBonusStage2 ; Ya	se la habia pasado

		ld	de, 2000h
		call	SumaPuntos	; Bonus	de 2000	puntos
		ld	a, 8Fh		; Bonus	stage clear
		call	setMusic

chkBonusStage2:
		ld	hl, statusEntrada
		inc	(hl)		; Pasa al siguiente estado

		ld	a, 70h
		ld	(waitCounter), a ; Tiempo que espera antes de finalizar	el proceso de salida

		call	calcBitMask	; Devuelve en DE el bit	activo que corresponde a la piramide actual
		ld	hl, PiramidesPasadas ; Cada bit	indica si la piramide correspondiente ya esta pasada/terminada
		jp	setPiramidClear	; Marca	la piramide actual como	pasada


;----------------------------------------------------
; Vida extra
; Suma una vida	y reproduce un SFX para	indicarlo
;----------------------------------------------------

VidaExtra:
		ld	hl, Vidas
		inc	(hl)		; Incrementa el	numero de vidas

		ld	a, 8Ah		; SFX vida extra
		call	setMusic
		jp	dibujaVidas

;----------------------------------------------------
; Ha salido de la piramide
;
;----------------------------------------------------

haSalido:
		ld	hl, timer
		ld	a, (hl)
		and	3		; (!?) Para que	hace esto sin o	vale para nada?

		inc	hl
		dec	(hl)		; Decrementa waitCounter
		ret	nz		; Aun hay que esperar a	que termine la fanfarria de "se salio de la piramide"

		xor	a
		ld	(flagEntraSale), a ; Continua con la logica normal del juego

		ld	a, 8		; Status = Stage clear
		ld	(GameStatus), a
		ret


;----------------------------------------------------
; Inicializa los sprites del prota y de	la puerta de entrada
; Coloca al prota en la	parte superior derecha de las escaleras	e indica color de ropa y piel
; Cambia el estado de la puerta	a "cerrandose"
; Coloca los sprites que forman	la hoja	derecha	de la puerta que solapa	al prota
; Cuatro sprites en total (dos parejas solapadas)
;----------------------------------------------------

setSprDoorProta:
		ld	de, sprAttrib	; Tabla	de atributos de	los sprites en RAM (Y, X, Spr, Col)
		ld	hl, attribDoor	; Atributos de las puertas de la entrada
		ld	bc, 10h		; 4 sprites * 4	bytes
		ldir

		ld	a, 0Eh
		ld	(protaColorRopa), a ; Color gris para la ropa y	casco del prota
		ld	a, 6
		ld	(ProtaColorPiel), a ; Color naranja para la piel

		ld	a, (puertaEntrada) ; Puerta por	la que se esta entrando	(direccion)
		srl	a		; Los valores son 1,2,4,8
		cp	4
		jr	nz, initDoorProta2
		dec	a		; Convierte numero de bit a decimal

initDoorProta2:
		ld	hl, pyramidDoors ; Y (FF = Desactivado)
					; X decimales
					; X
					; Habitacion
					; Status (Nibble alto =	Status,	Nibble bajo = contador)
					; Piramide destino
					; Direccion por	la que se entra	/ Flecha del mapa
		call	getHL_Ax7	; Obtiene puntero a los	datos de la puerta por la que se entra

		push	hl
		ld	de, ProtaY
		ld	a, (hl)		; Y centro puerta
		sub	8
		ld	(de), a		; Coloca al prota 8 pixeles mas	arriba
		inc	de
		inc	hl
		ldi			; X decimales

		ld	a, (hl)		; X centro puerta
		add	a, 8
		ld	(de), a		; Coloca al prota 8 pixeles a la derecha

		inc	de
		inc	hl
		ldi			; Misma	habitacion para	la puerta y para el prota

		ld	bc, 5
		ld	hl, protaDataDoor
		ldir			; Pone valores por defecto al iniciar una fase

		call	setAttribProta	; Actualiza los	atributos RAM de los sprites del prota segun sus coordenadas y sentido

		ld	a, (puertaEntrada)
		srl	a
		cp	4
		jr	nz, initDoorProta3 ; Guarda el indice de puerta	por la que se entra a la piramide
		dec	a		; Convierte numero de bit a decimal

initDoorProta3:
		ld	(ElemEnProceso), a ; Guarda el indice de puerta	por la que se entra a la piramide
		ld	a, 4		; Status
		call	getExitDat	; Obtiene un puntero al	estado de la puerta
		ld	(hl), 50h	; Estado de cerrando puerta

		pop	hl		; Puntero a la puerta
		ld	d, (hl)		; Coordenada Y central de la puerta
		inc	hl
		inc	hl
		ld	e, (hl)		; Coordenada X central de la puerta

		ld	hl, sprAttrib	; Tabla	de atributos de	los sprites en RAM (Y, X, Spr, Col)
		ld	a, 16
		add	a, e
		ld	e, a		; Suma 16 a la X de la puerta

		ld	a, d
		sub	17
		ld	d, a		; Resta	17 a la	Y de la	puerta

		ld	b, 2

initDoorProta4:
		ld	c, 2		; Son dos sprites solapados para conseguir color de fondo y de tinta

initDoorProta5:
		ld	(hl), d		; Y
		inc	hl
		ld	(hl), e		; X
		inc	hl		; El sprite ya ha sido indicado	antes mediante 'attribDoor'
		inc	hl		; El color tambien ha sido indicado por	'atribDoor'
		inc	hl		; Apunta a los atributos del siguiente sprite
		dec	c
		jr	nz, initDoorProta5 ; Siguiente sprite solapado


		ld	a, d		; Y del	primer cacho de	puerta
		add	a, 16		; Desplaza el alto del sprite (16 pixeles)
		ld	d, a
		djnz	initDoorProta4	; Pone el siguiente par	de sprites debajo del anterior

		xor	a
		ld	(statusEntrada), a ; Subestado de la puerta por	la que entra en	la piramide
		inc	a
		ld	(sentidoProta),	a ; 1 =	Izquierda, 2 = Derecha
		ret


;----------------------------------------------------
; Valores iniciales de las siguientes variables	al
; comenzar una fase
;
; Velocidad X decimales,
; Velocidad X entero,
; Velocidad X habitacion,
; Contador movimiento,
; Frame
;----------------------------------------------------
protaDataDoor:	db 0C8h, 0, 0, 1, 1


;----------------------------------------------------
; Attributos de	la puerta de entrada
; x, y,	sprite,	color
;----------------------------------------------------
attribDoor:	db 0E0h,0B0h,0D8h,   1	; Dibujo ladrillos
		db 0E0h,0B0h,0DCh,   3	; Relleno ladrillos
		db 0E0h,0B0h,0E0h,   1	; Dibujo ladrillos
		db 0E0h,0B0h,0E4h,   3	; Relleno


;----------------------------------------------------
; AI Momias
; Inteligencia de las momias
; Dependiendo del tipo de momia, estas dudan mas o menos al tomar una decision
; y van	mas rapidas o lentas por las escaleras.
; Itentan acercarse al prota y se aseguran de no aparecer por sorpresa por un lado de la pantalla cuando el prota esta cerca del borde
;----------------------------------------------------

AI_Momias:
		xor	a		; Empieza por la primera momia :)
		ld	(momiaEnProceso), a

nextMomia:
		call	getMomiaProcDat	; Obtiene puntero a la momia en	proceso
		exx
		ld	h, d
		ld	l, e
		ld	b, (hl)		; Status de la momia
		inc	hl
		ld	a, (hl)		; Sentido (1 = izquierda, 2 = derecha)
		srl	a
		srl	a
		inc	hl
		ld	(hl), a		; Controles. Dependiendo del sentido "aprieta" DERECHA o IZQUIERDA
		ld	a, b		; Estado de la momia
		exx


		ld	hl, updateMomiaAtr ; Actualiza los atributos RAM de la momia
		push	hl		; Guarda esta funcion en la pila para ejecutarla al terminar el	proceso	actual


		call	jumpIndex	; Dependiendo del estado de la momia salta a una de las	siguientes funciones


		dw momiaAnda		; 0 = Anda y comprueba si se cae o decide saltar. Al finalizar pasa al estado de pensar
		dw momiaSaltando	; 1 = Procesa salto
		dw momiaCayendo		; 2 = Momia cayendo. Al	llegar al suelo	pasa al	estado de andar
		dw momiaEscaleras	; 3 = Mueve a la momia por las escaleras y comprueba si	llega al final de las mismas
		dw momiaLimbo		; 4 = Espera un	tiempo antes de	pasar al siguiente estado (aparecer)
		dw momiaAparece		; 5 = Proceso de aparicion de la momia mediante	una nube de polvo
		dw momiaSuicida		; 6 = Anda hacia la derecha y explota
		dw momiaPiensa		; 7 = Mira a los lados y decide	como acercarse al prota
		dw momiaDesaparece

;----------------------------------------------------
; Momia	anda
; Si el	timer de la momia es 0 pasa al estado de pensar	y fija cuantas veces dudara antes de decidirse
; Cuando la momia choca	contra un muro se incrementa su	nivel de stress.
; Cada vez que consigue	andar un rato sin chocarse, el nivel de	stress disminuye.
; Cuando se estresa mucho, la momia acaba explotando.
; De esta forma	se evita que se	quede trabada en un agujero o en una ruta sin salida
;----------------------------------------------------

momiaAnda:
		ld	a, (ix+ACTOR_TIMER)
		or	a		; Esta andando?
		jr	nz, momiaAnda2	; si

		ld	(ix+ACTOR_STATUS), 7 ; Estado: Pensando
		ld	a, (ix+ACTOR_TIPO) ; Tipo de momia
		ld	de, vecesDudaMomia
		call	ADD_A_DE
		ld	a, (de)		; Segun	el tipo	de momia, duda o mira mas tiempo a los lados
		ld	(ix+ACTOR_TIMER), a ; Veces que	mira a los lados
		ret

momiaAnda2:
		ld	a, (timer)
		and	0Fh
		jr	nz, momiaAnda3

		dec	(ix+ACTOR_TIMER) ; Cada	16 iteraciones decrementa el tiempo de andar

momiaAnda3:
		pop	hl		; Saca de la pila la rutina que	actualiza los atributos	de la momia
		call	evitaSorpresa	; Evita	que una	momia aparezca por un lateral cuando el	prota esta cerca

		ld	hl, updateMomiaAtr ; Funcion que actualiza los atributos RAM del sprite	de la momia
		push	hl		; Guarda la funcion en la pila para ejecutar al	terminar el proceso

		ld	a, (ix+ACTOR_CONTROL) ;	1 = Arriba, 2 =	Abajo, 4 = Izquierda, 8	= Derecha
		bit	4, a		; Boton	A:Orden	de saltar
		jp	nz, tryToJump	; Salta	si no hay obstaculos

		push	ix		; Datos	momia
		pop	hl


		inc	hl
		push	hl		; Pointer a los	controles de la	momia
		inc	hl
		inc	hl		; Apunta a la coordenada Y
		call	chkCae		; Comprueba si tiene suelo bajo	los pies
		pop	hl
		jp	c, momiaSinSuelo ; Se va a caer	o decide saltar

		push	hl		; Puntero a los	controles (+#01)
		ld	a, 1		; Las momias no	actualizan la variable "sentidoEscalera" del prota
		ld	(modoSentEsc), a ; Si es 0 guarda en "sentidoEscalera" el tipo de escalera que se coge el prota. 0 = \, 1 = /
		call	chkCogeEsc2	; Comprueba si comienza	a subir	o bajr por una escalera
		pop	hl
		jp	z, setSentEsc	; Ha cogido unas escaleras

		call	chkChocaAndar2	; Comprueba si choca contra un muro o puerta giratoria

		push	af
		ld	a, ACTOR_STRESS	; Contador de veces que	choca (stress)
		call	getVariableMomia
		pop	af

		ld	a, (hl)		; Numero de veces que ha chocado
		jr	nc, momiaDecStress ; No	choca contra un	muro o puerta giratoria. Decrementa numero de decisiones

; La momia ha chocado con un muro
; Si el	numero de veces	que ha chocado casi consecutivamente es	9, la momia explota
; De esta forma	se evita que se	quede trabada en un agujero o en una ruta sin salida
		and	0F0h
		add	a, 1Fh		; Incrementa el	stress de la momia
		ld	(hl), a
		cp	0AFh
		jr	nz, momiaHaChocado

momiaVanish:
		ld	(ix+ACTOR_STATUS), 8 ; Estado: momia explota y desaparece
		ld	(ix+ACTOR_CONTROL), 4 ;	Va a la	izquierda
		ld	(ix+ACTOR_TIMER), 22h
		ret

momiaDecStress:
		cp	0F0h
		jr	z, momiaUpdate	; Si el	contado	de stress es 0 no lo decrementa

		ld	a, (timer)
		and	1Fh
		jr	nz, momiaUpdate	; Solo lo decrementa cada #20 iteraciones

		dec	(hl)		; Decrementa el	stress de la momia
		jr	nz, momiaUpdate	; (!?) Para que?

;----------------------------------------------------
; Actualiza la posicion	y frame	de la momia
;----------------------------------------------------

momiaUpdate:
		ld	e, (ix+ACTOR_SPEEDXDEC)
		ld	d, (ix+ACTOR_SPEED_X) ;	DE = Velocidad de la momia
		ld	a, 4		; Offset X decimal
		call	getVariableMomia ; Obtiene puntero a la	X con decimales	de la momia
		call	mueveElemento	; Actualiza sus	coordenadas al sumarle la velocidad
		call	momiaCalcFrame	; Actualiza si es necesario el frame de	la animacion
		ret

;----------------------------------------------------
; Tras chocar contra un	muro la	momia salta o se da la vuelta
; Si es	la mas tonta y se queda	entre dos muro se para a pensar
;----------------------------------------------------

momiaHaChocado:
		dec	hl
		ld	a, (hl)		; Tipo de momia
		or	a		; Es la	mas tonta? =0
		jr	nz, saltaOVuelve ; No

		call	getYMomia
		dec	hl
		ld	a, (hl)		; Sentido
		xor	3		; Invierte derecha/izquierda
		ld	b, a		; Cambia el sentido del	movimiento (la gira)
		call	chkChocaAndar4	; Tambien choca	por el otro lado?
		jr	nc, saltaOVuelve ; No choca


; La momia tonta (blanca) se queda atrapada entre dos muros

		ld	(ix+ACTOR_TIMER), 0FFh
		ld	(ix+ACTOR_STATUS), 7 ; Estado de pensar
		ret

;----------------------------------------------------
; La momia salta si puede. Si no, se da	la vuelta
;----------------------------------------------------

saltaOVuelve:
		call	getYMomia
		cp	8
		jr	c, daLaVuelta	; Esta muy arriba, da la vuelta

		call	chkSaltar	; Puede	saltar?	(No tiene nada encima ni delante)
		jp	c, momiaSetSalta ; Salta

daLaVuelta:
		ld	a, (ix+ACTOR_CONTROL) ;	1 = Arriba, 2 =	Abajo, 4 = Izquierda, 8	= Derecha
		xor	0Ch		; Cambia de direccion
		ld	(ix+ACTOR_CONTROL), a ;	1 = Arriba, 2 =	Abajo, 4 = Izquierda, 8	= Derecha
		ret

;----------------------------------------------------
; Incrementa el	contador de movimientos	y actualiza el numero de frame
;----------------------------------------------------

momiaCalcFrame:
		ld	a, 0Ah		; Offset a contador de movimientos
		call	getVariableMomia
		inc	(hl)		; Incrementa el	numero de movimientos
		jp	calcFrame2	; Actualiza el numero de frame (0-7) segun  el numero de movimientos acumulados

;----------------------------------------------------
; Guarda el sentido de las escaleras dentro de la estructura de	la momia
; In:
;   C =	tile mapa (escaleras)
;----------------------------------------------------

setSentEsc:
		ld	a, (ix+ACTOR_CONTROL) ;	1 = Arriba, 2 =	Abajo, 4 = Izquierda, 8	= Derecha
		rra			; Pasa control ARRIBA al carry
		ld	a, c
		ld	b, 8		; Control: DERECHA
		jr	nc, setSentEsc2	; No tiene ARRIBA apretado

		ld	b, 4		; Control: IZQUIERDA
		xor	1

setSentEsc2:
		and	1
		ld	(ix+ACTOR_SENT_ESC), a ; Sentido en el que van las escaleras. 0	= \  1 = /
		and	a
		ld	a, b
		jr	z, setSentEsc3
		xor	0Ch		; Cambia sentido del movimiento

setSentEsc3:
		ld	(ix+ACTOR_CONTROL), a ;	1 = Arriba, 2 =	Abajo, 4 = Izquierda, 8	= Derecha
		ret

;----------------------------------------------------
; Numero de veces que duda (mira a los lados) cada momia
; cuando esta decidiendo el siguiente movimiento
;----------------------------------------------------
vecesDudaMomia:	db    3
		db    3
		db    0
		db    0
		db    3


;----------------------------------------------------
; Actualiza los	atributos RAM de una momia
; Su posicion y	frame. La oculta si esta en otra habitacion
;----------------------------------------------------

updateMomiaAtr:
		ld	c, (ix+ACTOR_Y)
		ld	b, (ix+ACTOR_X)
		call	getMomiaAtrib

		ld	a, (ProtaRoom)	; Parte	alta de	la coordenada X. Indica	la habitacion de la piramide
		cp	(ix+ACTOR_ROOM)
		jr	nz, hideMomia	; No estan en la misma habitacion

		dec	c
		dec	c		; Y = Y	- 2
		ld	a, (ix+ACTOR_FRAME)
		push	af
		rra			; Si el	frame es par, mueve la momia un	poco hacia arriba
		jr	c, updateMomiaAt2
		inc	c

updateMomiaAt2:
		pop	af
		ld	de, framesMomia
		call	ADD_A_DE
		ld	a, (de)
		ld	d, a		; Frame
		ld	(hl), c		; Coordenada Y
		inc	hl
		ld	(hl), b		; Coordenada X
		inc	hl
		ld	a, (ix+ACTOR_SENTIDO) ;	1 = Izquierda, 2 = Derecha
		rra
		ld	a, d
		jr	nc, setFrameMomia
		add	a, 60h		; Desplazamiento a sprites invertidos

setFrameMomia:
		ld	(hl), a
		jr	chkLastMomia	; Comprueba si faltan momias por procesar

hideMomia:
		ld	(hl), 0E0h	; Oculta el sprite (Y =	#E0)

chkLastMomia:
		ld	hl, momiaEnProceso ; Comprueba si faltan momias	por procesar
		inc	(hl)
		ld	a, (hl)
		dec	hl
		cp	(hl)		; Ha procesado todas las momias?
		ret	nc		; Si, termina
		jp	nextMomia

framesMomia:	db 2Ch			; Pie atras
		db 28h			; Pies juntos
		db 30h			; Pies separados
		db 2Ch			; Pie atras
		db 28h			; Pies juntos
		db 30h			; Pies separados
		db 28h			; Pies juntos
		db 30h			; Pies eparados
		db 0E8h			; Nube grande
		db 0ECh			; Nube pequeña
		db 0D4h			; Destello

;----------------------------------------------------
; Intenta saltar
; Salta	si no esta muy arriba y	no hay obstaculos
;----------------------------------------------------

tryToJump:
		call	getYMomia
		ld	a, (hl)
		cp	8
		ret	c
		call	chkSaltar
		ret	nc


;----------------------------------------------------
; Pone estado de salto
; Guarda puntero a los valores de desplazamientos Y del	salto
;----------------------------------------------------

momiaSetSalta:
		push	ix
		pop	hl		; Datos	momia

Salta:	
		ld	(hl), 1		; Status = Saltar
		inc	hl
		res	4, (hl)		; Quita	"Boton A" del estado de las teclas del elemento

		ld	a, 0Ah
		call	ADD_A_HL
		ld	(hl), 2		; Frame	2 = Piernas separadas
		inc	hl
		ld	de, valoresSalto
		ld	(hl), e
		inc	hl
		ld	(hl), d		; Guarda puntero a los valores del salto

		inc	hl
		ld	(hl), 0		; Salto	subiendo (1 = cayendo)
		ret

;----------------------------------------------------
; Momia	saltando
; Actualiza las	coordenadas de la momia	y comprueba si choca
; contra algo para quitar el estado de salto y
; poner	el de andar o caida.
;----------------------------------------------------

momiaSaltando:
		call	getYMomia	; Obtiene puntero a los	datos de la momia
		dec	hl
		push	hl
		push	ix
		call	doSalto		; Procesa el salto

		pop	ix
		pop	hl
		call	chkPasaRoom	; Comprueba si pasa a otra habitacion
		push	ix
		pop	hl		; Puntero a estructura de la momia

	IF	(VERSION2)
		inc	hl
		xor	a
		cp	1
		call	chkChocaSalto1
	ELSE
		call	chkChocaSalto	; Choca	con algo al saltar?
	ENDIF
		jr	z, momiaCayendo	; Si, quita estado de salto y pone el de caida (si no hay suelo) o de andar (si	hay suelo)
		ret


;----------------------------------------------------
; Comprueba si el elemento llega a los limites de la pantalla
; y pasa de habitacion
; Out:
;   Z =	Pasa a otra habitacion
;  NZ =	No pasa
;----------------------------------------------------

chkPasaRoom:
		ld	a, (hl)		; Sentido
		inc	hl
		inc	hl
		inc	hl		; Apunta a la X
		ld	b, 0		; Limite izquierdo = 0
		rra			; Derecha o izquierda?
		jr	nc, chkPasaRoom2
		dec	b		; Limite derecho = 255

chkPasaRoom2:
		ld	a, b		; Limite
		cp	(hl)		; Lo compara con la X del elemento
		inc	hl
		ret	nz		; No ha	llegado	al limite de la	habitacion

		inc	(hl)		; Pasa a la habitacion de la derecha
		and	a
		ret	z

		dec	(hl)
		dec	(hl)		; Pasa a la habitacion de la izquierda
		ret

;----------------------------------------------------
; Cuando la momia llega	al borde de una	plataforma
; puede	saltar o dejarse caer
;----------------------------------------------------

momiaSinSuelo:
		ld	a, (ix+ACTOR_TIPO)
		and	a
		jr	z, momiaCayendo	; Momia	mas tonta. Nunca salta

		cp	3
		jr	z, momiaCayendo

		ld	a, (ix+ACTOR_POS_RELAT)	; 0 = A	la misma altura	(o casi), 1 = Momia por	encima,	2 = Por	debajo
		cp	1		; La momia esta	por encima del prota?
		jr	z, momiaCayendo	; Si, se deja caer para	bajar

		call	getYMomia	; Obtiene la Y de la momia
		ld	a, (hl)		; (!?) No hace falta
		cp	8		; Esta muy cerca de la parte de	arriba?
		jr	c, momiaCayendo	; No salta

; Va a saltar
		call	chkSaltar	; Tiene	espacio	para saltar?
		jp	c, momiaSetSalta ; si, salta


;----------------------------------------------------
; Procesa la caida de la momia y comprueba si llega al suelo
; Al llegar al suelo pone el estado de andar
;----------------------------------------------------


momiaCayendo:
		push	ix
		pop	hl
		call	cayendo		; Incrementa la	Y y comprueba si choca contra el suelo
		jp	nc, setMomiaAndar ; No esta cayendo, pone estado de andar
		ret

momiaEscaleras:
		push	ix
		pop	hl
		inc	hl
		ld	a, (hl)		; Controles
		and	0Ch
		ret	z		; No va	ni a la	derecha	ni a la	izquierda

		ld	a, (ix+ACTOR_TIPO)
		ld	de, pausaEscalera
		call	ADD_A_DE
		ld	a, (de)		; Masca	aplicada al timer para ralentizar el movimiento	de la momia en la escalera
		ld	b, a
		ld	a, 1
		ld	(quienEscalera), a ; (!?) Se usa esto? Quien esta en una escalera 0 = Prota. 1 = Momia
		ld	(quienEscalera), a ; (!?) Para que lo pone dos veces?
		call	andaEscalera
		jr	z, setMomiaPensar ; Ha llegado al final	de la escalera
		call	momiaCalcFrame
		ret

setMomiaPensar:
		ld	(ix+ACTOR_TIMER), 0 ; Al poner el timer	a 0 y el estado	de andar se consigue pasar al estado de	pensar en la siguiente iteracion

setMomiaAndar:
		xor	a
		jr	setMomiaStatus



		ld	a, 3		; (!?) Este codigo no se ejecuta nunca!

setMomiaStatus:
		ld	(ix+ACTOR_STATUS), a
		ret

;----------------------------------------------------
; Frames que los tipos de momia	se paran en cada paso
; que dan por las escaleras
; 0 = Muy rapido, 3 = lento
;----------------------------------------------------
pausaEscalera:	db    3
		db    0
		db    1
		db    0
		db    3

;----------------------------------------------------
; Estado por defecto de	la momia al empezar una	partida
; Espera un tiempo antes de aparecer
; El timer vale	#10 para que no	aparezca nada mas empezar
;----------------------------------------------------

momiaLimbo:
		pop	hl		; Saca de la pila la funcion que actualiza los atributos de la momia (no es visible)
		ld	a, (timer)
		and	1
		jp	nz, chkLastMomia ; Procesa solo	una de cada dos	iteraciones

		dec	(ix+ACTOR_TIMER)
		jp	nz, chkLastMomia ; Aun falta tiempo para que aparezca

		inc	(ix+ACTOR_STATUS) ; Siguiente estado de	la momia: Aparece
		ld	(ix+ACTOR_TIMER), 82h

		ld	a, 87h		; SFX aparece momia
		call	setMusic
		jp	chkLastMomia	; Comprueba si faltan momias por procesar

;----------------------------------------------------
; Proceso de aparicion de una momia
; Decrementa el	tiempo de aparicion. Al	llegar al final	pasa al	estado 0
; Si faltan menos de 8 iteraciones muestra la momia con	las piernas abiertas mirando a la izquierda
; Cada 32 frames anima la nube que indica que va a aparecer una	momia
;----------------------------------------------------

momiaAparece:
		ld	(ix+ACTOR_CONTROL), 8 ;	Mirando	a la derecha
		dec	(ix+ACTOR_TIMER) ; Decrementa el tiempo	de aparicion
		jp	z, setMomiaViva	; Ha llegado al	final

		ld	a, (ix+ACTOR_TIMER)
		cp	7		; Falta	poco para que vuelva a la vida?
		jr	c, momiaOpenLegs ; Muestra la momia con	las piernas separadas

		ld	b, a
		and	1Fh
		ret	nz		; No han pasado	32 iteraciones

		bit	5, b
		ld	a, 8		; Frame	nube grande
		jr	z, setMomiaFrame

		inc	a		; Frame	nube pequeña

setMomiaFrame:
		ld	(ix+ACTOR_FRAME), a
		ret

setMomiaViva:
		call	setMomiaAndar

momiaOpenLegs:
		ld	(ix+ACTOR_FRAME), 2 ; Piernas separadas
		ret

momiaSuicida:
		ld	(ix+ACTOR_CONTROL), 8 ;	1 = Arriba, 2 =	Abajo, 4 = Izquierda, 8	= Derecha
		dec	(ix+ACTOR_TIMER)
		ld	a, (ix+ACTOR_TIMER)
		ld	b, a		; (!?) Donde se	unsa B?
		jr	z, mataMomia
		and	1Fh
		ret	nz

		ld	a, 0Ah		; Frame	destello desaparecer
		ld	(ix+ACTOR_FRAME), a
		ret

mataMomia:
		call	quitaMomia
		pop	hl
		jp	chkLastMomia	; Comprueba si faltan momias por procesar


;----------------------------------------------------
; Manda	una momia al limbo.
; Quita	su sprite de la	pantalla.
; Tras explotar	una momia se va	al limbo un rato
;----------------------------------------------------

quitaMomia:
		call	getMomiaAtrib
		ld	(hl), 0E0h	; Y = #E0. Quita momia de la pantalla
		ld	(ix+ACTOR_STATUS), 4 ; Limbo
		ld	(ix+ACTOR_TIMER), 80h
		ld	(ix+ACTOR_FRAME), 9
		ret

;----------------------------------------------------
; Obtiene un puntero a los atributos RAM de la momia en	proceso
; HL = Puntero
;----------------------------------------------------

getMomiaAtrib:
		ld	a, (momiaEnProceso)
		ld	hl, enemyAttrib

getMomiaAtrib2:
		add	a, a
		add	a, a
		jp	ADD_A_HL

getYMomia:
		ld	a, 3		; Coordenada Y

;----------------------------------------------------
; Devuelve el valor A de la estructura de la momia actual
; In: A	= Valor	a leer
; Out: A = Valor leido
;----------------------------------------------------

getVariableMomia:
		ld	hl, (pMomiaProceso) ; Puntero a	los datos de la	momia en proceso
		call	ADD_A_HL
		ld	a, (hl)
		ret


;----------------------------------------------------
; La momia piensa que hacer
; Mira a los lados tantas veces	como vale TIMER
; In:
;    IX	= Datos	momia
;----------------------------------------------------

momiaPiensa:
		ld	a, (ix+ACTOR_TIMER) ; Veces que	duda
		or	a
		jr	z, momiaPiensa2	; Ya se	lo ha pensado

		cp	0E0h
		jr	z, momiaUnknown

		ld	(ix+ACTOR_FRAME), 2 ; Frame piernas separadas
		and	3
		ld	(ix+ACTOR_SENTIDO), a ;	Sentido	en el que mira

		ld	a, (timer)
		and	1Fh
		ret	nz		; Permanece 32 frames en esa postura

		dec	(ix+ACTOR_TIMER) ; Decrementa las veces	que mira a los lados
		ret	nz		; Aun tiene que	pensarselo un poco mas

momiaPiensa2:
		call	momiaDecide	; Toma una decision para acercarse al prota
		ld	(ix+ACTOR_STATUS), 0 ; Estado: andar
		ret

; (!?) Para que	sirve esto?

momiaUnknown:
		ld	a, (ix+ACTOR_CONTROL) ;	1 = Arriba, 2 =	Abajo, 4 = Izquierda, 8	= Derecha
		xor	1100b
		ld	(ix+ACTOR_CONTROL), a ;	Invierte el sentido de la momia
		rra
		rra
		and	3
		ld	(ix+ACTOR_SENTIDO), a ;	1 = Izquierda, 2 = Derecha

		call	getYMomia
		ld	bc, 0FCh	; X+15,Y+12
		call	getMapOffset	; Obtiene en HL	la direccion del mapa que corresponde a	las coordenadas
		ld	b, a		; (!?) Guarda el tile del mapa en B. Para que?
		and	0F0h		; Se queda con la familia o tipo de tile
		cp	10h
		jp	nz, tryToJump	; Salta	si no hay un muro/plataforma en	su parte inferior derecha

		call	getYMomia
		ld	bc, 10FCh	; X+16,	Y-4
		call	getMapOffset	; Obtiene en HL	la direccion del mapa que corresponde a	las coordenadas
		ld	b, a		; (!?) Para que	lo guarda en B?
		and	0F0h
		cp	10h
		jp	nz, tryToJump	; salta	si no hay un muro/plataforma en	su parte superior derecha
		jp	momiaVanish

momiaDesaparece:
		ld	(ix+ACTOR_CONTROL), 8 ;	Anda a la derecha

		dec	(ix+ACTOR_TIMER) ; Decrementa el tiempo	de exploxion

		ld	a, (ix+ACTOR_TIMER)
		ld	b, a
		jr	z, quitaACTOR_	; Ha terminado el tiempo. La momia desaparece

		and	1Fh
		ret	nz		; No es	multiplo de #20

		ld	(ix+ACTOR_FRAME), 0Ah ;	Destello desaparece
		ret

quitaACTOR_:
		call	quitaMomia	; Quita	el sprite de la	pantalla y manda la momia al limbo (estado 4)
		ld	(ix+ACTOR_TIMER), 0FFh
		call	initMomia
		pop	hl
		jp	chkLastMomia	; Comprueba si faltan momias por procesar


;----------------------------------------------------
; Evita	que una	momia aparezca por un lateral cuando el	prota esta cerca
; Si una momia se encuentra cerca del lateral de una
; habitacion contigua, y el prota esta en el lateral adyacente
; se cambia el sentido de la momia para	que no aparezca	'por sorpresa'
; y sin	tiempo a reaccionar para poder esquivarla
;----------------------------------------------------

evitaSorpresa:
		exx			; DE = Puntero estructura momia
		ld	hl, 6		; Offset a la variable 'room'
		add	hl, de
		ld	a, (ProtaRoom)	; Parte	alta de	la coordenada X. Indica	la habitacion de la piramide
		ld	b, (hl)		; B = Habitacion momia
		cp	(hl)		; Comprueba si la momia	esta en	la habitacion actual
		jr	z, evitaSorpresa6 ; si

		dec	hl
		ld	a, (hl)		; X momia
		ld	c, 50h
		cp	c
		jr	c, evitaSorpresa2 ; La X de la momia es	menor de #50

		ld	c, 0B0h
		cp	c
		jr	c, evitaSorpresa6 ; La X de la momia es	menor de #B0. No se encuentra cerca de los bordes laterales

		inc	b
		inc	b

evitaSorpresa2:
		dec	b
		ld	a, (ProtaRoom)	; Parte	alta de	la coordenada X. Indica	la habitacion de la piramide
		cp	b		; Se encuentra en el lateral cercano a la habitacion en	la que esta el prota?
		jr	nz, evitaSorpresa6 ; No

		xor	a
		sub	c
		ld	c, a
		cp	50h
		ld	a, (ProtaX)
		jr	z, evitaSorpresa5

		cp	c
		jr	c, evitaSorpresa6

evitaSorpresa3:
		inc	hl
		ld	a, (ProtaRoom)	; Parte	alta de	la coordenada X. Indica	la habitacion de la piramide
		cp	(hl)		; Habitacion de	la momia
		ld	a, 8		; Cambia el sentido hacia la derecha
		jr	c, evitaSorpresa4

		ld	a, 4		; Cambia el sentido hacia la izquierda

evitaSorpresa4:
		ld	h, d
		ld	l, e		; Puntero a la estructura de la	momia
		inc	hl
		ld	(hl), a		; Sentido en el	que anda la momia
		exx
		ret

evitaSorpresa5:
		cp	c
		jr	c, evitaSorpresa3

evitaSorpresa6:
		exx
		ret


;----------------------------------------------------
; La momia toma	una decision
; Busca	al prota y se mueve hacia el
;----------------------------------------------------

momiaDecide:
		ld	a, 5
		ld	(ix+ACTOR_TIMER), a

		call	buscaCercanias	; Mira si hay escaleras	para subir o bajar en las cercanias (5 tiles a cada lado)
		call	buscaProta	; Comprueba la posicion	de la momia relativa al	prota
		and	a
		jr	z, momiaDecide2	; A la misma altura

		dec	a
		jr	z, setOrdenBajar ; La momia esta por encima

		dec	a
		jr	z, setOrdenSubir ; La momia esta por debajo

momiaDecide2:
		ld	a, (ProtaRoom)	; Parte	alta de	la coordenada X. Indica	la habitacion de la piramide
		cp	(ix+ACTOR_ROOM)
		jr	nz, momiaDecide3 ; estan en habitaciones distintas

		ld	a, (ProtaX)
		cp	(ix+ACTOR_X)	; Compara la X del prota con la	X de la	momia

momiaDecide3:
		ld	a, 8		; Control: Anda	a la DERECHA
		jr	nc, momiaDecide4 ; El prota esta a la derecha

		ld	a, 4		; Control: anda	a la IZQUIERDA

momiaDecide4:
		ld	(ix+ACTOR_CONTROL), a ;	Fija la	direccion que debe seguir la momia para	acercarse al prota

		ld	c, a
		ld	hl, ProtaY
		call	getMapOffset00	; Obtiene puntero a la posicion	del mapa del prota
		ex	de, hl
		call	getYMomia
		call	getMapOffset00	; Obtiene puntero a la posicion	del mapa de la momia


; Comprueba si entre la	momia y	el prota hay algun obstaculo
; De ser asi, intentara	subir o	bajar de donde se encuentra

		ld	b, 20h		; Ancho	de la habitacion

momiaDecide5:
		and	a
		push	hl		; Mapa momia
		sbc	hl, de
		pop	hl
		ret	z		; Ha llegado a la posicion del prota en	la busqueda

		ld	a, (hl)		; Tipo de tile
		and	0F0h		; Se queda con la familia
		cp	10h		; Es una plataforma o muro?
		jr	z, momiaDecide7	; Si

		dec	hl		; Tile de la izquierda del mapa
		bit	2, c		; Sentido en el	que se mueve la	momia
		jr	nz, momiaDecide6 ; Va a	la izquierda

		inc	hl
		inc	hl		; Tile de la derecha

momiaDecide6:
		djnz	momiaDecide5
		ret

momiaDecide7:
		ld	a, i		; Valor	aleatorio
		rra
		or	c		; Sentido en el	que se mueve la	momia
		rra
		call	c, setOrdenSubir

setOrdenBajar:
		ld	hl, ordenBajar
		ld	a, (hl)		; Se mueve hacia la escaleras mas lejanas (dentro del radio de busqueda) que bajan
		and	a

momiaSetControl:
		ret	z
		ld	(ix+ACTOR_CONTROL), a ;	1 = Arriba, 2 =	Abajo, 4 = Izquierda, 8	= Derecha
		ret

setOrdenSubir:
		ld	hl, ordenSubir
		ld	a, (hl)		; Controles para dirigirse a la	escalera mas lejana (dentro del	radio de busqueda) que sube
		and	a
		jr	momiaSetControl


;----------------------------------------------------
; Calcula la posicion relativa de la momia respecto al prota
; Out: A y B
;   0 =	Estan casi a la	misma altura
;   1 =	La momia esta por encima
;   2 =	La momia esta por debajo
;----------------------------------------------------

buscaProta:
		ld	b, 0
		ld	de, ProtaY
		call	getYMomia	; Obtiene la Y de la momia
		ld	a, (protaStatus) ; 0 = Normal
					; 1 = Salto
					; 2 = Cayendo
					; 3 = Escaleras
					; 4 = Lanzando un cuhillo
					; 5 = Picando
					; 6 = Pasando por un apuerta giratoria
		cp	3		; Escaleras?
		jr	z, buscaProta2

		ld	a, (de)		; Y del	prota
		sub	(hl)		; Le resta la Y	de la momia
		ld	c, a
		sub	10
		add	a, 18
		jr	c, buscaProta3	; Estan	casi a la misma	altura

buscaProta2:
		inc	b
		ld	a, (de)		; Y del	prota
		sub	(hl)		; Y de la momia
		jr	nc, buscaProta3	; La momia esta	por encima
		inc	b		; La momia esta	por debajo

buscaProta3:
		ld	a, b
		ld	(ix+ACTOR_POS_RELAT), a	; 0 = A	la misma altura	(o casi), 1 = Momia por	encima,	2 = Por	debajo
		ret


;----------------------------------------------------
; Busca	en las cercanias de la momia para ver si hay
; escaleras que	suben, bajan o un muro
; Dependiendo de lo que	encuentre guardara las ordenes de subir	o bajar
;----------------------------------------------------

buscaCercanias:
		ld	b, 4
		ld	hl, ordenSubir

buscaCercanias2:
		ld	(hl), 0
		inc	hl
		djnz	buscaCercanias2	; Borra	ordenes	de subir o bajar anteriores

		push	ix		; Datos	momia
		pop	hl

		inc	hl
		ex	af, af'
		ld	a, (hl)		; Controles: Sentido en	el que va
		ex	af, af'

		inc	hl
		inc	hl
		push	hl		; Y
		call	buscaCercanias3	; Busca	primero	en el sentido actual
		pop	hl
		ex	af, af'
		xor	0Ch		; Invierte sentido para	buscar en el contrario al que va
		ex	af, af'

buscaCercanias3:
		call	getYMomia
		ld	bc, 8		; (!?) Con poner 'ld c,8' bastaria
		ld	b, c		; Punto	central	de la momia
		call	getMapOffset	; Obtiene en HL	la direccion del mapa que corresponde a	las coordenadas

		ex	af, af'
		dec	hl		; Tile a la izquierda de la momia
		bit	2, a		; Va a la izquierda?
		jr	nz, buscaCercanias4 ; Si, va a la izquierda

		inc	hl
		inc	hl		; Tile a la derecha de la momia

buscaCercanias4:
		ex	af, af'
		ld	b, 0		; contador de desplazamientos X	en la busqueda

buscaCercanias5:
		ex	af, af'
		dec	hl		; desplaza la busqueda un tile a la izquierda
		bit	2, a		; Va a la izquierda?
		jr	nz, buscaCercanias6 ; si, va a la izquierda

		inc	hl
		inc	hl		; desplaza la busqueda un tile a la derecha

buscaCercanias6:
		ex	af, af'
		ld	a, (hl)		; tile del mapa
		and	0F0h		; se queda con la familia o tipo de tile
		cp	10h		; es un	muro o plataforma?
		ret	z		; si

		cp	20h		; Es una escalera?
		jr	z, buscaCercanias7 ; Ha	encontrado una escalera

		cp	30h		; Es un	cuchillo?
		jr	nz, buscaCercanias8

		ld	a, (hl)
		cp	30h		; Es un	cuchillo clavado en el suelo?
		jr	z, buscaCercanias8

buscaCercanias7:
		ld	c, 1		; Orden	subir
		ld	de, distSubida
		call	guardaOrden

buscaCercanias8:
		push	hl
		ld	a, 60h		; Ancho	de las 3 habitaciones
		call	ADD_A_HL	; Apunta a la fila inferior (yTile+1)
		ld	a, (hl)		; lee el tile del mapa
		ld	c, a
		pop	hl
		and	0F0h		; Se queda con el tipo de tile
		jr	z, momiaBaja	; Esta vacio

		ld	a, c		; Tile del mapa
		and	0Fh
		cp	5		; Escaleras que	bajan?
		call	nc, momiaBaja	; Si, da orden de bajar

		inc	b
		ld	a, 5
		cp	b		; Ha buscado ya	5 posiciones en	una direccion?
		jr	nz, buscaCercanias5
		ret

momiaBaja:
		ld	c, 2		; Orden	bajar
		ld	de, distBajada

guardaOrden:
		ld	a, (de)
		cp	b
		ret	nc		; La orden existente tiene mas prioridad (va a las escaleras mas lejanas?)

		ld	a, b
		ld	(de), a		; Distancia a las escaleras
		dec	de
		ex	af, af'
		push	af
		and	0FCh		; Mantiene el sentido de la busqueda
		or	c		; Añade	orden de subir o bajar
		ld	(de), a		; Guarda la orden
		pop	af
		ex	af, af'
		ret

;----------------------------------------------------
; Obtiene datos	de la momia en proceso
; Out:
; IX = Datos momia
; (pMomiaData) = Puntero datos momia
;----------------------------------------------------

getMomiaProcDat:
		ld	hl, momiaEnProceso
		ld	a, (hl)

getMomiaDat:
		ld	b, a
		sla	b
		ld	a, b
		sla	b
		add	a, b
		sla	b
		sla	b
		add	a, b		; x22
		exx
		ld	hl, momiaDat	; Estructuras de las momias
		call	ADD_A_HL
		push	hl
		ld	(pMomiaProceso), hl ; Puntero a	los datos de la	momia en proceso
		pop	ix
		ex	de, hl
		exx
		ret


;----------------------------------------------------
;
; Actualiza las	coordenadas de un elemento segun su velocidad X
; In:
;  DE =	velocida. D = Parte entera, E =	Parte decimal
; Out:
;  A,D = Coordenada X
;  E = Decimales X
;----------------------------------------------------


mueveProta:
		ld	hl, ProtaXdecimal ; 'Decimales' usados en el calculo de la X. Asi se consiguen velocidades menores a 1 pixel
		ld	de, (protaSpeed) ; El byte bajo	indica la parte	"decimal" y el alto la entera

mueveElemento:
		push	ix
		push	hl
		push	hl
		ld	a, (hl)
		inc	hl
		ld	h, (hl)
		ld	l, a
		pop	ix
		ld	b, (ix+2)	; Habitacion
		ld	c, (ix+5)	; Desplazamiento habitacion
		ld	a, (ix-2)	; Sentido del movimiento
		rra
		jr	nc, mueveElemento2 ; Va	hacia la derecha
		ld	a, c
		cpl
		ld	c, a
		ld	a, d
		cpl
		ld	d, a
		ld	a, e
		cpl
		ld	e, a
		inc	de

mueveElemento2:
		add	hl, de		; Suma desplazamiento
		ld	a, b		; Habitacion actual
		adc	a, c		; Suma desplazamiento X	alto, por si ha	cambiado de habitacion
		ld	b, a
		ld	a, (ix+1)	; Coordenada X
		ex	de, hl
		pop	hl
		ld	(hl), e		; X decimales
		inc	hl
		ld	(hl), d		; X
		ld	(ix+2),	b	; Room
		pop	ix
		ret


;----------------------------------------------------
; Comprueba si puede realizar un salto mirando si hay
; techo	sobre el elemento, si el salto es solamente vertical
; Si es	con desplazamiento, comprueba si tienen	un muro	delante
; (y si	el techo es mazizo?)
; Out:
;   NC = No puede saltar
;----------------------------------------------------

chkSaltar:
		push	hl
		dec	hl
		dec	hl
		ld	a, (hl)		; Controles del	elemento
		pop	hl
		cp	10h		; Salto	vertical sin desplazamiento lateral?
		jr	z, chkChocaTecho ; Si, solo comprueba que no tenga techo sobre la cabeza

;---------------------------------------
; El salto es con desplazamiento lateral
; Comprueba si tiene un	muro delante
;---------------------------------------
		call	chkChocaTecho
		ret	nc		; Ha chocado

		dec	hl
		ld	a, (hl)		; Sentido
		inc	hl
		ld	bc, 304h	; Offset para la parte superior	izquierda
		rr	a
		jr	c, chkIncrustUp	; Izquierda

		ld	b, 0Ch		; Offset X parte derecha

chkIncrustUp:
		push	bc
		call	chkTocaMuro	; Z = choca
		pop	bc		; Recupera offset coordendas de	choque
		jr	z, chkTechoMazizo ; Ha chocado

		call	chkTocaY_8	; Decrementa en	8 el offset Y y	comprueba si choca
		ret	z

		scf
		ret

chkTechoMazizo:
		call	chkTocaY_8	; Decrementa en	8 el offset Y y	comprueba si choca
		ret	z		; Choca

		call	chkTocaY_8	; Decrementa en	8 el offset Y y	comprueba si choca
		ret	z		; Choca

		ld	b, 8		; Parte	central	X del elemento
		call	chkTocaMuro	; Z = choca
		ret	z		; Choca

		scf			; No choca
		ret

;----------------------------------------------------
; Comprueba si choca mientras salta
; Out: Carry = No choca
;----------------------------------------------------

chkChocaTecho:
		ld	bc, 4FEh
		call	chkTocaMuro	; Z = choca
		ret	z

		ld	bc, 0AFEh
		call	chkTocaMuro	; Z = choca
		ret	z

		scf			; No choca
		ret

chkTocaY_8:
		ld	a, c		; Decrementa en	8 el offset Y y	comprueba si choca
		sub	8
		ld	c, a
		push	bc
		call	chkTocaMuro	; Z = choca
		pop	bc
		ret


;----------------------------------------------------
; Comprueba si choca con algo mientras salta, ya sea mientras
; sube o mientras cae
; Out:
;   Z =	Ha chocado con algo al saltar. Termina el salto
;----------------------------------------------------

chkChocaSalto:
		inc	hl
		ld	a, (sentidoEscalera) ; Valor de	los controles en el momento del	salto. Así se sabe si fue un salto vertical
		cp	10h		; Boton	A apretado? (Hold jump)
chkChocaSalto1:
		inc	hl
		ld	d, (hl)		; Sentido
		inc	hl
		jr	z, chkChocaCae	; Esta apretado.

		ld	a, (ix+ACTOR_X)
		and	7
		cp	4		; Esta en medio	de un tile?
		jr	nz, chkChocaCae	; No

;------------------------------
; Comprueba si choca por arriba
;------------------------------
		ld	a, d		; Sentido
		rra
		ld	bc, 300h	; Offset superior izquierdo
		jr	c, chkChocaSalto2 ; Va a la izquierda
		ld	b, 0Ch		; Offset derecho

chkChocaSalto2:
		push	de
		call	chkTocaMuro	; Z = choca
		pop	de
		jr	z, ajustaPasillo ; Comprueba si	se ha encajado en un pasillo (muro por arriba y	por abajo)

;----------------------------------------
; Comprueba si choca con la parte central
;----------------------------------------

chkChocaSalto3:
		ld	a, d		; Sentido
		ld	bc, 308h	; Offset central izquierdo
		rra
		jr	c, chkChocaSalto4 ; Va a la izquierda
		ld	b, 0Ch		; Offset derecho

chkChocaSalto4:
		push	de
		call	chkTocaMuro	; Conca	con la parte central?
		pop	de
		jr	z, setFinSalto	; Si, termina el salto

;------------------------------------------
; Comprueba si choca con la parte de abajo
;------------------------------------------

		ld	a, d		; Sentido
		rra
		ld	bc, 30Eh	; Offset inferior izquierdo
		jr	c, chkChocaSalto5 ; Va a la izquierda
		ld	b, 0Ch		; Derecho

chkChocaSalto5:
		call	chkTocaMuro	; Z = choca
		jr	z, setFinSalto	; Si, termina el salto

chkChocaCae:
		ld	a, (ix+ACTOR_JUMPSENT) ; 0 = Subiendo, 1 = Cayendo
		and	a		; Esta subiendo	o cayendo?
		jr	z, setNZ	; Subiendo

		call	chkChocaSuelo	; Comprueba si choca con el suelo mientras cae
		jp	c, chkLlegaSuelo ; No ha chocado

setFinSalto:
		ld	a, (hl)		; Y
		and	0F8h
		ld	(hl), a		; Ajusta la coordenada Y a multiplo de 8 descartando los valores menores de 8

		xor	a
		and	a		; Set Z, fin del salto
		ret

; Comprueba si ha llegado al nivel del suelo

chkLlegaSuelo:
		call	chkPisaSuelo
		jr	z, setFinSalto	; Si, esta en el suelo

setNZ:	
		xor	a
		cp	1		; Set NZ
		ret

;----------------------------------------------------
; Se llama a esta funcion si al	saltar ha chocado con algo por la parte	superior
; Comprueba si bajo los	pies hay suelo y ajusta	la Y en	ese caso
;----------------------------------------------------

ajustaPasillo:
		ld	a, d		; Sentido
		ld	bc, 314h	; Offset medio tile por	debajo del elemento (izquierda)
		rra
		jr	c, ajustaPasillo2
		ld	b, 0Ch		; Derecha

ajustaPasillo2:
		push	de
		call	chkTocaMuro	; Z = choca
		pop	de
		jr	z, setFinSalto	; Y

		jr	chkChocaSalto3


;----------------------------------------------------
; Salto
; Si se	esta ejecutando	el ending, los valores del salto se multiplican	x4
; Dependiendo de la direccion que este pulsada,	salta a	la derecha o a la izquierda
; Recorre la tabla de desplazamientos hasta llegar al final. Entonces
; indica que hay que recorrerla	al reves para caer de la misma forma que se subio
; Si llega al final nuevamente (inicio), cae a velocidad maxima	y continua asi
;----------------------------------------------------

doSalto:
		ld	a, (GameStatus)
		cp	0Ah		; Status = Final del juego (ending)?
		jr	z, doSalto2	; Si, esta en el final del juego

		xor	a		; No esta en el	final del juego.
		ld	(waitCounter), a ; Lo pone a cero para no multiplicar los calores del salto x4

doSalto2:
		push	hl
		push	hl
		ld	a, 0Ah
		call	ADD_A_HL
		ld	e, (hl)
		inc	hl
		ld	d, (hl)		; DE = Puntero a los desplazamientos del salto
		inc	hl
		ld	b, (hl)		; Sentido del salto: Subiendo o	bajando?
		pop	hl
		pop	ix
		dec	hl

		ld	a, (hl)		; Teclas pulsadas
		inc	hl
		inc	hl
		inc	hl
		inc	hl
		and	0Ch		; Se queda solo	con derecha e izquierda
		jr	z, doSalto3

		dec	(hl)		; Decrementa la	X
		bit	2, a		; Izquierda = 4
		jr	nz, doSalto3

		inc	(hl)		; Derecha = 8
		inc	(hl)		; Incrementa la	X

doSalto3:
		ld	a, (de)		; Desplazamiento Y del salto
		inc	a		; Ha llegado al	final de la tabla?
		jr	z, saltoCaeMax	; Si, cae a la maxima velocidad

		dec	a		; Restaura el valor de desplazamiento
		ld	c, a		; Lo guarda en C

		ld	a, (waitCounter)
		dec	a
		dec	a
		ld	a, c
		jr	nz, chkSaltoSubBaj ; Salta si waitCounter no es	2

		add	a, a
		add	a, a		; Multiplica el	desplazamiento x4

chkSaltoSubBaj:
		dec	b
		inc	b		; Sube o cae?
		jr	nz, saltoUpdate	; Sube
		neg			; Cae, asi que pasa el valor a negativo

saltoUpdate:
		call	saltoUpdateY	; Actualiza la coordenada Y del	elemento que esta saltando
		inc	de		; Siguiente posicion de	la lista de desplazamientos

		ld	a, b		; Sentido del salto
		and	a		; Sube o cae?
		jr	z, saltoUpdate3	; Sube

		dec	de		; Recorre la lista hacia atras

saltoUpdate2:
		dec	de

saltoUpdate3:
		ld	(ix+0Ah), e
		ld	(ix+0Bh), d	; Guarda puntero a los desplazamientos del salto
		ld	a, (de)
		cp	0FEh		; Ha llegado al	final de la tabla? (Punto mas alto del salto)
		ret	nz		; No

		ld	(ix+0Ch), 1	; Cambia el sentido del	salto. Comienza	a caer
					; Para ello recorre la misma lista hacia atras
		jr	saltoUpdate2	; Decrementa el	puntero	para dejarlo en	un valor valido

saltoCaeMax:
		ld	a, 4

saltoUpdateY:
		dec	hl
		dec	hl
		add	a, (hl)
		ld	(hl), a
		ret

;----------------------------------------------------
; Desplazamientos aplicados a la Y del elemento	cuando salta
;----------------------------------------------------
		db 0FFh			; Fin del salto. Cae a maxima velocidad
valoresSalto:	db 4
		db    2
		db    2
		db    2
		db    1
		db    1
		db    2
		db    0
		db    1
		db    1
		db    0
		db    0
		db -2			; Final	de la tabla. Comienza la caida

;----------------------------------------------------
; Pone estado de cayendo
; Actualiza coordenada Y debido	a la caida y comprueba si choca	contra el suelo
; Out:
;   C =	Cae
;  NC =	Esta sobre suelo
;----------------------------------------------------

cayendo:
		ld	(hl), 2		; Estado de cayendo
		inc	hl
		inc	hl
		inc	hl
		ld	a, (hl)		; Y
		and	0FCh
		ld	(hl), a		; Ajusta la Y a	multiplo de 4

		push	hl
		call	chkCae
		pop	hl
		ret	nc		; Esta pisando algo

		ld	a, (hl)		; Y
		add	a, 4		; Incrementa la	Y en 4
		and	0FCh
		ld	(hl), a		; Ajusta la Y a	multiplo de 4

		xor	a
		sub	1		; Set Carry
		ret


;----------------------------------------------------
; Mueve	a un personaje por las escaleras
; Out:
;    Z = Ha llegado al final de	las escaleras
;----------------------------------------------------

andaEscalera:
		ld	a, (timer)
		and	b		; Mascara para ralentizar la velocidad en las escaleras
		ret	nz

		inc	hl
		ld	c, (hl)		; Sentido
		inc	hl
		inc	hl
		inc	hl
		ld	a, (hl)		; X
		dec	hl
		dec	hl		; Apunta a la Y
		and	3
		jr	nz, andaEscalera2 ; La X no es multiplo	de 4

		push	hl		; Apunta a la Y
		call	chkFinEscalera	; Comprueba si llega al	final de la escalera
		pop	hl
		ret	z		; Si, ha llegado al final

andaEscalera2:
		ld	a, c		; Sentido
		inc	hl
		inc	hl
		inc	(hl)		; Incrementa la	X
		rra
		jr	nc, andaEscalera3 ; Va a la derecha
		dec	(hl)
		dec	(hl)		; Decrementa la	X. Va a	la izquierda

andaEscalera3:
		push	hl
		ld	a, 0Ah
		call	ADD_A_HL	; Apunta al sentido de las escaleras (+#0f)
		ld	a, (hl)
		dec	hl
		dec	hl
		dec	hl
		dec	hl
		dec	hl
		inc	(hl)		; Contador de movimiento
		pop	hl		; Apunta a la X

		add	a, c		; Sentido escalera + sentido movimiento
		ld	b, 1		; Baja
		bit	0, a
		jr	z, andaEscalera4
		ld	b, -1		; Sube

andaEscalera4:
		dec	hl
		dec	hl		; Apunta a la Y
		ld	a, (hl)		; Y
		add	a, b		; Suma desplazamineto vertical
		ld	(hl), a		; Actualiza la coordenada Y dependiendo	del sentido de la escalera y hacia donde se mueve

		xor	a
		cp	1		; Set NZ
		ret


;----------------------------------------------------
; Muestra el final del juego
;----------------------------------------------------

ShowEnding:
		push	bc
		call	updateSprites
		pop	bc
		djnz	showEnding2

		ld	hl, protaEndingDat ; Datos preparados para el ending (el prota sale de la piramide, anda a la izquierda	y salta)
		ld	de, protaStatus	; Destino: estructura del prota
		ld	bc, 0Ch		; Numero de datos a copiar
		ldir

		call	setAttribProta	; Actualiza atributos de los sprites del prota
		ld	hl, controlsEnding ; Izquierda,	Izquierda+Salto
		ld	(keyPressDemo),	hl ; Puntero a los controles grabados
		ld	a, 88h
		ld	(KeyHoldCntDemo), a

nextSubStatus_:
		jp	NextSubStatus


controlsEnding:	db 4, 1Bh
		db 14h,	0FFh		; Izquierda, Izquierda+Salto

;----------------------------------------------------
; Anda hasta el	centro de la pantalla y	salta
;----------------------------------------------------

showEnding2:
		djnz	showEnding3
		call	ReplaySavedMov	; Reproduce movimientos	grabados del ending (andar izquierda y saltar)
		call	AI_Prota	; Mueve	y anima	al prota
		ld	a, (flagVivo)
		and	a
		ret	nz		; Se ha	terminado la demo

		call	setProtaSalta_	; Salta

		ld	hl, sentidoProta ; 1 = Izquierda, 2 = Derecha
		ld	(hl), a		; (!?) A = #3F No parece que tenga un valor puesto a proposito
		dec	a		; #3E?
		dec	hl
		ld	(hl), a		; ProntaControl
		ld	a, 2
		ld	(waitCounter), a
		jr	nextSubStatus_

;----------------------------------------------------
; Espera a que termine el salto
;----------------------------------------------------

showEnding3:
		djnz	showSpecialBonus
		call	AI_Prota	; Mueve	y anima	al prota
		ld	a, (flagSalto)	; 0 = Saltando,	1 = En el suelo
		or	a
		ret	z		; Aun no ha terminado el salto
		jr	nextSubStatus_

;----------------------------------------------------
; Muestra texto	de CONGRATULATIONS, SPECIAL BONUS y suma 10.000	puntos
;----------------------------------------------------

showSpecialBonus:
		djnz	waitEnding
		call	VidaExtra	; Suma una vida	extra
		call	specialBonus	; Muestra texto	de CONGARTULATIONS, SPECIAL BONUS y suma 10.000	puntos
		ld	a, 0D0h
		ld	(waitCounter), a
		jr	nextSubStatus_

;----------------------------------------------------
; Espera un rato mientras esta el texto	en pantalla
; Pasa a estado	"Stage clear"
;----------------------------------------------------

waitEnding:
		djnz	setupEnding
		ld	hl, waitCounter
		dec	(hl)
		ret	nz

		ld	a, 8		; status: Stage	clear
		ld	(GameStatus), a
		ret

;----------------------------------------------------
; Prepara todo para mostrar el final
; - Oculta los sprites y muestra la cortinilla
; - Carga los sprites del porta	con el pico
; - Pone la musica del juego
; - Borra todo el mapa RAM
;----------------------------------------------------

setupEnding:
		call	hideSprAttrib	; Oculta los sprites
		call	drawCortinilla	; Dibuja la cortinilla
		ret	p		; No ha	terminado con la cortinilla

		ld	a, 20h
		call	cogeObjeto	; Hace que el prota lleve el pico

		ld	a, 8Bh		; Ingame music
		call	setMusic

		call	BorraMapaRAM
		ld	hl, MapaRAMRoot	; La primera fila del mapa no se usa (ocupada por el marcador).	Tambien	usado como inicio de la	pila
		ld	de,  MapaRAMRoot+1 ; La	primera	fila del mapa no se usa	(ocupada por el	marcador). Tambien usado como inicio de	la pila
		ld	bc, 720h
		ld	(hl), 0		; Tile vacio
		ldir

		ld	hl, 2480h	; VRAM address pattern generator table = Pattern #90
		ld	de, endingTiles
		call	UnpackPatterns

		ld	hl, 480h	; VRAM address color table = pattern #90
		ld	de, endingColors
		call	UnpackPatterns

		ld	hl, 391Fh	; VRAM address name table = Posicion pico piramide grande derecha
		ld	c, 90h
		xor	a
		call	drawHalfPiram

		ld	hl, 3A03h	; VRAM address name table = Posicion vertice izquierdo piramide	mediana	izquierda
		ld	c, 92h
		call	drawHalfPiram

		ld	hl, 3A2Bh	; VRAM address name table = Posicion vert. izq.	piramide pequeña central
		call	drawHalfPiram

		ld	hl, 3A04h	; VRAM address name table = Posicion vertice superior lado derecho piramide mediana izquierda
		ld	c, 94h
		inc	a		; Lado derecho de las piramides
		call	drawHalfPiram

		ld	hl, 3A2Ch	; VRAM address name table = Posicion vertice superior lado derecho piramide pequeña central
		call	drawHalfPiram

		ld	de, tilesEndDoor ; Patrones que	forman la puerta de la piramide	grande
		ld	bc, 302h	; Alto = 3 tiles, ancho	= 2 tiles
		ld	hl, 3A1Eh	; VRAM address name table = Posicion de	la puerta
		call	DEtoVRAM_NXNY	; Dibuja la puerta en pantalla

		ld	a, 96h		; Patron suelo de arena
		ld	hl, 3A60h	; VRAM address name table = Suelo
		ld	bc, 20h		; Ancho	de la pantalla
		call	setFillVRAM	; Dibuja el suelo
		call	renderMarcador

		ld	de, starsLocations
		ld	b, 6		; Numero de estrellas en el cielo

drawStars:
		ld	a, (de)		; Byte bajo de la direccion VRAM tabla de nombres (semicoordenada) de la estrella
		ld	l, a
		ld	h, 39h		; Byte alto de la direccion VRAM de la tabla de	nombres
		ld	a, 97h		; Patron estrella
		call	WRTVRM		; Dibuja la estrella
		inc	de		; Siguiente estrella
		djnz	drawStars

nextSubstatus2:
		ld	hl, subStatus
		inc	(hl)
		ret

;----------------------------------------------------
; Dibuja media piramide	(triangulo rectangulo)
; Pinta	la piramide desde la altura del	vertice	hasta que llega	al suelo, incrementando	el ancho en cada linea
; In:
;  HL =	VRAM address name table
;   C =	Patron diagonal	piramide / o \.	(C+1)= Patron relleno
;   A =	Lado de	la piramide que	pinta (0 = izquierdo, 1	= derecho)
;----------------------------------------------------

drawHalfPiram:
		ld	b, 0		; Contador del ancho de	la fila	actual de la piramide

chkVertice:
		push	hl		; Guarda direccion VRAM	del eje	de la piramide
		push	bc		; Guarda el ancho de la	linea actual de	la piramide
		dec	b
		inc	b		; Es cero el ancho? (Es	el vertice superior?)
		jr	z, drawVertice	; Coloca el vertice de la piramide

drawRelleno:
		ex	af, af'         ; Guarda la direccion de pintado
		ld	a, c		; Tile de arista / o \
		inc	a		; Lo pasa a tile de relleno
		call	WRTVRM		; Tile de relleno de la	piramide
		ex	af, af'         ; Recupera la direccion de pintado
		dec	hl		; Se mueve un patron a la izquierda
		and	a		; Lado de la piramide que tiene	que pintar?
		jr	z, drawRelleno2

		inc	hl
		inc	hl		; Se mueve un patron a la derecha

drawRelleno2:
		djnz	drawRelleno	; Aun faltan patrones por pintar de la fila actual de la piramide

drawVertice:
		pop	bc		; Recupera el ancho actual de la fila de la piramide
		inc	b		; Incrementa contador del ancho	de la piramide
		ex	af, af'         ; Guarda la direccion de pintado indicada en A
		ld	a, c		; Vertice de la	piramide / patron diagonal
		call	WRTVRM		; Dibuja el patron en pantalla
		ex	af, af'         ; Recupera la direccion de pintado

		pop	hl		; Recupera la direccion	VRAM del eje central de	la piramide
		ld	de, 20h		; Distancia al tile inferior
		add	hl, de		; Coloca puntero VRAM un tile mas abajo
		push	hl		; Guarda direccion VRAM	del eje	central
		and	a
		ld	de, 3A80h	; VRAM address name table por debajo de	la linea del suelo
		sbc	hl, de		; Comprueba si ya se ha	pintado	la piramide hasta el suelo
		pop	hl
		jr	c, chkVertice	; Continua pintando otra fila de la piramide

		ret


;----------------------------------------------------
; Tiles	usados para dibujar el escenario final
; Tiles:
;   - Lateral dcho. ladrillo, relleno ladrillo (piramide cercana)
;   - Lateral dcho. arenisca, relleno arenisca (piramide lejana)
;   - Lateral izdo. arenisca oscura, relleno arenisca oscura
;   - Arena del	suelo
;   - Estrella del cielo
;----------------------------------------------------
endingTiles:	db 88h,	0, 2, 6, 0, 0Fh, 2Fh, 6Fh, 0, 3, 0FEh, 81h, 0
		db 3, 0EFh, 88h, 0, 1, 3, 7, 0Fh, 1Fh, 3Fh, 7Fh, 9, 0FFh
		db 87h,	80h, 0C0h, 0E0h, 0F0h, 0F8h, 0FCh, 0FEh, 9, 0FFh
		db 87h,	55h, 0AAh, 55h,	0AAh, 66h, 99h,	66h, 8,	0, 81h
		db 0C0h, 0

;----------------------------------------------------
; Tabla	de colores de los tiles	de fondo anteriores
;----------------------------------------------------
endingColors:	db 88h,	60h, 60h, 0A0h,	0A0h, 60h, 60h,	0A0h, 0A0h, 2
		db 60h,	2, 0A0h, 2, 60h, 2, 0A0h, 10h, 80h, 10h, 60h, 4
		db 8Ah,	4, 6Ah,	8, 50h,	0


;----------------------------------------------------
; Patrones que forman la puerta	de la piramide del final del juego
;----------------------------------------------------
tilesEndDoor:	db 63h,	64h, 0,	65h, 66h, 67h

;----------------------------------------------------
; Bytes	bajos de la direccion VRAM de la tabla de nombres donde	se pintan las estrellas
; El byte alto es fijo = #39
;----------------------------------------------------
starsLocations:	db 9, 16h, 38h,	67h, 74h, 8Eh, 0A9h


;----------------------------------------------------
; Datos	del prota para el ending
; Status, Control, sentido, Y, decimales, X, habitacion, speed decimales, speed	X, Speed room, movCnt, frame
; Andar, izquierda, izquierda, Y=#88, 0, X=#F0,	0, spd=#C0
;----------------------------------------------------
protaEndingDat:	db 0, 4, 1, 88h, 0, 0F0h, 0, 0C0h, 0, 0, 0, 0


;----------------------------------------------------
; Setup	pergamino
;----------------------------------------------------

setupPergamino:
		call	hideSprAttrib
		ld	de, gfxMap	; Patrones del pergamino con el	mapa de	piramides
		ld	hl, 2600h	; VRAM address pattern #C0
		call	UnpackPatterns	; Descomprime los patrones en VRAM

		ld	de, colorTableMap ; Tabla de color de los patrones del mapa
		ld	hl, 600h	; VRAM address color table pattern #C0
		call	UnpackPatterns	; Descomprime tabla de colores

		ld	de, gfxSprMapa	; Sprites usados en el mapa (silueta piramide y	flechas)
		call	unpackGFXset	; Descomprime sprites

		xor	a
		ld	(statusEntrada), a
		ld	(timerPergam2),	a ; Se usa para	hacer una pausa	tras terminar de sonar la musica del pergamino al llegar al GOAL

		ld	a, 91h		; Musica pergamino
		call	setMusic

		ld	a, (piramideActual)
		call	setPiramidMap	; Coloca la silueta para resaltar la piramide actual

		ld	a, (puertaSalida) ; Direccion de la salida de la piramide
		ld	de, numSprFlechas ; Numero de sprites de las flechas

setFlechaMap:
		push	de
		srl	a
		cp	4
		jr	nz, setFlechaMap2
		dec	a		; Convierte valores 1,2,4,8 en 0,1,2,3

setFlechaMap2:
		push	af
		add	a, a
		ld	hl, offsetFlechas
		call	ADD_A_HL
		ld	de, attrPiramidMap ; Atributos del sprite usado	para resaltar una piramide en el mapa (silueta)
		ld	bc, attrFlechaMap ; Atributos de la flecha del mapa
		ld	a, (de)		; Y de la piramide
		add	a, (hl)		; Le suma el desplazamiento que	le corresponde a la flecha
		ld	(bc), a		; Y de la flecha
		inc	hl
		inc	de
		inc	bc
		ld	a, (de)		; X de la piramide
		add	a, (hl)		; Le suma el desplazamiento
		ld	(bc), a		; X de la flecha
		inc	bc
		pop	af		; Recupera la direccion	de la flecha
		pop	de		; Puntero al numero de sprite que corresponde cada direccion
		call	ADD_A_DE
		ld	a, (de)		; Sprite que corresponde a la direccion	de salida
		ld	(bc), a		; Sprite de la flecha
		ret

;----------------------------------------------------
;
; Coloca la flecha en la casilla "GOAL" del mapa
;
;----------------------------------------------------

setFlechaGoal:
		ld	hl, attrPiramidMap ; Atributos del sprite usado	para resaltar una piramide en el mapa (silueta)
		push	hl
		ld	(hl), 97h
		inc	hl
		ld	(hl), 7Bh
		ld	a, 1		; Flecha por arriba
		call	setFlechaInvert
		pop	hl
		ld	(hl), 0C3h
		ret

;----------------------------------------------------
;
; Actualiza las	coordenadas y los sprites del mapa de piramides
; Sprites: flecha y silueta de piramide
;
;----------------------------------------------------

setDestinoMap:
		ld	a, (piramideDest)
		call	setPiramidMap
		ld	a, (puertaEntrada)

setFlechaInvert:
		ld	de, numSprFlechInv
		jr	setFlechaMap

;----------------------------------------------------
;
; Logica del mapa de piramides
;
;----------------------------------------------------

tickPergamino:
		ld	a, (timer)
		and	7		; 8 colores de animacion
		ld	hl, coloresFlecha ; Colores usados para	resaltar la flecha y piramide en el mapa
		call	ADD_A_HL
		ld	a, (hl)
		ld	(colorPiramidMap), a ; Color del outline de la piramide	en el mapa
		ld	(colorFlechaMap), a ; Color de la flecha que indica a que piramide vamos en el mapa
		call	updateSprites

		call	chkPause	; Comprueba si se pulsa	F1 en el mapa

		ld	hl, piramideActual
		ld	a, (hl)
		inc	hl
		sub	(hl)
		ld	hl, statusEntrada
		inc	(hl)
		cp	0Eh		; Ultima piramide?
		ld	a, (hl)
		jr	z, setEndingStat

		cp	58h		; Ciclos que muestra la	flecha de salida
		jr	z, setDestinoMap

		cp	0E0h		; Ciclos que muestra la	flecha de entrada
		ret	nz

		inc	a
		ld	(flagEndPergamino), a ;	1 = Ha terminado de mostar el pergamino/mapa
		ret

setEndingStat:
		cp	58h		; Hay que cambiar la posicion de la flecha al destino?
		jr	z, setFlechaGoal ; Coloca la flecha sobre GOAL

		ld	a, (MusicChanData)
		or	a
		ret	nz		; Aun suena musica

		ld	hl, timerPergam2 ; Se usa para hacer una pausa tras terminar de	sonar la musica	del pergamino al llegar	al GOAL
		ld	a, (hl)
		inc	(hl)
		cp	80h
		ret	nz		; Hace una pausa al terminar de	sonar la musica

		ld	hl, numFinishGame ; Numero de veces que	se ha terminado	el juego
		inc	(hl)		; Incrementa el	numero de veces	que se ha terminado el juego

		xor	a
		inc	hl
		ld	(hl), a
		ld	d, h
		ld	e, l
		inc	de
		ld	bc, 0Ah
		ld	a, c		; A = Status #A
		ldir			; Borra	10 bytes de variables desde numFinishedGame

		call	setGameStatus	; Pone status #A = Ending
		jp	ResetSubStatus	; (!?) Ya lo hace en la	anterior llamada

;----------------------------------------------------
; Muestra texto	de "CONGRATULATIONS" "SPECIAL BONUS"
; Y suma 10.000	puntos
;----------------------------------------------------

specialBonus:
	IF	(VERSION2)
		ld	de, TXT_ENDING
		call	unpackGFXset
		ld	de, 5000h
		push	de
		call	SumaPuntos
		pop	de
		jp	SumaPuntos
	ELSE
		ld	de, TXT_ENDING
		call	unpackGFXset
		ld	de, 5000h
		call	SumaPuntos
		ld	de, 5000h
		jp	SumaPuntos
	ENDIF

;----------------------------------------------------
; Pone las coordenadas de la silueta de	la piramide actual
;----------------------------------------------------

setPiramidMap:
		dec	a
		add	a, a
		ld	hl, coordPiramMap
		call	ADD_A_HL
		ld	de, attrPiramidMap ; Atributos del sprite usado	para resaltar una piramide en el mapa (silueta)
		ldi			; Y
		ldi			; X
		ex	de, hl
		ld	(hl), 0E4h	; Sprite de la silueta de la piramide
		ret

;----------------------------------------------------
; Graficos del pergamino con el	mapa de	piramides
;----------------------------------------------------
gfxMap:		db 0A0h, 1, 3, 7, 0Fh, 1Fh, 3Fh, 0Fh, 3, 80h, 0C0h, 0E0h
		db 0F0h, 0F8h, 0FCh, 0F0h, 0C0h, 1, 3, 7, 0Fh, 1Fh, 3Fh
		db 0Fh,	3, 80h,	0C0h, 0E0h, 0F0h, 0F8h,	0FCh, 0F0h, 0C0h
		db 5, 0, 81h, 0FFh, 0Fh, 80h, 81h, 0FFh, 7, 0, 81h, 0FFh
		db 7, 0, 81h, 0FFh, 0Ah, 1, 8, 3, 8, 0C0h, 0A3h, 0FFh
		db 38h,	49h, 81h, 9Dh, 49h, 38h, 0FFh, 0FFh, 0E1h, 13h
		db 12h,	13h, 12h, 0E2h,	0FFh, 0FFh, 0C8h, 68h, 28h, 0E8h
		db 28h,	2Fh, 0FFh, 1, 3, 7, 0Fh, 1Fh, 3Fh, 7Fh,	7Fh, 0F0h
		db 0F9h, 0FDh, 7, 0FFh,	3, 0DFh, 91h, 0CBh, 89h, 80h, 0
		db 81h,	0D1h, 0F3h, 0F3h, 0FBh,	0FFh, 0FFh, 0Fh, 1Fh, 3Fh
		db 3Fh,	7Fh, 7Fh, 5, 0FFh, 8Ah,	0F7h, 0F3h, 0D7h, 83h
		db 85h,	0F8h, 0F8h, 0F0h, 0FAh,	0FEh, 5, 0FFh, 4, 7Fh
		db 7, 3Fh, 7, 7Fh, 4, 3Fh, 0Bh,	0Fh, 0Dh, 1Fh, 4, 80h
		db 0Ch,	0C0h, 3, 0F0h, 0Ch, 0E0h, 0Bh, 0F0h, 6,	0E0h, 6
		db 80h,	4, 0, 7, 80h, 0Ch, 0C0h, 7, 80h, 6, 0, 4, 80h
		db 2, 0C0h, 0

colorTableMap:	db 5, 8Fh, 3, 6Fh, 5, 9Fh, 8, 8Fh, 83h,	61h, 6Fh, 6Fh
		db 5, 9Fh, 83h,	81h, 8Fh, 8Fh, 30h, 1Fh, 11h, 6Fh, 6, 4Fh
		db 2, 6Fh, 6, 4Fh, 2, 6Fh, 6, 4Fh, 81h,	6Fh, 8,	0E0h, 78h
		db 0F0h, 48h, 0F0h, 0


;----------------------------------------------------
; Sprites usados en el mapa de piramides
; Silueta piramide, flecha arriba, derecha, abajo, izquierda
;----------------------------------------------------
gfxSprMapa:	dw 1F20h		; Direccion VRAM sprite	#E4
		db 88h,	6, 9, 10h, 20h,	40h, 0C0h, 30h,	0Fh, 0Ah, 0, 85h
		db 80h,	40h, 20h, 30h, 0C0h, 9,	0, 84h,	10h, 38h, 7Ch
		db 0FEh, 3, 38h, 32h, 0, 87h, 10h, 18h,	0FCh, 0FEh, 0FCh
		db 18h,	10h, 3,	38h, 84h, 0FEh,	7Ch, 38h, 10h, 32h, 0
		db 87h,	10h, 30h, 7Eh, 0FEh, 7Eh, 30h, 10h, 80h

		dw #3867
		db 91h		; Transfiere #11 patrones
		db 20h, 0,	30h, 39h, 32h, 21h, 2Dh, 29h, 24h, 1Bh, 33h,	0, 2Dh,	21h, 30h, 0, 20h	; Text: "- Pyramid's Map -"


		; Tabla de nombres del pergamino		
		db 4Fh, 0, 85h, 0CFh, 0D0h
		db 1, 1, 0D2h, 4, 1, 88h, 0D0h,	0D3h, 1, 1, 1, 0D2h, 0D0h
		db 0D5h, 0Fh, 0, 81h, 0D8h, 10h, 1, 81h, 0DCh, 0Eh, 0
		db 92h,	0DBh, 1, 0C0h, 0C3h, 0C7h, 0C7h, 0C2h, 0C3h, 0C7h
		db 0C7h, 0C2h, 0C3h, 0C7h, 0C8h, 1, 1, 1, 0DFh,	0Eh, 0
		db 81h,	0D9h, 0Ch, 1, 85h, 0C9h, 1, 1, 1, 0E0h,	0Eh, 0
		db 92h,	0DAh, 1, 1, 0C4h, 0C7h,	0C2h, 0C3h, 0C7h, 0C7h
		db 0C7h, 0C2h, 0C3h, 0C7h, 0C2h, 0C1h, 1, 1, 0E1h, 0Eh
		db 0, 84h, 0D7h, 1, 1, 0C5h, 0Dh, 1, 81h, 0DDh,	0Eh, 0
		db 3, 1, 89h, 0C6h, 0C2h, 0C3h,	0C7h, 0C7h, 0C2h, 0C3h
		db 0C7h, 0C8h, 5, 1, 81h, 0E2h,	0Eh, 0,	81h, 0D6h, 0Ah
		db 1, 81h, 0C9h, 5, 1, 81h, 0E3h, 0Eh, 0, 8Dh, 0D8h, 1
		db 0C4h, 0C2h, 0C3h, 0C7h, 0C2h, 0C3h, 0C7h, 0C7h, 0C7h
		db 0C2h, 0C1h, 4, 1, 81h, 0E4h,	0Eh, 0,	83h, 0DBh, 1, 0C5h
		db 0Eh,	1, 81h,	0DFh, 0Eh, 0, 92h, 0D9h, 1, 0C6h, 0C7h
		db 0C7h, 0C7h, 0C2h, 0C3h, 0C7h, 0C2h, 0C3h, 0C7h, 0C7h
		db 0C2h, 0C1h, 1, 1, 0E0h, 0Eh,	0, 81h,	0DAh, 0Ch, 1, 85h
		db 0C9h, 1, 1, 1, 0DEh,	0Eh, 0,	81h, 0D7h, 8, 1, 89h, 0C4h
		db 0C7h, 0C7h, 0C7h, 0C2h, 0C1h, 1, 1, 0E5h, 0Eh, 0, 7
		db 1, 85h, 0CAh, 0CCh, 0CDh, 0CEh, 0CBh, 5, 1, 81h, 0E6h
		db 0Eh,	0, 84h,	0D6h, 0D1h, 0D4h, 0D1h,	4, 1, 8Ah, 0D4h
		db 1, 1, 1, 0D1h, 0D1h,	1, 1, 0D1h, 0E7h, 0
		
coloresFlecha:	db 1, 6, 6, 0Ah, 0Ah, 6, 6, 6	; Colores usados para resaltar la flecha y piramide en el mapa


;----------------------------------------------------
;
; Coordenadas en pantalla de las piramides del mapa
; Y, X
;----------------------------------------------------
coordPiramMap:	db 3Fh,	4Ah
		db 3Fh,	6Ah
		db 3Fh,	8Ah
		db 4Fh,	0A2h
		db 4Fh,	8Ah
		db 4Fh,	62h
		db 5Fh,	5Ah
		db 5Fh,	7Ah
		db 6Fh,	92h
		db 6Fh,	6Ah
		db 6Fh,	52h
		db 7Fh,	6Ah
		db 7Fh,	82h
		db 7Fh,	0A2h
		db 8Fh,	0A2h

offsetFlechas:	db 0F9h, 2
		db 8, 2
		db 0F9h, 0F1h
		db 0F9h, 4

;----------------------------------------------------
; Numero de sprites de las flechas
;----------------------------------------------------
numSprFlechas:	db 0E8h
		db 0F0h			; Abajo
		db 0F4h			; Izquierda
		db 0ECh			; Derecha

;----------------------------------------------------
; Numero de sprites de las flechas invertidas
;----------------------------------------------------
numSprFlechInv:	db 0F0h
		db 0E8h			; Arriba
		db 0ECh			; Derecha
		db 0F4h			; Izquierda


TXT_ENDING:
		dw #38c9		; Direccion VRAM
		db 8Fh
		db 23h,	2Fh, 2Eh, 27h, 32h, 21h, 34h, 35h, 2Ch,	21h, 34h, 29h, 2Fh, 2Eh, 33h 	; "CONGRATULATIONS"
		db #2e, 0									; Rellena #2e patrones
		db 90h			; Transfiere #10 patrones
		db 33h, 30h, 25h, 23h, 29h, 21h, 2Ch, 0, 22h, 2Fh, 2Eh, 35h, 33h, 0, 0, 11h 	; "SPECIAL BONUS  1"
		
		db    4, 10h									; "0000"
		db    0										; Fin

;----------------------------------------------------
;
; Set music
; In:
;   A =	Numero de musica o efecto
;----------------------------------------------------

setMusic:
	IF	(VERSION2)
		di
		call	SetMusic_
		ei
		ret
	ELSE
		di
		push	hl
		push	de
		push	bc
		push	af
		push	ix
		call	SetMusic_
		pop	ix
		pop	af
		pop	bc
		pop	de
		pop	hl
		ei
		ret
	ENDIF
	
SetMusic_:
		ld	c, a
		and	3Fh
		ld	b, 2		; Canales a usar
		ld	hl, musicCh1
		cp	0Bh		; Es una efecto	de sonido de los que suenan mientras suena la musica principal?
		jr	c, setSFX

		cp	11h		; Es una musica	que suena en solitario y usa los 3 canales?
		jr	c, setMus

		inc	b		; Usa los 3 canales
		jr	setMus

setSFX:	
		dec	b		; Solo usa 1 canal
		ld	hl, musicCh3	; El canal 3 es	el que reproduce los efectos de	sonido

setMus:	
		ld	a, (hl)		; Musica que esta sonando en este canal
		and	3Fh		; Descarta bits	de configuracion y se queda solo con el	numero de musica
		ld	e, a		; E = Sonido actual
		ld	a, c
		and	3Fh		; A = Sonido que se quiere reproducir
		cp	e		; Tiene	mas prioridad el que esta sonando o el nuevo?
		ret	c		; El que esta sonando tiene mas	prioridad

		add	a, a
		ld	de, MusicIndex-2
		call	ADD_A_DE	; Obtiene puntero a los	datos de la musica o efecto que	hay que	reproducir
		dec	hl
		dec	hl

setChanData:
		push	hl
		pop	ix
		ld	(hl), 1		; Contador de la duracion de la	nota
		inc	hl
		ld	(hl), 1		; Duracion por defecto de la nota
		inc	hl
		ld	(hl), c		; Musica que esta reproduciendo	el canal

		inc	hl
		ld	a, (de)
		ld	(hl), a		; Byte bajo del	puntero	a los datos de la musica/efecto
		inc	hl
		inc	de
		ld	a, (de)
		ld	(hl), a		; Byte alto del	puntero

		ld	(ix+9),	0
		ld	a, 0Ah
		call	ADD_A_HL	; Apunta al siguiente canal
		inc	de
		djnz	setChanData
		ret

;----------------------------------------------------
; Pattern loop
; Comando = #FE	xx
;  xx =	Numero de veces	a repetir el pattern musical
;  FF =	Loop infinito
;----------------------------------------------------

patternLoop:
		inc	hl		; Parametro del	comando	loop
		ld	a, (ix+MUSIC_CNT_LOOP) ; Veces que se ha reproducido un	pattern
		inc	a		; Incrementa el	numero de veces	que ha sonado el pattern
		cp	(hl)		; Ha sonado tantas veces como se indica?
		jr	z, omiteLoop

		jp	m, setMusPattern ; Es un loop infinito?
		dec	a		; No incrementa	el numero de veces que ha sonado

setMusPattern:
		ld	(ix+MUSIC_CNT_LOOP), a ; Veces que se ha reproducido un	pattern
		inc	hl
		ld	a, (hl)		; Direccion baja del pattern
		ld	(ix+MUSIC_ADD_LOW), a
		inc	hl
		ld	a, (hl)		; Direccion alta del pattern
		ld	(ix+MUSIC_ADD_HIGH), a
		jr	contProcessSnd	; Interpretar el pattern

omiteLoop:
		inc	hl
		inc	hl		; Descarta direccion del loop
		xor	a
		ld	(ix+MUSIC_CNT_LOOP), a ; Inicializa contador de	repeticiones del pattern
		call	incMusicPoint

contProcessSnd:
		inc	(ix+MUSIC_CNT_NOTA) ; Este comando no modifica la duracion de la nota
		jp	processSndData

;----------------------------------------------------
; Alterna entre	el tono	o ruido	del canal 3
; In:
;   C =	Canal en proceso 1, 3, 5 (1-3)
;   D:
;    1 = Activa	tono canal 3 y desactiva ruido
;    0 = Desactiva tono	canal 3	y activa ruido
;----------------------------------------------------

switchCh3OnOff:
		ld	a, c
		cp	5		; Es el	canal 3?
		ret	nz		; No

		dec	d
		jr	z, toneOnCh123

		ld	a, 10011100b
		jr	SetPSGMixer	; Desactiva el tono del	canal 3	y activa el ruido

toneOnCh123:
		ld	a, 10111000b	; Activa los 3 canales de sonido y apaga los de	ruido

SetPSGMixer:
		ld	(mixerValuePSG), a
		ld	e, a
		ld	a, 7
		jp	WRTPSG


;----------------------------------------------------
; Actualiza el driver de sonido
;----------------------------------------------------

updateSound:
		ld	a, (mixerValuePSG)
		call	SetPSGMixer	; Fija el estado de los	canales	del PSG

		ld	c, 1
		ld	ix, MusicChanData
		exx
		ld	b, 3		; Numero de canales
		ld	de, 0Eh		; Channel data size

updateSound2:
		exx
		ld	a, (ix+MUSIC_ID) ; Musica que esta reproduciendo el canal

		push	af
		dec	a		; Es el	sonido de caer?
		call	z, updateSfxCaer
		pop	af

		or	a		; Esta sonando algo?
		call	nz, processSndData ; si

		inc	c
		inc	c		; Siguiente canal
		exx
		add	ix, de		; Apunta a los datos del siguiente canal
		djnz	updateSound2	; Reproduce siguiente canal
		ret

updateSfxCaer:
		ld	a, c
		cp	5
		ret	c		; No es	el canal 3

		ld	hl, caidaSndDat	; Este byte y los dos anteriores controlan la frecuencia del sonido de caida
		ld	de, caidaSndData
		ld	a, (flagSetCaeSnd) ; Si	es 0 hay que inicializar los datos del sonido de caida
		cp	1
		jr	c, initCaeSndDat ; Inicializa valores del sonido de caida

		ld	a, 8
		add	a, (hl)		; Incrementa frecuencia	del sonido de caida
		ld	(hl), a
		dec	hl
		jr	nc, setFrqCaePoint ; Guarda el puntero a la frecuencia de caida

		inc	(hl)		; Si hay acarreo, incrementa frecuencia	byte alto

setFrqCaePoint:
		dec	hl
		ld	(ix+MUSIC_ADD_LOW), l
		ld	(ix+MUSIC_ADD_HIGH), h
		ret

initCaeSndDat:
		push	bc
		ex	de, hl
		ld	bc, 4
		lddr

		ex	de, hl
		pop	bc
		inc	hl
		inc	hl
		inc	hl
		jr	setFrqCaePoint



		db    1			; Quita	"flagSetCaeSnd"
		db 21h
		db 0B0h
caidaSndData:	db 61h

processSndData:
		bit	6, a
		ld	d, 1
		call	z, switchCh3OnOff

		ld	a, (ix+MUSIC_ID)
		or	a
		jp	m, loc_7C2D

		dec	(ix+MUSIC_CNT_NOTA) ; Decrementa contador duracion nota
		ret	nz		; No hay que actualizar	la nota, sigue sonando la anterior

nextNote:
		ld	l, (ix+MUSIC_ADD_LOW)
		ld	h, (ix+MUSIC_ADD_HIGH) ; Puntero a los datos de	la musica
		ld	a, (hl)		; Dato
		cp	0FEh		; Hay que hacer	un loop	de un pattern?
		jp	z, patternLoop	; Si

		jr	nc, endMusic	; #FF =	Fin de los datos

		bit	7, (ix+MUSIC_ID)
		jp	nz, setNote

; Duracion nota: #2x (x	= duracion)
		and	0F0h		; Se queda con el comando (nibble alto)
		cp	20h		; Comando: Cambiar duracion de la nota?
		ld	a, (hl)		; Vuelve a leer	el dato
		jr	nz, loc_7BC7

		and	0Fh		; Se queda con la duracion (nibble bajo)
		ld	(ix+MUSIC_DURAC_NOTA), a ; Cambia la duracion de la nota
		inc	hl
		ld	a, (hl)		; Lee el siguiente dato

loc_7BC7:
		ld	b, a
		and	0F0h
		cp	10h
		jr	nz, loc_7BEA

		ld	a, (hl)
		and	1Fh
		ld	e, a
		inc	hl
		bit	4, (hl)
		ld	b, (hl)
		jr	nz, loc_7BDC

		ld	a, e
		sub	10h
		ld	e, a

loc_7BDC:
		res	4, b
		dec	hl
		ld	a, 6		; Noise	generator
		call	WRTPSG
		ld	d, 0
		call	switchCh3OnOff
		inc	hl

loc_7BEA:
		bit	6, (ix+MUSIC_ID)
		jr	z, loc_7BF7

		ld	a, (hl)		; (!?) No se usa el valor
		call	incMusicPoint
		ld	a, b
		jr	setDuracion

loc_7BF7:
		and	0F0h
		ld	b, a
		xor	(hl)
		ld	d, a		; Frecuencia (high)
		inc	hl
		ld	e, (hl)		; Frecuencia (low)
		call	incMusicPoint
		ex	de, hl
		call	setFreq
		ld	a, b
		rrca
		rrca
		rrca
		rrca

setDuracion:
		ld	h, a
		ld	e, (ix+MUSIC_DURAC_NOTA) ; Valor de la duracion	de la nota
		ld	(ix+MUSIC_CNT_NOTA), e ; Contador de la	duracion de la nota
		ld	a, (ix+0Ch)
		add	a, e
		ld	(ix+8),	a
		jr	setVolume

endMusic:
		xor	a
		ld	(ix+MUSIC_CNT_LOOP), a ; Veces que se ha reproducido un	pattern
		ld	(ix+0Bh), a
		ld	d, 1
		call	switchCh3OnOff
		xor	a
		ld	(ix+MUSIC_ID), a ; Ninguna musica sonando
		ld	h, a		; Volumen 0
		jr	setVolume

loc_7C2D:
		dec	(ix+MUSIC_CNT_NOTA) ; Decrementa duracion contador nota
		jp	z, nextNote	; Fin nota

		dec	(ix+8)
		ld	a, (ix+8)
		cp	(ix+MUSIC_CNT_NOTA)
		jr	nz, loc_7C47

		ld	e, a
		ld	a, (ix+0Dh)
		cp	e
		ld	a, e
		jr	nc, decVolume
		ret

loc_7C47:
		dec	(ix+8)

decVolume:
		ld	a, (ix+MUSIC_VOLUME)
		dec	a
		ret	m		; El volumen era 0
		ld	(ix+MUSIC_VOLUME), a
		ld	h, a

;----------------------------------------------------
; Fija el volumen de un	canal del PSG
; In:
;   C =	Canal 1-3 (1,3,5)
;   H =	Volumen
;----------------------------------------------------

setVolume:
		ld	a, c
		rrca
		add	a, 88h
		ld	e, h
		jp	WRTPSG

setNote:
		ld	a, (hl)
		and	0F0h
		cp	0D0h		; Comando #D = Tempo
		ld	a, (hl)
		jr	nz, loc_7C6A

		and	0Fh
		ld	(ix+MUSIC_TEMPO), a
		inc	hl
		ld	a, (hl)

loc_7C6A:
		cp	0F0h
		jr	c, loc_7C7F

		and	0Fh
		ld	(ix+MUSIC_VOLUME_CH), a	; Volumen canal
		inc	hl
		ld	a, (hl)
		ld	(ix+0Ch), a
		inc	hl
		ld	a, (hl)
		ld	(ix+0Dh), a
		inc	hl
		ld	a, (hl)

loc_7C7F:
		cp	0E0h
		jr	c, loc_7C94

		and	0Fh
		bit	3, a
		jr	z, changOctave

		ld	(ix+0Bh), a
		inc	hl
		jr	setNote

changOctave:
		ld	(ix+MUSIC_OCTAVA), a ; Octava?
		inc	hl
		ld	a, (hl)		; Nota+duracion

loc_7C94:
		and	0Fh		; Nibble bajo =	duracion
		ld	b, a
		ld	a, (ix+MUSIC_TEMPO)
		jr	z, setDuracionNota

incDuracionNota:
		add	a, (ix+MUSIC_TEMPO)
		djnz	incDuracionNota

setDuracionNota:
		ld	(ix+MUSIC_DURAC_NOTA), a

		ld	a, (hl)
		call	incMusicPoint
		and	0F0h
		rrca
		rrca
		rrca
		rrca
		ld	b, a
		sub	0Ch
		jr	z, defaultVolume

		ld	a, (ix+MUSIC_VOLUME_CH)	; Volumen canal

defaultVolume:
		ld	(ix+MUSIC_VOLUME), a
		call	setDuracion

		ld	a, b
		ld	hl, freqNotas
		call	ADD_A_HL

		ld	l, (hl)		; Frecuencia
		ld	h, 0

		ld	a, (ix+MUSIC_OCTAVA) ; Octava?
		or	a
		jr	z, setOctave

		ld	b, a

addOctave:
		add	hl, hl
		djnz	addOctave

setOctave:
		ld	a, (ix+0Bh)
		or	a
		jr	z, setFreq
		inc	hl		; Chorus?

; C = Canal 1,3,5 (1-3)
; HL = Frecuencia

setFreq:
		ld	a, c		; Registro PSG de la frecuencia	del canal (high)
		ld	e, h
		call	WRTPSG
		ld	a, c
		dec	a		; Registro frecuencia (low)
		ld	e, l
		jp	WRTPSG

incMusicPoint:
		inc	hl
		ld	(ix+MUSIC_ADD_LOW), l
		ld	(ix+MUSIC_ADD_HIGH), h
		ret

;----------------------------------------------------
; Frecuencias de las notas (segunda octava)
;----------------------------------------------------
freqNotas:	db 6Ah
		db 64h
		db 5Fh
		db 59h
		db 54h
		db 50h
		db 4Bh
		db 47h
		db 43h
		db 3Fh
		db 3Ch
		db 38h

MusicIndex:
		dw SFX_Dummy		; 1 - Caer
		dw SFX_Dummy		; 2 - Choca suelo
		dw SFX_PuertaGir	; 3 - Puerta giratoria
		dw SFX_Coger		; 4 - Coge objeto:cuchillo o pico
		dw SFX_Picar		; 5 - Sonido del pico
		dw SFX_Lanzar		; 6 - Larzar cuchillo
		dw SFX_Momia		; 7 - Aparece una momia
		dw SFX_Hit		; 8 - Explota momia al golpearla con cuchillo
		dw SFX_Gema		; 9 - Coger gema
		dw SFX_VidaExtra	; 10 - Vida extra

		dw MUS_Ingame		; 11 - Musica ingame
		dw MUS_Ingame2

		dw MUS_CloseDoor	; 13 - Puerta cerrandose
		dw MUS_CloseDoor2

		dw MUS_SalirPiram	; 15 - Campanilla al salir de la piramide
		dw MUS_SalirPiram2

		dw MUS_Mapa		; 17 - Fanfarria del pergamino
		dw MUS_Mapa2
		dw MUS_Mapa3

		dw MUS_StageClr		; 20 - Stage clear. Ha cogido todas las	gemas
		dw MUS_StageClr2
		dw MUS_StageClr3

		dw MUS_Start		; 23 - Start game
		dw MUS_Start2
		dw MUS_Start3		; 25

		dw MUS_GameOver		; 26 - Game Over
		dw MUS_GameOver2
		dw MUS_GameOver3

		dw MUS_Muerte		; 29 - Prota muere
		dw MUS_Muerte2		; 30
		dw MUS_Muerte3

		dw SFX_Dummy		; 32 - Silencio
		dw SFX_Dummy
		dw SFX_Dummy

SFX_Dummy:	db 0FFh

SFX_Momia:      db 0D1h, 0FCh, 3, 3, 0E2h, 0, 0C0h, 10h, 0C0h, 20h, 0C0h
		db 20h, 0C0h, 40h, 80h, 40h, 80h, 0CEh, 0FDh, 0, 0C0h
		db 10h, 0C0h, 20h, 0C0h, 20h, 0C0h, 40h, 80h, 40h, 80h
		db 0CEh, 0D2h, 0C6h

		db 0FEh, 2
		dw SFX_Momia
		db 0FFh

SFX_Hit:	db 21h,	0E0h, 0A0h, 0E0h, 0C0h,	0E0h, 0E0h, 0D0h, 60h
		db 0D0h, 80h, 0D0h, 0A0h, 0D0h,	20h, 0C0h, 40h,	0C0h, 60h
		db 0C0h, 80h, 0FFh

SFX_Gema:	db 22h,	0D0h, 54h, 0, 0, 0D0h, 50h, 0, 0, 0D0h,	47h, 0D0h
		db 42h,	0, 0, 0D0h, 38h, 0D0h, 33h, 0FFh

SFX_Coger:	db 22h,	0C1h, 52h, 0E0h, 74h, 0C0h, 91h, 0F0h, 74h, 0D0h
		db 75h,	0FFh

SFX_Picar:	db 22h,	1Ch, 1Fh, 8, 16h, 0Ch, 0FFh

SFX_Lanzar:	db 21h,	0E0h, 78h, 0C0h, 70h, 0C0h, 68h, 0E0h, 63h, 0D0h
		db 5Ah,	0D0h, 53h, 0B0h, 53h, 90h, 53h,	50h, 53h, 0FFh

SFX_PuertaGir:	db 26h,	0F6h, 94h, 0F6h, 8Fh, 0F6h, 8Fh, 0F6h, 8Ah, 0E6h
		db 85h,	0E6h, 80h, 0D6h, 7Ah, 0D6h, 75h, 0C6h, 70h, 0C6h
		db 6Ah,	0B6h, 85h, 0A6h, 70h, 96h, 6Ah,	0FFh

MUS_Muerte:	db 26h,	0E1h, 80h, 0E2h, 80h, 0D2h, 0, 0D3h, 0,	0C2h, 80h
		db 0C3h, 80h, 0B3h, 0, 0B4h, 0,	0FFh

MUS_Muerte2:	db 26h,	0E0h, 80h, 0E1h, 80h, 0D1h, 0, 0D2h, 0,	0C1h, 80h
		db 0C2h, 80h, 0B2h, 0, 0B3h, 0,	0FFh

MUS_Muerte3:	db 26h,	0E1h, 0, 0E1h, 0, 0D1h,	80h, 0D2h, 80h,	0C2h, 0	; ...
		db 0C3h, 0, 0B2h, 80h, 0B3h, 80h, 0FFh

MUS_Ingame:	db 0D8h, 0FCh, 3, 3, 0E2h, 42h,	50h, 42h, 50h, 80h, 0C0h
		db 90h,	0C0h, 0B0h, 90h, 80h, 50h, 42h,	50h, 41h, 21h
		db 11h,	21h, 43h, 82h, 90h, 82h, 90h, 0B0h, 0C0h, 0E1h
		db 0, 0C0h, 30h, 0, 0E2h, 0B0h,	90h, 80h, 90h, 0B0h, 90h
		db 80h,	0C0h, 50h, 0C0h, 42h, 50h, 41h,	0B0h, 90h, 0B0h
		db 0E1h, 0, 30h, 40h, 30h, 0C0h, 0, 0C0h, 0E2h,	0B2h, 0E1h
		db 0, 0E2h, 0B1h, 0B0h,	90h, 0B0h, 0E1h, 0, 30h, 40h, 60h
		db 40h,	30h, 0,	0E2h, 0B2h, 0E1h, 0, 0E2h, 0B3h, 0FEh
		db 0FFh
		dw MUS_Ingame

MUS_Ingame2:	db 0D8h, 0FCh, 3, 3, 0E3h

byte_7E61:	db 41h,	80h, 80h, 40h, 0C0h, 81h, 0FEh,	4
		dw byte_7E61

byte_7E6B:	db 51h,	90h, 90h, 50h, 0C0h, 91h, 0FEh,	2
		dw byte_7E6B

byte_7E75:	db 41h,	80h, 80h, 40h, 0C0h, 81h, 0FEh,	2
		dw byte_7E75

byte_7E7F:	db 31h,	90h, 90h, 0E4h,	0B0h, 0C0h, 0E3h, 91h, 0FEh, 3
		dw byte_7E7F
		db 31h,	90h, 90h, 0E4h,	0B0h, 0E3h, 30h, 60h, 0B0h, 0FEh
		db 0FFh
		dw MUS_Ingame2
		db 0FEh
		db 0FFh

MUS_StageClr:	db 0E8h
MUS_StageClr2:	db 0D6h, 0FCh, 1, 1, 0E1h, 1, 11h, 41h,	51h, 41h, 11h
		db 1, 0E2h, 0A1h, 0E1h,	0, 10h,	0, 10h,	0, 10h,	0, 10h
		db 3, 0FFh

MUS_StageClr3:	db 0D6h, 0FBh, 1, 1, 0E3h, 0B1h, 0E2h, 11h, 41h, 51h, 41h
		db 11h,	1, 0E3h, 0A1h, 0E2h, 0,	10h, 0,	10h, 0,	10h, 0
		db 10h,	3, 0FFh

MUS_GameOver:	db 0E8h
MUS_GameOver2:	db 0DAh, 0FCh, 2, 2, 0E1h, 73h,	0B3h, 0A3h, 83h, 80h, 70h
		db 40h,	30h, 40h, 0C0h,	70h, 0C0h, 0D5h, 80h, 0A0h, 0DAh
		db 83h,	0FFh

MUS_GameOver3:	db 0DAh, 0FDh, 2, 2, 0E2h, 70h,	80h, 0A0h, 0B0h, 0E1h
		db 20h,	0C0h, 0E2h, 0B0h, 0C0h,	0A0h, 0C0h, 80h, 0C0h
		db 0D5h, 0A0h, 0B0h, 0DAh, 0A2h, 80h, 70h, 40h,	30h, 40h
		db 0C0h, 70h, 0C0h, 84h, 0FFh

MUS_Start:	db 0E8h
MUS_Start2:	db 0D4h, 0FCh, 1, 1, 0E0h, 21h,	0C1h, 0E1h, 91h, 0C1h
		db 0E0h, 1, 0E1h, 0A1h,	91h, 0C1h, 71h,	0A1h, 0E0h, 11h
		db 0E1h, 0A1h, 97h, 31h, 21h, 31h, 61h,	91h, 71h, 91h
		db 0A1h, 91h, 71h, 61h,	31h, 27h, 0FFh

MUS_Start3:	db 0D3h, 0FBh, 1, 1, 0E1h, 0C0h, 0D4h, 21h, 0C1h, 0E2h
		db 91h,	0C1h, 0E1h, 1, 0E2h, 0A1h, 91h,	0C1h, 71h, 0A1h
		db 0E1h, 11h, 0E2h, 0A1h, 97h, 31h, 21h, 31h, 61h, 91h
		db 71h,	91h, 0A1h, 91h,	71h, 61h, 31h, 27h, 0FFh

SFX_VidaExtra:	db 0D4h, 0FDh, 3, 3, 0E2h, 70h,	60h, 70h, 0E1h,	70h, 60h
		db 71h,	0FFh

MUS_CloseDoor:	db 0D1h, 0FCh, 1, 1, 0E3h, 1, 1, 51h, 51h, 21h,	21h, 71h
		db 71h,	0CEh, 51h, 51h,	91h, 91h, 71h, 71h, 0B1h, 0B1h
		db 91h,	91h, 0E3h, 1, 1, 0FFh

MUS_CloseDoor2:	db 0D1h, 0FCh, 1, 1, 0E2h, 1, 1, 51h, 51h, 21h,	21h, 71h
		db 71h,	0CFh, 51h, 51h,	91h, 91h, 71h, 71h, 0B1h, 0B1h
		db 91h,	91h, 0E1h, 1, 1, 0FFh

MUS_Mapa:	db 0D6h, 0FCh, 3, 3, 0E2h, 0B2h, 0B0h, 0D7h, 0B0h, 70h
		db 0D8h, 90h, 0D6h, 0B1h, 0E1h,	20h, 20h, 41h, 0, 40h
		db 7Bh,	0FFh

MUS_Mapa2:	db 0D6h
		db 0FCh, 3, 3, 0E2h, 72h, 70h, 0D7h, 70h, 20h, 0D8h, 50h
		db 0D6h, 71h, 0B0h, 0B0h, 0E1h,	1, 0E2h, 90h, 0E2h, 0
		db 2Bh,	0FFh

MUS_Mapa3:	db 0D6h, 0FCh, 3, 3, 0E2h, 22h,	20h, 0D7h, 20h,	0E3h, 0B0h
		db 0D8h, 0E2h, 20h, 0D6h, 21h, 70h, 70h, 91h, 50h, 90h
		db 0BBh, 0FFh

MUS_SalirPiram:	db 0D4h, 0FCh, 3, 3, 0E1h, 70h,	0E0h, 40h, 70h,	40h, 70h
		db 0FFh

MUS_SalirPiram2:db 0D4h, 0FCh, 3, 3, 0E1h, 40h,	0E0h, 0, 40h, 0, 40h, 0FFh

	IF	(VERSION2)
		db #ff
	ENDIF
	
;------------------------------------------------------------------------------	
;
; Identificador del juego de Konami: OUKE NO TANI
;
;    -00: #AA (Token)
;    -01: Número RC7xx en formato BCD
;    -02: Número de bytes usados para el nombre
;    -03: Nombre en katakana (escrito al revés)
;
;------------------------------------------------------------------------------
		db 95h,	8Fh, 98h, 88h, 82h, 84h, 6, 27h, 0AAh




; ===========================================================================

		MAP     #e000
		
GameStatus:	# 1
					; 0 = Konami Logo
					; 1 = Menu wait
					; 2 = Set demo
					; 3 = Musica de	inicio,	parpadea START PLAY, pone modo juego
					; 4 = Empezando	partida
					; 5 = Jugando /	Mapa
					; 6 = Perdiendo	una vida / Game	Over
					; 7 = Game Over
					; 8 = Stage Clear
					; 9 = Scroll pantalla
					; 10 = Muestra el final	del juego
subStatus:	# 1
controlPlayer:	# 1			; bit 6	= Prota	controlado por el jugador
timer:		# 1
waitCounter:	# 1
tickInProgress:	# 1			; Si el	bit0 esta a 1 no se ejecuta la logica del juego

dummy_1		# 2

KeyTrigger:	# 1
KeyHold:	# 1			; 1 = Arriba, 2	= Abajo, 4 = Izquierda,	8 = Derecha, #10 = Boton A, #20	=Boton B
gameLogoCnt:	# 1

dummy_2		# 2

flagEndPergamino:# 1
					; 1 = Ha terminado de mostar el	pergamino/mapa
CoordKonamiLogo:# 2			; Direccion BG Map (name table)	del logo


MusicChanData:	# 2
musicCh1:	# 12

MusicChanData2:	# 2
musicCh2:	# 12

MusicChanData3:	# 2
musicCh3:	# 12

mixerValuePSG:	# 1
flagSetCaeSnd:	# 1			; Si es	0 hay que inicializar los datos	del sonido de caida
dummy_3		# 2

caidaSndDat:	# 1			; Este byte y los dos anteriores controlan la frecuencia del sonido de caida
dummy:		# 1

KeyTrigger2:	# 1
KeyHold2:	# 1

dummy0:		# 1

record_0000xx:	# 2
record_xx0000:	# 1

dummy_4		# 3

score_0000xx:	# 2
score_xx0000:	# 1

dummy_5		# 4

Vidas:		# 1
flagPiramideMap:# 1
					; 0 = Mostrando	mapa, 1	= Dentro de la piramide
extraLifeCounter:# 1
flagVivo:	# 1
					; 0 = Muerto, 1	= Vivo
piramideActual:	# 1
piramideDest:	# 1
puertaEntrada:	# 1
					; Indica la puerta/direccion por la que	se esta	entrando a la piramide
puertaSalida:	# 1
					; 1 = Arriba, 2	= Abajo, 4 = Izquierda,	8 = Derecha
numFinishGame:	# 1
					; Numero de veces que se ha terminado el juego
dummy_6		# 2

UNKNOWN:	# 1			; (!?) Se usa?
dummy_7		# 2

flagMuerte:	# 1			; No se	usa (!?)
quienEscalera:	# 1			; (!?) Se usa esto? Quien esta en una escalera 0 = Prota. 1 = Momia

dummy_8:	# 1

offsetPlanoSpr:	# 1			; Contador que modifica	el plano en el que son pintados	los sprites, asi se consigue que parpaden en vez de desaparecer
PiramidesPasadas:# 2			; Cada bit indica si la	piramide correspondiente ya esta pasada/terminada
keyTriggerMap:	# 1
keyHoldMap:	# 1
mapPaused:	# 1			; 1 = Pausing

dummy_9:	# 25

keyPressDemo:	# 2			; Puntero a los	controles grabados
KeyHoldCntDemo:	# 1
escaleraData:	# 45

;----------------------------------------------------
; Tabla	de atributos de	los sprites en RAM
; Sprites:
; 0-3 =	Parte izquierda	de la puerta de	la piramide (usada para	tapar al prota y dar sensacion de que pasa por detras)
; 3 = Tambien usado como halo de la piramide en	el mapa
; 4-5 =	Prota
; 6-9 =	Momias
; 15 = Cuchillo	o flecha mapa
;----------------------------------------------------
sprAttrib:	# 1			; Tabla	de atributos de	los sprites en RAM (Y, X, Spr, Col)
puertaXspr:	# 15
protaAttrib:	# 3
protaColorRopa:	# 4
ProtaColorPiel:	# 1
enemyAttrib:	# 16
unk_E0D8:	# 20

; Atributos del	cuchillo al rebotar
knifeAttrib:	# 16
attrPiramidMap:	# 3			; Atributos del	sprite usado para resaltar una piramide	en el mapa (silueta)

colorPiramidMap:# 1			; Color	del outline de la piramide en el mapa
attrFlechaMap:	# 3			; Atributos de la flecha del mapa

colorFlechaMap:	# 1			; Color	de la flecha que indica	a que piramide vamos en	el mapa

dummy_10:	# 2Ch

statusEntrada:	# 1			; Timer	usado en el mapa/pergamino de piramides
					; como status del prota	en las escaleras de entrada/salida
lanzamFallido:	# 1			; 1 = El cuchillo se ha	lanzado	contra un muro y directamente sale rebotando
flagEntraSale:	# 1			; 1 = Entrando o saliendo de la	piramide. Ejecuta una logica especial para este	caso
flagStageClear:	# 1
protaStatus:	# 1			; 0 = Normal
					; 1 = Salto
					; 2 = Cayendo
					; 3 = Escaleras
					; 4 = Lanzando un cuhillo
					; 5 = Picando
					; 6 = Pasando por un apuerta giratoria
					
protaControl:	# 1			; 1 = Arriba, 2	= Abajo, 4 = Izquierda,	8 = Derecha, #10 = Boton A, #20	=Boton B
sentidoProta:	# 1			; 1 = Izquierda, 2 = Derecha
ProtaY:		# 1
ProtaXdecimal:	# 1			; 'Decimales' usados en el calculo de la X. Asi se consiguen velocidades menores a 1 pixel
ProtaX:		# 1
ProtaRoom:	# 1			; Parte	alta de	la coordenada X. Indica	la habitacion de la piramide
protaSpeed:	# 2			; El byte bajo indica la parte "decimal" y el alto la entera
speedRoom:	# 1			; Usando para sumar/restar a la	habitacion cuando se pasa de una a otra
protaMovCnt:	# 1			; Contador usado cada vez que se mueve el prota. (!?) No se usa	su valor
protaFrame:	# 1

; Los siguientes dos bytes se usan para	guardar	un puntero a una tabla con los valores del salto +#0C y	+#0D
timerPergam2:	# 1			; Se usa para hacer una	pausa tras terminar de sonar la	musica del pergamino al	llegar al GOAL
dummy_11:	# 1

flagSalto:	# 1			; 0 = Saltando,	1 = En el suelo
sentidoEscalera:# 1			; 0 = \, 1 = /
					; Tambien usado	para saber si el salto fue en vertical (guarda el estado de las	teclas en el momento del salto.
objetoCogido:	# 1			; #10 =	Cuchillo, #20 =	Pico
accionWaitCnt:	# 1			; Contador usado para controlar	la animacion y duracion	de la accion (lanzar cuchillo, cavar, pasar puerta giratoria)
timerEmpuja:	# 1			; Timer	usado para saber el tiempo que se empuja una puerta giratoria
flagScrolling:	# 1
agujeroCnt:	# 1			; Al comenzar a	pica vale #15

; Datos	del agujero que	se esta	picando
agujeroDat:	# 4			; Y, X,	habitacion

modoSentEsc:	# 1			; Si es	0 guarda en "sentidoEscalera" el tipo de escalera que se coge el prota. 0 = \, 1 = /
momiasPiramid:	# 3*6			; Datos	de las momias que hay en la piramide actual: y,	x (%xxxxx--p), tipo

dummy_12:	# 2
pMomiaProceso:	# 2			; Puntero a los	datos de la momia en proceso
numMomias:	# 1
momiaEnProceso:	# 1
ordenSubir:	# 1
distSubida:	# 1
ordenBajar:	# 1
distBajada:	# 1
momiaDat:	# 16h*4			; 0 = Andando
					; 1 = Salto
					; 2 = Cayendo
					; 3 = Escaleras
					; 4 = Limbo
					; 5 = Aparece
					; 6 = Suicida
					; 7 = pensando
					;
					; +#00 = Status
					; +#01 = Control
					; +#02 = Sentido
					; +#03 = Y
					; +#04 = X decimal
					; +#05 = X
					; +#06 = Room
					; +#07 = Speed X decimal
					; +#08 = Speed X
					; +#09 = Speed Room
					; +#0b = Frame
					; +#11 = Timer
					; +#14 = Tipo momia

puertaCerrada:	# 1			; Vale 1 al cerrarse la	salida

dummy_13:	# 1

numPuertas:	# 1
pyramidDoors:	# 18h			; Y (FF	= Desactivado)
					; X decimales
					; X
					; Habitacion
					; Status (Nibble alto =	Status,	Nibble bajo = contador)
					; Piramide destino
					; Direccion por	la que se entra	/ Flecha del mapa
dummy_14:	# 21

gemasCogidas:	# 1
gemasTotales:	# 1
ElemEnProceso:	# 1			; Usado	para saber la gema o puerta que	se esta	procesando
datosGemas:	# 6Ch			; 0 = Color/activa. Nibble alto	indica el color. El bajo si esta activa	(1) o no (0)
					; 1 = Status
					; 2 = Y
					; 3 = decimales	X
					; 4 = X
					; 5 = habitacion
					; 6-8 =	0, 0, 0
					
					
IDcuchilloCoge:	# 1			; Cuchillo que coge el prota
knifeEnProceso:	# 1
numKnifes:	# 1
;
; Datos	de los cuchillos
; Numero maximo	de cuchillos 6
; Tamaño de la estructura 17 bytes
;
knifesData:	# 66h			; 0 = Status (1	= suelo, 2 = Cogido, 4 = Lanzamiento?, 5= lanzado, 7 =Rebotando)
					; 1 = Sentido (1 = izquierda, 2	= Derecha)
					; 2 = Y
					; 3 = X	decimales
					; 4 = X
					; 5 = Habitacion
					; 6 = Velocidad	decimales
					; 7 = Velocidad	cuchillo
					; 8 = Velocidad	cambio habitacion
					; 9 = Contador movimiento
					; A = Tile backup 1 (fondo)
					; B = Tile backup 2 (guarda dos	tiles al lanzarlo)

idxPicoCogido:	# 1			; Indice del pico cogido por el	prota
numPicos:	# 1

; 5 bytes por entrada
picosData:	# 50h			; 0 = Status
					; 1 = Y
					; 2 = X	decimal
					; 3 = X
					; 4 = Habitacion
GiratEnProceso:	# 1
numDoorGira:	# 1

; 7 bytes por puerta
doorGiraData:	# 0DFh			; 0 = Status (bit 0 = Girando, bits 2-1	= altura + 2)
					; 1 = Y
					; 2 = X	decimal
					; 3 = X
					; 4 = Habitacion
					; 5 = Sentido giro
					; 6 = Contador giro
muroTrampProces:# 1
numMuroTrampa:	# 1 			; Numero de muros trampa que hay en la piramide
muroTrampaDat:	# 5*4			; Y, decimales X, X, habitacion

stackArea:	# 2edh; 301h
stackTop:	# 0
MapaRAMRoot:	# 60h			; La primera fila del mapa no se usa (ocupada por el marcador).	Tambien	usado como inicio de la	pila
MapaRAM:	# 8A0h			; Mapa de las tres posibles habitaciones de la piramide. Cada fila ocupa #60 bytes (#20 * 3)

