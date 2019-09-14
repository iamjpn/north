SECTIONS
{
 . = 0;
 _start = .;
 .head : {
  KEEP(*(.head))
 }

 . = 0x10000;
 parameter_stack_bottom = .;
 .pstack : {
  KEEP(*(.pstack))
 }

 . = 0x12000;
 return_stack_bottom = .;
 .rstack : {
  KEEP(*(.rstack))
 }

 . = 0x1700;
}
