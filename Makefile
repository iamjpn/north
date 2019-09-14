CROSS_COMPILE = powerpc64le-linux-gnu-
CC = $(CROSS_COMPILE)gcc
LD = $(CROSS_COMPILE)ld
OBJCPY = $(CROSS_COMPILE)objcopy

head: head.elf
	$(OBJCPY) -O binary head.elf head

head.elf: head.o
	$(LD) -o head.elf -EL -N -T powerpc.lds head.o

head.o: head.S
	$(CC) -c -g -mlittle-endian head.S

clean:
	rm head.elf head.o head
