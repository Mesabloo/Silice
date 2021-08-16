An example use would be:

```silice
algorithm main(
  output uint$NUM_LEDS$ leds,
  inout  uint8          pmod,
) {
$$for i=1,4 do
  uint1 pmod$i$ = uninitialized;
$$end
$$for i=7,10 do
  uint1 pmod$i$ = uninitialized;
$$end
    
  pmod := {pmod10, pmod9, pmod8, pmod7, pmod4, pmod3, pmod2, pmod1};
    
  __debug("Hello -- %d", 6d24);
}
```
