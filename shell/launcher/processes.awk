# top's second look at one's processes, each as its pid, its share of the
# processor, its memory in MiB and its command line, a tab apart. top says how
# much memory with a letter for the unit, or none for KiB.
/^ *PID/ { block++; next }
block == 2 && NF >= 12 && count < 300 {
	sub(",", ".", $9)
	sub(",", ".", $6)
	unit = substr($6, length($6))
	memory = $6 + 0
	if (unit == "g")
		memory *= 1024
	else if (unit == "t")
		memory *= 1048576
	else if (unit != "m")
		memory /= 1024
	command = $12
	for (i = 13; i <= NF; i++)
		command = command " " $i
	print $1 "\t" $9 "\t" memory "\t" command
	count++
}
