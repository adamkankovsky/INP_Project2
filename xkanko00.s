; Vernamova sifra na architekture DLX
; Adam Kankovsky xkanko00

        .data 0x04          ; zacatek data segmentu v pameti
login:  .asciiz "xkanko00!"  ; <-- nahradte vasim loginem
cipher: .space 9 ; sem ukladejte sifrovane znaky (za posledni nezapomente dat 0)

        .align 2            ; dale zarovnavej na ctverice (2^2) bajtu
laddr:  .word login         ; 4B adresa vstupniho textu (pro vypis)
caddr:  .word cipher        ; 4B adresa sifrovaneho retezce (pro vypis)

        .text 0x40          ; adresa zacatku programu v pameti
        .global main        ; 

main: 	addi r5, r0, 0;r5-r12-r15-r22-r29-r0
loopA:	addi r15, r0, 1;
	lb r29, login(r15);
	lb r12, login(r5);
	addi r22, r0, 96;
	sgt  r15,r12,r22;
	beqz r15, number;
	nop;
	nop;
	subi r15, r29, 96;
	add r12, r12, r15;
	sgt r15, r22, r12;
	beqz r15, aupperA;
	nop;
	nop;
	sub r12, r12, r22;
	addi r22, r0, 122;
	add r12, r22, r12;
	sb cipher(r5), r12;
	addi r5, r5, 1;
	j loopB;
	nop;
	nop;

aupperA:addi r22, r0, 123;
	sgt r15, r12, r22;
	beqz r15, aunderZ;
	nop;
	nop;
	sub r12, r12, r22;
	addi r22, r0, 97;
	add r12, r22, r12;
	sb cipher(r5), r12;
	addi r5, r5, 1;
	j loopB;
	nop;
	nop;

aunderZ:sb cipher(r5), r12;
	addi r5, r5, 1;
	j loopB;
	nop;
	nop;


loopB:	addi r15, r0, 2;
	lb r29, login(r15);
	lb r12, login(r5);
	addi r22, r0, 96;
	sgt  r15,r12,r22;
	beqz r15, number;
	nop;
	nop;
	sub r15, r22, r29;
	add r12, r12, r15;
	sgt r15, r22, r12;
	beqz r15, bupperA;
	nop;
	nop;
	sub r12, r12, r22;
	addi r22, r0, 122;
	add r12, r22, r12;
	sb cipher(r5), r12;
	addi r5, r5, 1;
	j loopA;
	nop;
	nop;

bupperA:addi r22, r0, 123;
	sgt r15, r12, r22;
	beqz r15, bunderZ;
	nop;
	nop;
	sub r12, r12, r22;
	addi r22, r0, 97;
	add r12, r22, r12;
	sb cipher(r5), r12;
	addi r5, r5, 1;
	j loopA;
	nop;
	nop;

bunderZ:sb cipher(r5), r12;
	addi r5, r5, 1;
	j loopA;
	nop;
	nop;

number:	addi r12, r0, 0;
	sb cipher(r5), r12;

end:    addi r14, r0, caddr ; <-- pro vypis sifry nahradte laddr adresou caddr
        trap 5  ; vypis textoveho retezce (jeho adresa se ocekava v r14)
        trap 0  ; ukonceni simulace
