# Load from memory and then forward the read value (requires stall of pipeline)

.data
	val: .word 0x10010004 0xFFFFFFFF 0x1234abcd
	
.text
main:
	la x1, val

	lw x2, 0(x1)
	lhu x3, 4(x2)
    addi x3, x3, 1

	addi x4, x4, 1

	sw x4, 0(x1)
	lw x5, 0(x1)
	
halt:	j halt
