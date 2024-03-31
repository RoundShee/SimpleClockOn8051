;书P76
;ST12864程序
;占用P2做并行输出
;且占用一些
RST		BIT		P1.3
RS      BIT		P1.4
RW      BIT     P1.5
EN      BIT     P1.6
SONG    EQU     20H         ;要写入数据的存储单元-RAM 目前与12864不冲突
READ    EQU     21H         ;读出数据存储单元
XUNHUAN EQU     22H         ;循环变量单元
COUNT   EQU     23H         ;查表计数器

;初始化
        CLR     RST         ;芯片复位上电
        LCALL   DELAY
        SETB    RST
        LCALL   ST12864_INT ;初始化12864
        LCALL   HANZI_WRITE ;调用显示汉字子程序
        ;没了
TABLE:  DB      "12大连理工大学12";第一行
        DB      "123456789123456";第三行
		DB      "222222222222222";第二行
		DB      "444444444444444";第四行

;模块初始化程序
ST12864_INT:                ;模块初始化程序
        MOV     SONG,#30H   ;基本指令集操作 的控制字
        LCALL   SEND_ML     ;送命令子程序
        MOV     SONG,#01H   ;清除屏幕
        LCALL   SEND_ML
        MOV     SONG,#06H   ;设定点 指令控制字 (AC+1 图形不动 光标右移)
        LCALL   SEND_ML
        MOV     SONG,#0CH
		LCALL	SEND_ML
		RET

;送命令程序
SEND_ML:					;送命令子程序
		LCALL	CHK_BUSY
		MOV		P2,SONG
		CLR		RS
		CLR		RW
		SETB	EN
		LCALL	DELAY
		CLR		EN
		RET

;查询屏幕状态程序
CHK_BUSY:					;查询屏幕状态子程序
		MOV		P2,#0FFH
		CLR		RS
		SETB	RW
		SETB	EN
CHK_LOP:MOV		A,P2
		JB		P2.7,CHK_LOP
		CLR		EN
		RET

;写汉字子程序
HANZI_WRITE:				;写汉字子程序
		MOV		SONG,#80H	;设定DDRAM地址AC=0
		LCALL	SEND_ML
		MOV		XUNHUAN,#32H
		MOV		DPTR,#TABLE
		MOV		A,#00H
		MOV		COUNT,#00H
HANZI_LOOP:
		MOVC	A,@A+DPTR
		MOV		SONG,A
		LCALL	SEND_SJ
		INC		COUNT
		MOV		A,COUNT
		DJNZ	XUNHUAN,HANZI_LOOP
		RET

;发送数据子程序
SEND_SJ:
		LCALL	CHK_BUSY
		MOV		P2,SONG
		SETB	RS
		CLR		RW
		SETB	EN
		CLR		EN
		RET
