ENTRY(_start)

SECTIONS
{
  /* Code starts at address 0 */
  . = 0x00000000;

  .text : {
    *(.text.entry)
    *(.text*)
  }

  .rodata : {
    *(.rodata*)
  }

  .data : {
    *(.data*)
  }

  .bss : {
    *(.bss*)
    *(COMMON)
  }
}

