本章任务：
1、解决了数据相关问题，load-use没有解决，放到以后解决。


## LLbit模块
规定在MEM阶段读取、WB阶段写入。
有一点需要说明：Regfile、HiLo、LLbit都是在WB阶段写入，且这些寄存器都是上升沿触发的，故准确地说是在WB阶段的下一个时钟上升沿写入，也就是WB结束了，进入下一个阶段时。