.text
	.global _start

	_start:
		li t0, 10
		li t1, 20
		add t3, t0, t1
		mul t4, t3, t0
		div t5, t4, t0
