#define RSTACK %r1
#define PSTACK %r2
#define NEXTWP %r3

#define FIXUP_ENDIAN						   \
	tdi   0,0,0x48;	  /* Reverse endian of b . + 8		*/ \
	b     191f;	  /* Skip trampoline if endian is good	*/ \
	.long 0xa600607d; /* mfmsr r11				*/ \
	.long 0x01006b69; /* xori r11,r11,1			*/ \
	.long 0x05009f42; /* bcl 20,31,$+4			*/ \
	.long 0xa602487d; /* mflr r10				*/ \
	.long 0x14004a39; /* addi r10,r10,20			*/ \
	.long 0xa64b5a7d; /* mthsrr0 r10			*/ \
	.long 0xa64b7b7d; /* mthsrr1 r11			*/ \
	.long 0x2402004c; /* hrfid				*/ \
191:


/* Load an immediate 64-bit value into a register */
#define LOAD_IMM64(r, e)			\
	lis     r,(e)@highest;			\
	ori     r,r,(e)@higher;			\
	rldicr  r,r, 32, 31;			\
	oris    r,r, (e)@h;			\
	ori     r,r, (e)@l;


/* NEXT macro */
.macro NEXT
	lwz	%r4, 0(NEXTWP)
	addi	NEXTWP, NEXTWP, 4
	/* Load from the code word */
	lwz	%r5, 0(%r4)
	/* Load link register and branch */
	mtlr	%r5
	blr
.endm

.macro PUSHRSP reg
	stw	\reg, 0(RSTACK)
	addi	RSTACK, RSTACK, -4
.endm

.macro POPRSP reg
	addi	RSTACK, RSTACK, 4
	lwz	\reg, 0(RSTACK)
.endm

.macro PUSHPSP reg
	stw	\reg, 0(PSTACK)
	addi	PSTACK, PSTACK, -4
.endm

.macro POPPSP reg
	addi	PSTACK, PSTACK, 4
	lwz	\reg, 0(PSTACK)
.endm

	.section ".head","ax"

/*
 * Microwatt comes in at 0 as little endian so we do not need to worry about
 * FIXUP_ENDIAN.
 */
	. = 0
.global _start
_start:
	b	boot_entry

	/*
	 * QEMU comes in at 0x10. Set qemu_console to distingush from
	 * microwatt.
	 */
	. = 0x10
	FIXUP_ENDIAN
	b	boot_entry

.global boot_entry
boot_entry:
	mr	%r14, %r3
1:
	/* r1 = rstack / r2 = pstack / r3 = instruction p */
	LOAD_IMM64(%r1, return_stack_top)
	LOAD_IMM64(%r2, parameter_stack_top)

	LOAD_IMM64(%r5, 3)
	PUSHPSP %r5
	LOAD_IMM64(%r5, 4)
	PUSHPSP %r5
	LOAD_IMM64(NEXTWP, cold_start)
	NEXT
	mr	%r3, %r14
	b	1b

#define EXCEPTION(nr)		\
	.= nr			;\
	b	.

	/* More exception stubs */
	EXCEPTION(0x300)
	EXCEPTION(0x380)
	EXCEPTION(0x400)
	EXCEPTION(0x480)
	EXCEPTION(0x500)
	EXCEPTION(0x600)
	EXCEPTION(0x700)
	EXCEPTION(0x800)
	EXCEPTION(0x900)
	EXCEPTION(0x980)
	EXCEPTION(0xa00)
	EXCEPTION(0xb00)
	EXCEPTION(0xc00)
	EXCEPTION(0xd00)
	EXCEPTION(0xe00)
	EXCEPTION(0xe20)
	EXCEPTION(0xe40)
	EXCEPTION(0xe60)
	EXCEPTION(0xe80)
	EXCEPTION(0xf00)
	EXCEPTION(0xf20)
	EXCEPTION(0xf40)
	EXCEPTION(0xf60)
	EXCEPTION(0xf80)
	EXCEPTION(0x1000)
	EXCEPTION(0x1100)
	EXCEPTION(0x1200)
	EXCEPTION(0x1300)
	EXCEPTION(0x1400)
	EXCEPTION(0x1500)
	EXCEPTION(0x1600)

cold_start:
	.int QUIT

DOCOL:
	PUSHRSP	NEXTWP
	mr	NEXTWP, %r4
	addi	NEXTWP, NEXTWP, 4
	NEXT

	.set F_IMMED,0x80
	.set F_HIDDEN,0x20
	.set F_LENMASK,0x1f	// length mask

	// Store the chain of links.
	.set link,0
	.macro defword name, namelen, flags=0, label
	.globl name_\label
name_\label :
	.int link		// link
	.set link,name_\label
	.byte \flags+\namelen	// flags + length byte
	.ascii "\name"		// the name
	.align 2		// padding to next 4 byte boundary
	.globl \label
\label :
	.int DOCOL
	// list of word pointers follow
	.endm

	.macro defcode name, namelen, flags=0, label
	.globl name_\label
name_\label :
	.int link		// link
	.set link,name_\label
	.byte \flags+\namelen	// flags + length byte
	.ascii "\name"		// the name
	.align 2 		// padding to next 4 byte boundar
	.globl \label
\label :
	.int code_\label	// codeword
	.globl code_\label
code_\label :			// assembler code follows
	.endm

/*
 * On powerpc the only ways for indirect are the branch register and target
 * registers So we need to move from the return stack to the link register and
 * then branch there Going to make a word 4 bytes
 */

	// x -
	defcode "DROP",4,,DROP
	addi PSTACK, PSTACK, 4
	NEXT

	// x y - y x
	defcode "SWAP",4,,SWAP
	POPPSP %r4
	POPPSP %r5
	PUSHPSP %r4
	PUSHPSP %r5
	NEXT

	// x - x x
	defcode "DUP",3,,DUP
	lwz	%r4, 4(PSTACK)
	PUSHPSP %r4
	NEXT

	// x y -- x y x
	defcode "OVER",4,,OVER
	lwz	%r4, 8(PSTACK)
	PUSHPSP %r4
	NEXT

	// a b c | b c a
	defcode "ROT",3,,ROT
	POPPSP %r4 // c
	POPPSP %r5 // b
	POPPSP %r6 // a
	PUSHPSP %r5
	PUSHPSP %r4
	PUSHPSP %r6
	NEXT

	// a b c | c a b
	defcode "-ROT",4,,NROT
	POPPSP %r4 // c
	POPPSP %r5 // b
	POPPSP %r6 // a
	PUSHPSP %r4
	PUSHPSP %r6
	PUSHPSP %r5
	NEXT

	defcode "2DROP",5,,TWODROP // drop top two elements of stack
	addi PSTACK, PSTACK, 8
	NEXT

	defcode "2DUP",4,,TWODUP // duplicate top two elements of stack
	lwz	%r4, 4(PSTACK)
	lwz	%r5, 8(PSTACK)
	PUSHPSP	%r5
	PUSHPSP	%r4
	NEXT

	defcode "2SWAP",5,,TWOSWAP // swap top two pairs of elements of stack
	POPPSP %r4
	POPPSP %r5
	POPPSP %r6
	POPPSP %r7
	PUSHPSP %r5
	PUSHPSP %r4
	PUSHPSP %r7
	PUSHPSP %r6
	NEXT

	defcode "?DUP",4,,QDUP	// duplicate top of stack if non-zero
	lwz	%r4, 4(PSTACK)
	cmpwi	cr0, %r4, 0
	beq	1f
	PUSHPSP %r4
1:
	NEXT

	defcode "1+",2,,INCR
	lwz	%r4, 4(PSTACK)
	addi	%r4, %r4, 1
	stw	%r4, 4(PSTACK)
	NEXT

	defcode "1-",2,,DECR
	lwz	%r4, 4(PSTACK)
	subi	%r4, %r4, 1
	stw	%r4, 4(PSTACK)
	NEXT

	defcode "4+",2,,INCR4
	lwz	%r4, 4(PSTACK)
	addi	%r4, %r4, 4
	stw	%r4, 4(PSTACK)
	NEXT

	defcode "4-",2,,DECR4
	lwz	%r4, 4(PSTACK)
	subi    %r4, %r4, 4
	stw	%r4, 4(PSTACK)
	NEXT

	defcode "+",1,,ADD
	POPPSP %r4
	POPPSP %r5
	add	%r4, %r4, %r5
	PUSHPSP %r4
	NEXT

	// XXX
	defcode "-",1,,SUB
	POPPSP %r4 // top
	POPPSP %r5
	sub	%r4, %r5, %r4
	PUSHPSP %r4
	NEXT

	defcode "*",1,,MUL
	POPPSP %r4
	POPPSP %r5
	mullw	%r4, %r4, %r5
	PUSHPSP %r4
	NEXT

	defcode "/",1,,DIV
	POPPSP %r4 // divisor
	POPPSP %r5
	divw	%r4, %r5, %r4
	PUSHPSP %r4
	NEXT

	defcode "MOD",3,,MOD
	POPPSP %r4 // divisor
	POPPSP %r5
	modsw	%r4, %r5, %r4
	PUSHPSP %r4
	NEXT

	defcode "/MOD",4,,DIVMOD
	POPPSP %r4 // divisor
	POPPSP %r5
	modsw	%r6, %r5, %r4
	divw	%r4, %r5, %r4
	PUSHPSP %r6
	PUSHPSP %r4
	NEXT

	defcode "=",1,,EQU	// top two words are equal?
	POPPSP %r4
	POPPSP %r5
	li	%r6, 0
	cmpw	cr0, %r4, %r5
	bne	1f
	not	%r6, %r6
1:
	PUSHPSP %r6
	NEXT

	defcode "<>",2,,NEQU	// top two words are not equal?
	POPPSP %r4
	POPPSP %r5
	li	%r6, 0
	not	%r6, %r6
	cmpw	cr0, %r4, %r5
	bne	1f
	li	%r6, 0
1:
	PUSHPSP %r6
	NEXT

	// ( n1 n2 — flag )
	// Returns true if n1 is less than n2.
	defcode "<",1,,LT
	POPPSP %r4
	POPPSP %r5
	li	%r6, 0
	not	%r6, %r6
	cmpw	cr0, %r5, %r4
	blt	1f
	li	%r6, 0
1:
	PUSHPSP %r6
	NEXT

	defcode ">",1,,GT
	POPPSP %r4
	POPPSP %r5
	li	%r6, 0
	not	%r6, %r6
	cmpw	cr0, %r5, %r4
	bgt	1f
	li	%r6, 0
1:
	PUSHPSP %r6
	NEXT

	defcode "<=",2,,LE
	POPPSP %r4
	POPPSP %r5
	li	%r6, 0
	not	%r6, %r6
	cmpw	cr0, %r5, %r4
	ble	1f
	li	%r6, 0
1:
	PUSHPSP %r6
	NEXT

	defcode ">=",2,,GE
	POPPSP %r4
	POPPSP %r5
	li	%r6, 0
	not	%r6, %r6
	cmpw	cr0, %r5, %r4
	bge	1f
	li	%r6, 0
1:
	PUSHPSP %r6
	NEXT

	defcode "0=",2,,ZEQU	// top of stack equals 0?
	POPPSP %r4
	li	%r6, 0
	cmpwi	cr0, %r4, 0
	bne	1f
	not	%r6, %r6
1:
	PUSHPSP %r6
	NEXT

	defcode "0<>",3,,ZNEQU	// top of stack not 0?
	POPPSP %r4
	li	%r6, 0
	not	%r6, %r6
	cmpwi	cr0, %r4, 0
	bne	1f
	li	%r6, 0
1:
	PUSHPSP %r6
	NEXT

	defcode "AND",3,,AND	// bitwise AND
	POPPSP %r4
	POPPSP %r5
	and	%r4, %r4, %r5
	PUSHPSP %r4
	NEXT

	defcode "OR",2,,OR	// bitwise OR
	POPPSP %r4
	POPPSP %r5
	or	%r4, %r4, %r5
	PUSHPSP %r4
	NEXT

	defcode "XOR",3,,XOR	// bitwise XOR
	POPPSP %r4
	POPPSP %r5
	xor	%r4, %r4, %r5
	PUSHPSP %r4
	NEXT

	defcode "INVERT",6,,INVERT // this is the FORTH bitwise "NOT" function (cf. NEGATE and NOT)
	POPPSP %r4
	not	%r4, %r4
	PUSHPSP %r4
	NEXT

	defcode "EXIT",4,,EXIT
	POPRSP NEXTWP
	NEXT

	defcode "LIT",3,,LIT
	lwz	%r4, 0(NEXTWP)
	addi	NEXTWP, NEXTWP, 4
	PUSHPSP %r4
	NEXT

	defcode "!",1,,STORE
	POPPSP %r4 // address
	POPPSP %r5 // data
	stw	%r5, 0(%r4)
	NEXT

	defcode "@",1,,FETCH
	POPPSP %r4 // address
	lwz %r4, 0(%r4)
	PUSHPSP	%r4
	NEXT

	defcode "+!",2,,ADDSTORE
	POPPSP %r4 // address
	POPPSP %r5 // amount to add
	lwz	%r6, 0(%r4)
	add	%r6, %r6, %r5
	stw	%r6, 0(%r4)
	NEXT

	defcode "-!",2,,SUBSTORE
	POPPSP %r4 // address
	POPPSP %r5 // amount to add
	lwz	%r6, 0(%r4)
	sub	%r6, %r6, %r5
	stw	%r6, 0(%r4)
	NEXT

	defcode "C!",2,,STOREBYTE
	POPPSP %r4 // address
	POPPSP %r5 // data
	stb	%r5, 0(%r4)
	NEXT

	defcode "C@",2,,FETCHBYTE
	POPPSP %r4 // address
	lbz %r4, 0(%r4)
	PUSHPSP	%r4
	NEXT

	.macro defvar name, namelen, flags=0, label, initial=0
	defcode \name,\namelen,\flags,\label
	LOAD_IMM64(%r4, var_\name)
	PUSHPSP	%r4
	NEXT
var_\name:
	.int \initial
	.endm

	defvar "STATE",5,,STATE
	defvar "HERE",4,,HERE, END
	defvar "LATEST",6,,LATEST,name_INTERPRET//name_ADD// must be last in built-in dictionary
	defvar "S0",2,,SZ
	defvar "BASE",4,,BASE,10

	/* define constants ... */
	/* think about word length again */
	.macro defconst name, namelen, flags=0, label, value
	defcode \name,\namelen,\flags,\label
	LOAD_IMM64(%r4, \value)
	PUSHPSP	%r4
	NEXT
	.endm

	defconst "VERSION",7,,VERSION,1
	defconst "R0",2,,RZ,return_stack_top
	defconst "DOCOL",5,,__DOCOL,DOCOL
	defconst "F_IMMED",7,,__F_IMMED,F_IMMED
	defconst "F_HIDDEN",8,,__F_HIDDEN,F_HIDDEN
	defconst "F_LENMASK",9,,__F_LENMASK,F_LENMASK

	/* Return stack */
	defcode ">R",2,,TOR
	POPPSP %r4
	PUSHRSP %r4
	NEXT

	defcode "R>",2,,FROMR
	POPRSP %r4
	PUSHPSP %r4
	NEXT

	defcode "RSP@",4,,RSPFETCH
	PUSHPSP RSTACK
	NEXT

	defcode "RSP!",4,,RSPSTORE
	POPPSP RSTACK
	NEXT

	defcode "RDROP",5,,RDROP
	addi	RSTACK, RSTACK, 4
	NEXT

	/* Parameter stack */
	defcode "DSP@",4,,DSPFETCH
	PUSHPSP	PSTACK
	NEXT

	defcode "DSP!",4,,DSPSTORE
	POPPSP PSTACK
	NEXT

#define QEMU_UART_BASE 0x60300d00103f8

#define REG_RBR		0
#define REG_THR		0
#define REG_DLL		0
#define REG_IER		1
#define REG_DLM		1
#define REG_FCR		2
#define REG_IIR		2
#define REG_LCR		3
#define REG_MCR		4
#define REG_LSR		5
#define REG_MSR		6
#define REG_SCR		7

#define LSR_DR		0x01    /* Data ready */
#define LSR_OE		0x02    /* Overrun */
#define LSR_PE		0x04    /* Parity error */
#define LSR_FE		0x08    /* Framing error */
#define LSR_BI		0x10    /* Break */
#define LSR_THRE	0x20    /* Xmit holding register empty */
#define LSR_TEMT	0x40    /* Xmitter empty */
#define LSR_ERR		0x80    /* Error */

#define LCR_DLAB 	0x80    /* DLL access */

#define IER_RX		0x01
#define IER_THRE	0x02
#define IER_ALL		0x0f

eol:
	.int 0
	defcode "KEY",3,,KEY
	bl	_KEY
	PUSHPSP	%r4
	NEXT
_KEY:
	LOAD_IMM64(%r4, QEMU_UART_BASE)
1:
	lbz	%r5, REG_LSR(%r4)
	andi.	%r5, %r5, LSR_DR /* Got data ? */
	cmpwi	cr0, %r5, 0
	beq	1b /* empty */
	lbz	%r4, REG_THR(%r4)
	cmpwi	%r4, '\r'
	beq	2f
	b	_EMIT
2:
	LOAD_IMM64(%r5, eol)
	li	%r6, 1
	stb	%r6, 0(%r5)
	blr

	defcode "EMIT",4,,EMIT
	POPPSP %r4
	bl	_EMIT
	NEXT
_EMIT:
	LOAD_IMM64(%r6, QEMU_UART_BASE)
1:
	lbz	%r5, REG_LSR(%r6)
	andi.	%r5, %r5, LSR_THRE /* Empty ? */
	cmpwi	cr0, %r5, 0
	beq	1b /* Not empty */
/*
	cmpwi	%r4, '\r'
	bne	3f
	li	%r4, '\n'
3:
	cmpwi	%r4, '\n'
	bne	2f
	li	%r5, '\r'
	blr
	stb	%r5, REG_RBR(%r6)
2:
*/
	stb	%r4, REG_RBR(%r6)
	blr

	defcode "WORD",4,,WORD
	bl _WORD
	PUSHPSP	%r4 // base addr
	PUSHPSP	%r5 // length
	NEXT

_WORD:
	mflr	%r8
1:
	bl	_KEY // get char in %r4
	cmpwi	cr0, %r4, '\\'
	beq	3f
	cmpwi	cr0, %r4, ' '
	beq	1b

	LOAD_IMM64(%r9, word_buffer)
	mr	%r7, %r9 // keep
	addi	%r9, %r9, -1
2:
	stbu	%r4, 1(%r9)
	bl	_KEY
	cmpwi	cr0, %r4, ' '
	beq	4f
	cmpwi	cr0, %r4, '\n'
	beq	4f
	cmpwi	cr0, %r4, '\r'
	beq	4f
	b	2b

4:
	addi	%r9, %r9, 1
	sub	%r5, %r9, %r7
	mr	%r4, %r7
	mtlr	%r8
	blr

3:
	bl	_KEY
	cmpwi	cr0, %r4, '\n'
	beq	1b
	cmpwi	cr0, %r4, '\r'
	beq	1b
	b	3b

word_buffer:
	.space 32

	defcode "NUMBER",6,,NUMBER
	POPPSP	%r4 // length
	POPPSP	%r5 // start address
	bl 	_NUMBER
	PUSHPSP	%r6 // number
	PUSHPSP %r4 // un parsed chars
	NEXT

// Test more
_NUMBER:
	li	%r6, 0
	li	%r7, 0

	cmpwi	%r4, 0 // zero length
	beq	5f

	LOAD_IMM64(%r8, var_BASE)
	lwz	%r8, 0(%r8) // r8 holds base

	// Check for -
	lbz	%r9, 0(%r5)
	addi	%r5, %r5, 1
	li	%r10, 0
	cmpwi	cr0, %r9, '-'
	bne	2f
	not	%r10, %r10
	addi	%r4, %r4, -1
	cmpwi	%r4, 0
	bne	1f
	li	%r4, 1
	blr


1:
	mullw	%r6, %r6, %r8
	lbz	%r9, 0(%r5)
	addi	%r5, %r5, 1

2:
	subi	%r9, %r9, '0'
	cmpwi	%r9, 0
	blt	4f
	cmpwi	%r9, 10
	ble	3f
	subi	%r9, %r9, 17 // 'A' - '0' = 17
	blt	4f
	addi	%r9, %r9, 10

3:
	cmpw	%r9, %r8 // greater than base
	bge	4f

	add	%r6, %r6, %r9
	addi	%r4, %r4, -1
	cmpwi	%r4, 0
	bne	1b

4:
	cmpwi	%r10, 0
	beq	5f
	neg	%r6, %r6

5:
	blr

	defcode "FIND",4,,FIND
	POPPSP %r4 // length
	POPPSP %r5 // address
	bl _FIND
	PUSHPSP %r4
	NEXT

_FIND:

	mfctr	%r10 // copy ctr
	LOAD_IMM64(%r6, var_LATEST)
	lwz	%r6, 0(%r6)
1:
	cmpwi	cr0, %r6, 0 // null
	beq	4f

	lbz	%r7, 4(%r6)
	andi.	%r7, %r7, F_HIDDEN|F_LENMASK
	cmpw	cr0, %r4, %r7
	bne	2f

	PUSHPSP	%r5 // keep address

	// string checking ...
	mr	%r7, %r6
	addi	%r7, %r7, 4 // 5 - 1
	addi	%r5, %r5, -1

	mtctr	%r4
5:
	lbzu	%r8, 1(%r7)
	lbzu	%r9, 1(%r5)
	cmpw	%r8, %r9
	bne	3f // not the same
	bdnz	5b

	mtctr	%r10
	POPPSP	%r5
	mr	%r4, %r6
	blr
3:
	POPPSP	%r5
2:
	lwz	%r6, 0(%r6)
	b	1b

4:
	li	%r4, 0
	mtctr	%r10
	blr

	defcode ">CFA",4,,TCFA
	POPPSP %r4
	bl	_TCFA
	PUSHPSP	%r4
	NEXT

_TCFA:
	addi	%r4, %r4, 4 // skip link pointer
	lbz	%r5, 0(%r4) // load flags+len
	addi	%r4, %r4, 1 // skip flags + len
	andi.	%r5, %r5, F_LENMASK
	add	%r4, %r4, %r5
	li	%r5, (4 - 1)
	add	%r4, %r4, %r5 // going to align to 4
	not	%r5, %r5
	and	%r4, %r4, %r5
	blr

	defword ">DFA",4,,TDFA
	.int TCFA
	.int INCR4
	.int EXIT

	defcode "CREATE",6,,CREATE
	mfctr	%r0
	POPPSP %r4 // length
	POPPSP %r5 // address of name

	// Link pointer
	// Copy latest to HERE aka new header
	LOAD_IMM64(%r7, var_LATEST)
	lwz	%r7, 0(%r7)
	LOAD_IMM64(%r6, var_HERE)
	lwz	%r6, 0(%r6)
	stw	%r7, 0(%r6)
	addi	%r6, %r6, 4

	// Length byte and word itself
	stb	%r4, 0(%r6)
	addi	%r6, %r6, 1

	//Now the word
	mtctr	%r4
1:
	lbz	%r7, 0(%r5)
	stb	%r7, 0(%r6)
	addi	%r5, %r5, 1
	addi	%r6, %r6, 1
	bdnz	1b

	li	%r7, (4 - 1)
	add	%r6, %r6, %r7 // going to align to 4
	not	%r7, %r7
	and	%r6, %r6, %r7

	LOAD_IMM64(%r8, var_HERE)
	LOAD_IMM64(%r9, var_LATEST)
	lwz	%r10, 0(%r8)
	stw	%r10, 0(%r9)
	stw	%r6, 0(%r8)

	mtctr	%r0
	NEXT

	defcode ",",1,,COMMA
	POPPSP %r4
	bl	_COMMA
	NEXT

_COMMA:
	LOAD_IMM64(%r5, var_HERE)
	lwz	%r6, 0(%r5)
	stw	%r4, 0(%r6)
	addi	%r6, %r6, 4
	stw	%r6, 0(%r5)
	blr

	defcode "[",1,F_IMMED,LBRAC
	LOAD_IMM64(%r4, var_STATE)
	li	%r5, 0
	stw	%r5, 0(%r4)
	NEXT

	defcode "]",1,,RBRAC
	LOAD_IMM64(%r4, var_STATE)
	li	%r5, 1
	stw	%r5, 0(%r4)
	NEXT

	defword ":",1,,COLON
	.int WORD		// Get the name of the new word
	.int CREATE		// CREATE the dictionary entry / header
	.int LIT, DOCOL, COMMA	// Append DOCOL  (the codeword).
	.int LATEST, FETCH, HIDDEN // Make the word hidden (see below for definition).
	.int RBRAC		// Go into compile mode.
	.int EXIT		// Return from the function.

	defword ";",1,F_IMMED,SEMICOLON
	.int LIT, EXIT, COMMA	// Append EXIT (so the word will return).
	.int LATEST, FETCH, HIDDEN // Toggle hidden flag -- unhide the word
	.int LBRAC		// Go back to IMMEDIATE mode.
	.int EXIT		// Return from the function.

	defcode "IMMEDIATE",9,F_IMMED,IMMEDIATE
	LOAD_IMM64(%r4, var_LATEST)
	lwz	%r4, 0(%r4)
	addi	%r4, %r4, 4
	lbz	%r5, 0(%r4)
	xori	%r5, %r5, F_IMMED
	stb	%r5, 0(%r4)
	NEXT

	defcode "HIDDEN",6,,HIDDEN
	POPPSP %r4
	addi	%r4, %r4, 4
	lbz	%r5, 0(%r4)
	xori	%r5, %r5, F_HIDDEN
	stb	%r5, 0(%r4)
	NEXT

	defword "HIDE",4,,HIDE
	.int WORD		// Get the word (after HIDE).
	.int FIND		// Look up in the dictionary.
	.int HIDDEN		// Set F_HIDDEN flag.
	.int EXIT		// Return.

	defcode "'",1,,TICK
	lwz	%r4, 0(NEXTWP)
	addi	NEXTWP, NEXTWP, 4
	PUSHPSP	%r4
	NEXT

	defcode "BRANCH",6,,BRANCH
	lwz	%r4, 0(NEXTWP)
	extsh	%r4, %r4
	add	NEXTWP, NEXTWP, %r4
	NEXT

	defcode "0BRANCH",7,,ZBRANCH
	POPPSP	%r4
	cmpwi	%r4, 0
	beq	code_BRANCH
	lwz	%r4, 0(NEXTWP)
	extsh	%r4, %r4
	addi	NEXTWP, NEXTWP, 4
	NEXT

	defcode "LITSTRING",9,,LITSTRING
	lwz	%r4, 0(NEXTWP)
	addi	NEXTWP, NEXTWP, 4 // get length of string
	PUSHPSP NEXTWP
	PUSHRSP %r4
	add	NEXTWP, NEXTWP, %r4
	li	%r5, (4 - 1)
	add	NEXTWP, NEXTWP, %r5 // going to align to 4
	not	%r5, %r5
	and	NEXTWP, NEXTWP, %r5
	NEXT

	defcode "TELL",4,,TELL
	mfctr	%r0
	POPPSP %r4 // length
	POPPSP %r5 // address
	mtctr	%r4
1:
	lbz	%r4, 0(%r5)
	addi	%r5, %r5, 1
	bl _EMIT
	bdnz 1b

	mtctr	%r0
	NEXT

	defcode "OK",2,,OK
	bl _OK
	NEXT
_OK:
	mflr	%r0
	LOAD_IMM64(%r9, eol)
	lbz	%r10, 0(%r9)
	cmpwi	%r10, 1
	bne	1f
	li	%r4, '\t'
	bl	_EMIT
	li	%r4, 'o'
	bl	_EMIT
	li	%r4, 'k'
	bl	_EMIT
	li	%r4, '\r'
	bl	_EMIT
	li	%r4, '\n'
	bl	_EMIT
1:
	li	%r10, 0
	stb	%r10, 0(%r9)
	mtlr	%r0
	blr

	defcode "ERR",3,,ERR
	bl _ERR
	NEXT
_ERR:
	mflr	%r0
	li	%r4, '\t'
	bl	_EMIT
	li	%r4, 'e'
	bl	_EMIT
	li	%r4, 'r'
	bl	_EMIT
	li	%r4, 'r'
	bl	_EMIT
	li	%r4, '\r'
	bl	_EMIT
	li	%r4, '\n'
	bl	_EMIT
1:
	li	%r10, 0
	stb	%r10, 0(%r9)
	mtlr	%r0
	blr

	defcode "CR",2,,CR
	li	%r4, '\r'
	bl	_EMIT
	li	%r4, '\n'
	bl	_EMIT
	NEXT

	defcode "CHAR",4,,CHAR
	bl	_WORD
	lbz	%r4, 0(%r4)
	PUSHPSP	%r4
	NEXT

interpret_is_lit:
	.int	0

	defword "QUIT",4,,QUIT
	.int RZ,RSPSTORE	// R0 RSP!, clear the return stack
	.int INTERPRET		// interpret the next word
	.int BRANCH,-8		// and loop (indefinitely)

	defcode "INTERPRET",9,,INTERPRET
	LOAD_IMM64(%r6, interpret_is_lit)
	li	%r4, 0
	stb	%r4, 0(%r6)

	bl _WORD		// Returns %ecx = length, %edi = pointer to word.
	mr	%r12, %r4
	mr	%r13, %r5
	mr	%r5, %r12 //
	mr	%r4, %r13 //
	bl	_FIND
	cmpwi	%r4, 0 // Found?
	beq	1f

	// In the dictionary
	lbz	%r9, 4(%r4) // get flags
	bl	_TCFA
	andi.	%r9, %r9, F_IMMED
	cmpwi	%r9, F_IMMED
	beq	4f // Straight to exec

	b	2f


1: // Not in dictionary
	LOAD_IMM64(%r6, interpret_is_lit)
	li	%r4, 1
	stb	%r4, 0(%r6)

	mr	%r5, %r12 //
	mr	%r4, %r13 //
	bl	_NUMBER
	mr	%r8, %r6 // keep number
	cmpwi	%r4, 0
	bgt	6f
	LOAD_IMM64(%r4, LIT)

2:
	LOAD_IMM64(%r7, var_STATE)
	lwz	%r7, 0(%r7)
	cmpwi	%r7, 0
	beq	4f // executing

	// Appending ...
	bl	_COMMA
	LOAD_IMM64(%r6, interpret_is_lit)
	lwz	%r6, 0(%r6)
	cmpwi	%r6, 0
	beq	3f
	mr	%r4, %r8
	bl	_COMMA

3:
	NEXT


4:
	mr	%r11, %r4
	bl	_OK
	LOAD_IMM64(%r6, interpret_is_lit)
	lbz	%r6, 0(%r6)
	cmpwi	%r6, 0
	bne	5f

	// Not a literal, execute now
	mr	%r4, %r11
	lwz	%r5, 0(%r4)
	mtlr	%r5
	blr

5:
	PUSHPSP	%r8
	NEXT

6:
	bl	_ERR
	NEXT

END:
	.int 0xff

.section ".pstack","ax"
.global parameter_stack_bottom
parameter_stack_bottom:
	.space 0x1000

.global parameter_stack_top
parameter_stack_top:


.section ".rstack","ax"
.global return_stack_bottom
return_stack_bottom:
	.space 0x1000
.global return_stack_top
return_stack_top:
