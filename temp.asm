;测试数据20H，由串口以9600发送

    ;开始发送20H-26H数据


SDA			BIT		P1.0
SCL			BIT		P1.1
WSLA_8563	EQU		0A2H		;PCF8563T地址
RSLA_8563	EQU		0A3H		;
WSLA_7290	EQU		70H			;ZLG7290B地址
RSLA_7290	EQU		71H

RST			BIT		P1.3		;ST12864程序
RS      	BIT		P1.4
RW      	BIT     P1.5
EN      	BIT     P1.6
SONG    	EQU     30H         ;要写入数据的存储单元-RAM 目前与12864不冲突
READ    	EQU     31H         ;读出数据存储单元
XUNHUAN 	EQU     32H         ;循环变量单元
COUNT   	EQU     33H         ;查表计数器
KEYVAL		EQU		27H

;主程序准备
		ORG		0000H
		LJMP	START
		ORG		0003H
		LJMP	INC_RCT			;/INT0中断入口单元
		ORG		0013H
		LJMP	INT_7290		;扫描键盘中断
		ORG		0100H
START:	MOV		SP,#60H			;堆栈上移-避开变量区域
		;初始化	屏幕
        CLR     RST         ;屏幕芯片复位上电
        LCALL   DELAY
        SETB    RST
        LCALL   ST12864_INT ;初始化12864
        LCALL   HANZI_WRITE ;预先写入屏幕一些数据字符
		CLR		P1.7			;ZLG7290B复位
		LCALL	DELAY
		SETB	P1.7
            ;串口初始化
    MOV	TMOD,#20H
	MOV	TL1,#0FDH		;9600
	MOV	TH1,#0FDH
	MOV	PCON,#00H
	SETB	TR1
	MOV	SCON,#40H
		;变量存储	PCF8563T	10H-1DH		RAM
		MOV		10H,#00H		;启动控制字
		MOV		11H,#1FH		;设置报警及定时器中断

		MOV		12H,#20H		;秒单元
		MOV		13H,#03H		;分单元
		MOV		14H,#10H		;小时单元
		MOV		15H,#01H		;日期单元
		MOV		16H,#01H		;星期单元
		MOV		17H,#04H		;月单元
		MOV		18H,#24H		;年单元

		MOV		19H,#00H		;设置分报警
		MOV		1AH,#00H		;设置小时报警
		MOV		1BH,#00H		;设置日期报警
		MOV		1CH,#00H		;设置星期报警
		MOV		1DH,#83H		;设定CLKOUT的频率1Hz
		;写入以上变量
		MOV		R7,#0EH			;写入参数个数
		MOV		R0,#10H			;连续变量的首地址
		MOV		R2,#00H			;从器件的内部地址
		MOV		R3,#WSLA_8563	;准备向PCF8563写入数据串
		LCALL	WRNBYT			;写入时间,控制命令到8563
		SETB	EA				;允许中断
		SETB	EX0				;开启外部中断0CLK
		SETB	EX1				;按键中断开启
		SETB	PX1				;按键优先于CLK
		SETB	IT0				;触发方式-低电平触发
		CLR		IT1				;下降沿触发
		MOV		40H,#32H		;ASCII年高两位-送屏幕初始化
		MOV		41H,#30H
		MOV		2EH,#0FCH
		MOV		2FH,#0DAH		;初始化年高两位
		SJMP	$				;等待中断

;屏幕内容区域	ROM部分
TABLE1:	DB      "2024/03/31/21:27";第一行 16
TABLE2:	DB      "星期            ";第三行
TABLE3:	DB      "                ";第二行
TABLE4:	DB      "                ";第四行


;中断程序-每秒中断
INC_RCT:
		MOV		R7,#07H			;读出数据个数
		MOV		R0,#20H			;目标数据块首地址
		MOV		R2,#02H			;从器件内部地址
		MOV		R3,#WSLA_8563
		MOV		R4,#RSLA_8563	;准备读8563参数
		LCALL	RDNBYT			;读出数据放置到RAM的20H-26H中
		LCALL	ADJUST			;调时间调整子程序
		LCALL	CHAIFEN			;拆分-包含查表

		MOV		SONG,#80H		;上一行显示
		MOV		XUNHUAN,#16		;2024/11/11/11:11
		MOV		R0,#40H
		LCALL	TIME_WRITE
		;上面测试
		MOV		R7,#08H
		MOV		R2,#10H
		MOV		R3,#WSLA_7290
		JNB		P1.2,YEARS		;使用P1.2控制显示内容  1-显示年月日
		MOV		R0,#38H			;显示小时分钟秒
		SJMP	DISP
YEARS:	MOV		R0,#28H			;显示年月日
DISP:	LCALL	WRNBYT			;调用ZLG7290B显示
		JNB		P3.2,$
		RETI

;按键中断
INT_7290:
		PUSH	ACC
		PUSH	PSW
		PUSH	00H
		PUSH	02H
		PUSH	03H
		PUSH	04H
		PUSH	07H

		MOV		R0,#KEYVAL		;源目地
		MOV		R7,01H
		MOV		R2,01H
		MOV		R3,#WSLA_7290
		MOV		R4,#RSLA_7290
		LCALL	RDNBYT
		;已经存放到KEYVAL中
		POP		07H
		POP		04H
		POP		03H
		POP		02H
		POP		00H
		POP		PSW
		POP		ACC
		RETI

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
		MOV		XUNHUAN,#64	;全部显示
		MOV		DPTR,#TABLE1
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


;写时间至LCD子程序
;入口参数
;SONG起始位置,XUNHUAN多少位,R0源始地址
TIME_WRITE:					;魔改程序
		LCALL	SEND_ML
TIMWRT_LOOP:
		MOV		A,@R0
		MOV		SONG,A
		LCALL	SEND_SJ
		INC		R0
		DJNZ	XUNHUAN,TIMWRT_LOOP
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
;-------------------------------------
;下面是关于ST12864的内容 		

;拆分子程序-将RAM空间20H-26H查表拆分送入28H-2FH,38H-3FH
CHAIFEN:						;增加ASCII存储
		PUSH	PSW				;R5 ASCII低	R6高
		PUSH	ACC
		PUSH	03H				;R3
		PUSH	04H
		PUSH	05H
		PUSH	06H
		MOV		A,20H			;取秒
		LCALL	CF				;拆分,查表在R4(H),R3中
		MOV		38H,R3
		MOV		39H,R4
		;MOV		4DH,R5
		;MOV		4CH,R6			;ASCII
		;这里缺代码	将秒转换为4DH的' ' 或者':'
		MOV		3AH,#02H		;送分隔符-

		MOV		A,21H			;取分钟 参数
		LCALL	CF
		MOV		3BH,R3
		MOV		3CH,R4
		MOV		4FH,R5
		MOV		4EH,R6			;ASCII
		MOV		3DH,#02H

		MOV		A,22H			;取小时 参数
		LCALL	CF
		MOV		3EH,R3
		MOV		3FH,R4
		MOV		4CH,R5
		MOV		4BH,R6			;ASCII

		MOV		A,23H			;取日参数
		LCALL	CF
		;MOV		A,R3		;拆分后被转码
		;ORL		A,#01H		;这里不对
		;MOV		R3,A
		MOV		28H,R3
		MOV		29H,R4
		MOV		49H,R5
		MOV		48H,R6			;ASCII

		MOV		A,25H			;取月参数
		LCALL	CF
		;MOV		A,R3
		;ORL		A,#01H
		;MOV		R3,A
		MOV		2AH,R3
		MOV		2BH,R4
		MOV		46H,R5
		MOV		45H,R6			;ASCII

		MOV		A,26H			;取年参数
		LCALL	CF
		;MOV		A,R3
		;ORL		A,#01H
		;MOV		R3,A
		MOV		2CH,R3
		MOV		2DH,R4
		MOV		43H,R5
		MOV		42H,R6			;ASCII
		;MOV		2EH,#0FCH		;0
		;MOV		2FH,#0DAH		;2后期得改
		POP		06H
		POP		05H
		POP		04H
		POP		03H
		POP		ACC
		POP		PSW
		RET

;将A中的数据拆分成两个独立的BCD码并查表-结果存放在R3,R4中
CF:		PUSH	02H
		PUSH	DPH
		PUSH	DPL
		MOV		DPTR,#LEDSEG
		MOV		R2,A			;备份A
		ANL		A,#0FH			;取低位
		ADD		A,'0'
		MOV		R5,A
		CLR		C
		SUBB	A,'0'
		MOVC	A,@A+DPTR		;查表
		MOV		R3,A			;到R3
		MOV		A,R2
		SWAP	A
		ANL		A,#0FH
		ADD		A,'0'
		MOV		R6,A
		CLR		C
		SUBB	A,'0'
		MOVC	A,@A+DPTR
		MOV		R4,A			;到R4
		POP		DPL
		POP		DPH
		POP		02H
		RET
LEDSEG:	DB	0FCH,60H,0DAH,0F2H,66H,0B6H,0BEH,0E4H
		DB	0FEH,0F6H,0EEH,3EH,9CH,7AH,9EH,8EH

ADJUST:
		PUSH	ACC
		MOV		A,20H			;处理秒单元
		ANL		A,#7FH
		MOV		20H,A
		MOV		A,21H			;处理分单元
		ANL		A,#7FH
		MOV		21H,A
		MOV		A,22H			;处理小时单元
		ANL		A,#3FH
		MOV		22H,A
		MOV		A,23H			;处理日单元
		ANL		A,#3FH
		MOV		23H,A
		MOV		A,24H			;处理星期单元
		ANL		A,#07H
		MOV		24H,A
		MOV		A,25H			;处理月单元
		ANL		A,#1FH
		MOV		25H,A
		POP		ACC
		RET

;延迟子程序
DELAY:	PUSH	00H
		PUSH	01H
		MOV		R0,#00H
DELAY1:	MOV		R1,#00H
		DJNZ	R1,$
		DJNZ	R0,DELAY1
		POP		01H
		POP		00H
		RET

;通用I^2C总线通信子程序
;多字节写操作子程序
;入口参数
;R7字节数
;R0源数据块首地址
;R2从器件内部子地址
;R3外围地址
;相关子程序WRBYT,STOP,CACK,STA
;个人表述：R3.W(R2)<---R7---R0
WRNBYT:	PUSH	PSW
		PUSH	ACC
WRADD:	MOV		A,R3			;取外围地址
		LCALL	STA				;发送起始信号s
		LCALL	WRBYT			;发送外围地址
		LCALL	CACK			;检测外围应答
		JB		F0,WRADD		;应答不正确返回
		MOV		A,R2
		LCALL	WRBYT			;发送内部首地址
		LCALL	CACK
		JB		F0,WRADD
WRDA:	MOV		A,@R0
		LCALL	WRBYT			;发送外围地址
		LCALL	CACK
		JB		F0,WRADD
		INC		R0
		DJNZ	R7,WRDA
		LCALL	STOP
		POP		ACC
		POP		PSW
		RET

;多字节读程序
;入口参数
;R7字节数
;R0目标数据块首地址
;R2从器件内部首地址
;R3器件地址-写,R4器件地址-读
;个人表述：R3.W<-----
;			R4.R(R2)---R7--->R0
RDNBYT:	PUSH	PSW
		PUSH	ACC
RDADD1:	LCALL	STA
		MOV		A,R3
		LCALL	WRBYT
		LCALL	CACK
		JB		F0,RDADD1
		MOV		A,R2
		LCALL	WRBYT
		LCALL	CACK
		JB		F0,RDADD1
		LCALL	STA
		MOV		A,R4
		LCALL	WRBYT
		LCALL	CACK
		JB		F0,RDADD1
RDN:	LCALL	RDBYT
		MOV		@R0,A
		DJNZ	R7,ACK
		LCALL	MNACK
		LCALL	STOP
		POP		ACC
		POP		PSW
		RET
ACK:	LCALL	MNACK
		INC		R0
		SJMP	RDN

;最底层iic
;发送启动信号s
STA:
		SETB	SDA
		SETB	SCL
		NOP
		NOP
		NOP
		NOP
		NOP
		CLR		SDA			;产生启动信号
		NOP
		NOP
		NOP
		NOP
		NOP
		CLR		SCL
		RET


;发送停止信号P
STOP:
		CLR		SDA
		SETB	SCL
		NOP
		NOP
		NOP
		NOP
		NOP
		SETB	SDA
		NOP
		NOP
		NOP
		NOP
		NOP
		SETB	SCL
		SETB	SDA
		RET

;发送应答信号
MACK:
		CLR		SDA
		SETB	SCL
		NOP
		NOP
		NOP
		NOP
		NOP
		CLR		SCL
		SETB	SDA
		RET

;发送非应答信号
MNACK:
		SETB	SDA
		SETB	SCL
		NOP
		NOP
		NOP
		NOP
		NOP
		CLR		SCL
		CLR		SDA
		RET

;应答检测信号
CACK:
		SETB	SDA
		SETB	SCL
		CLR		F0
		MOV		C,SDA
		JNC		CEND
		SETB	F0
CEND:	CLR		SCL
		RET

;发送一个字节
WRBYT:	PUSH	06H
		MOV		R6,#08H
WLP:	RLC		A
		MOV		SDA,C
		SETB	SCL
		NOP
		NOP
		NOP
		NOP
		NOP
		JNB		SCL,$
		CLR		SCL
		DJNZ	R6,WLP
		POP		06H
		RET

;接收一个字节
RDBYT:	PUSH	06H
		MOV		R6,#08H
RLP:	SETB	SDA
		SETB	SCL
		JNB		SCL,$
		MOV		C,SDA
		MOV		A,R2
		RLC		A
		MOV		R2,A
		CLR		SCL
		DJNZ	R6,RLP
		POP		06H
		RET
CHAUNKOU:
    PUSH	ACC
	PUSH	PSW  
    PUSH    00H      
    MOV R0,#20H
    ;MOV R1,#7
	MOV	A,@R0
	MOV	SBUF,A
	JNB	TI,$
	CLR	TI
	;LCALL	DELAY
    POP     00H
    POP     PSW
    POP     ACC
    RET
		END