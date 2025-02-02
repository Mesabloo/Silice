// SL 2020-12-22 @sylefeb
// 
// ------------------------- 
//      GNU AFFERO GENERAL PUBLIC LICENSE
//        Version 3, 19 November 2007
//      
//  A copy of the license full text is included in 
//  the distribution, please refer to it for details.

$$if not bram_depth then
$$ if ICEBREAKER then
$$  bram_depth = 11 
$$ else
$$  bram_depth = 13 -- 13 : 8K ints, ~100 MHz   14 : 16K ints ~90 MHz
$$ end
$$end
$$ bram_size  = 1<<bram_depth

$$config['simple_dualport_bram_wmask_byte_wenable1_width'] = 'data'

algorithm bram_ram_32bits(
  rv32i_ram_provider pram,              // provided ram interface
  input uint26       predicted_addr,    // next predicted address
  input uint1        predicted_correct, // was the prediction correct?
  input uint32       data_override,     // data used as an override by memory mapper
) <autorun> {

  simple_dualport_bram uint32 mem<"simple_dualport_bram_wmask_byte">[$bram_size$] = { file("data.img"), pad(uninitialized) };
  
  uint1 in_scope             <:: ~pram.addr[31,1]; // Note: memory mapped addresses use the top most bits 
  uint$bram_depth$ predicted <:: predicted_addr[2,$bram_depth$];

  uint1 wait_one(0);

$$if verbose then                          
  uint32 cycle = 0;
$$end  
  
  always {
$$if verbose then  
     if (pram.in_valid | wait_one) {
       //__display("[cycle%d] in_scope:%b in_valid:%b wait:%b addr_in:%h rw:%b prev:@%h predok:%b newpred:@%h data_in:%h",in_scope,cycle,pram.in_valid,wait_one,pram.addr[2,24],pram.rw,mem.addr0,predicted_correct,predicted,pram.data_in);
     }
     if (pram.in_valid && ~predicted_correct && (mem.addr0 == pram.addr[2,$bram_depth$])) {
       //__display("########################################### missed opportunity");
     }
$$end
    pram.data_out       = in_scope ? (mem.rdata0 >> {pram.addr[0,2],3b000}) : data_override;
    pram.done           = (predicted_correct & pram.in_valid) | wait_one | pram.rw;
    mem.addr0           = (pram.in_valid & ~predicted_correct & ~pram.rw) // Note: removing pram.rw does not hurt ...
                          ? pram.addr[2,$bram_depth$] // read addr next (wait_one)
                          : predicted; // predict
    mem.addr1           = pram.addr[2,$bram_depth$];
    mem.wenable1        = pram.wmask & {4{pram.rw & pram.in_valid & in_scope}};
    mem.wdata1          = pram.data_in;    
$$if verbose then  
     if (pram.in_valid | wait_one) {                        
       //__display("          done:%b wait:%b pred:@%h out:%h wen:%b",pram.done,wait_one,mem.addr0,pram.data_out,mem.wenable1[0,4]);  
     }
    cycle = cycle + 1;
$$end    
    wait_one            = (pram.in_valid & ~predicted_correct & ~pram.rw);
  }
}
