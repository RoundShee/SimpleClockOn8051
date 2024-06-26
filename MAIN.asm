;P1.0--SDA  P1.1--SCL   P1.2--S0    P1.7--RST_L     P3.2--CLKOUT
;P1.3--RST	P1.4--RS	P1.5--RW	P1.6--EN		P2--12864
;P3.3--KINT

;RAM空间使用情况:
;10H-11H	PCF8563T初始化-设置报警及定时器中断
;12H		;秒单元		都是BCD码
;13H		;分单元		此段空间可被复用
;14H		;小时单元	秒中断读取8563存放处
;15H		;日期单元	也是adjust存放处
;16H		;星期单元
;17H		;月单元
;18H		;年单元
;19H-1DH	;报警相关
;1EH		;还是指针-计数0-12
;1FH		5FH	'_'
;20H		20.0 设置模式=1  走时模式=0	key16
;			20.1 按键数据可被主程序读取
;			20.2 秒脉冲
;			20.3 03 控制数码管翻转
;21H		4秒计数
;22H-26H
;27H		放键值
;28H-2FH	日l	日h	月l	月h 年0 年1	年2	年3
;30H-33H	12864屏幕-程序参数
;34H-37H	
;38H-3FH	秒l	秒h	-	分l	分h	-	时l	时h
;40H-41H	年3	年2		ASCII
;42H-43H	年1	年0
;44H		'/'
;45H-46H	月h	月l
;47H		'/'
;48H-49H	日h	日l
;4AH		'/'
;4BH-4CH	时h	时l
;4DH		':'
;4EH-4FH	分h	分l
;50H-5FH	年年年年月月日日时时分分周50H-5CH
;60H		以上堆栈

SDA			BIT		P1.0
SCL			BIT		P1.1
WSLA_8563	EQU		0A2H	;PCF8563T地址
RSLA_8563	EQU		0A3H	;
WSLA_7290	EQU		70H		;ZLG7290B地址
RSLA_7290	EQU		71H

RST			BIT		P1.3	;ST12864程序
RS      	BIT		P1.4
RW      	BIT     P1.5
EN      	BIT     P1.6
SONG    	EQU     30H     ;要写入数据的存储单元-RAM 目前与12864不冲突
READ    	EQU     31H     ;读出数据存储单元
XUNHUAN 	EQU     32H     ;循环变量单元
COUNT   	EQU     33H     ;查表计数器
KEYVAL		EQU		27H

;主程序准备
		ORG		0000H
		LJMP	START
		ORG		0003H
		LJMP	INC_RCT		;/INT0中断入口单元
		ORG		0013H
		LJMP	INT_KEY		;扫描键盘中断
		ORG		0100H
START:	MOV		SP,#60H		;堆栈上移-避开变量区域
		;初始化	屏幕
        CLR     RST         ;屏幕芯片复位上电
        LCALL   DELAY
        SETB    RST
        LCALL   ST12864_INT ;初始化12864
		CLR		P1.7		;ZLG7290B复位
		LCALL	DELAY
		SETB	P1.7

		;串口初始化---后期删除
    	MOV	TMOD,#20H
		MOV	TL1,#0FDH		;9600
		MOV	TH1,#0FDH
		MOV	PCON,#00H
		SETB	TR1
		MOV	SCON,#40H

		;变量存储	PCF8563T	10H-1DH		RAM
		MOV		10H,#00H	;启动控制字
		MOV		11H,#1FH	;设置报警及定时器中断

		MOV		12H,#20H	;秒单元
		MOV		13H,#03H	;分单元
		MOV		14H,#10H	;小时单元
		MOV		15H,#01H	;日期单元
		MOV		16H,#01H	;星期单元
		MOV		17H,#04H	;月单元
		MOV		18H,#24H	;年单元

		MOV		19H,#00H	;设置分报警
		MOV		1AH,#00H	;设置小时报警
		MOV		1BH,#00H	;设置日期报警
		MOV		1CH,#00H	;设置星期报警
		MOV		1DH,#83H	;设定CLKOUT的频率1Hz
		;写入以上变量
		MOV		R7,#0EH		;写入参数个数
		MOV		R0,#10H		;连续变量的首地址
		MOV		R2,#00H		;从器件的内部地址
		MOV		R3,#WSLA_8563;准备向PCF8563写入数据串
		LCALL	WRNBYT		;写入时间,控制命令到8563
		SETB	EA			;允许中断
		SETB	EX0			;开启外部中断0CLK
		SETB	EX1			;按键中断开启
		SETB	PX1			;按键优先于CLK
		SETB	IT0			;触发方式-低电平触发
		SETB	IT1			;下降沿触发
		MOV		40H,#32H	;ASCII年高两位-送屏幕初始化
		MOV		41H,#30H
		MOV		44H,#2FH
		MOV		47H,#2FH
		MOV		4AH,#2FH	; '/'
		MOV		4DH,#3AH	; ':'
		MOV		1FH,#5FH	; '_'
		MOV		2EH,#0FCH
		MOV		2FH,#0DAH	;初始化年高两位
		MOV		20H,#0		;按键状态初始化
		MOV		21H,#2		;计数

MAIN_WAIT:
		CLR		01;
		JNB		P1.2,IGNORY	;按键强制拉低则锁定
		MOV		A,21H
		JNZ		FOALTING
		MOV		21H,#04H
		CPL		03
FOALTING:
		JB		02,IGNORY
		DEC		21H
IGNORY:
		JNB		00,MAIN_WAIT;最外层等待按键,中断的循环
;SETTING0:
		;此层进入设置界面-以下准备工作
		MOV     SONG,#01H   ;清除屏幕
        LCALL   SEND_ML
		MOV		SONG,#80H	;内部地址第一行
		MOV		XUNHUAN,#4	;俩汉字
		MOV		DPTR,#TAB_SE
		LCALL	ROM_WRITE
		MOV		SONG,#88H	;内部地址第三行
		MOV		XUNHUAN,#2	;汉字
		MOV		DPTR,#TAB_WEK
		LCALL	ROM_WRITE
		MOV		50H,#0FFH	;年
		MOV		51H,#0FFH
		MOV		52H,#0FFH
		MOV		53H,#0FFH	
		MOV		54H,#0FFH	;月
		MOV		55H,#0FFH
		MOV		56H,#0FFH	;日
		MOV		57H,#0FFH
		MOV		58H,#0FFH	;时
		MOV		59H,#0FFH
		MOV		5AH,#0FFH	;分
		MOV		5BH,#0FFH
		MOV		5CH,#0FFH	;周
		MOV		1EH,#00H	;指针
SETTING:		;SETTING下的循环
		;这里先写入LCD屏幕格式时间
		MOV		SONG,#90H	;第二行
		MOV		XUNHUAN,#16	;时间串
		MOV		R0,#40H		;源数据地址
		LCALL	RAM_WRITE
		MOV		SONG,#89H	;第三行
		MOV		XUNHUAN,#1	;时间串
		MOV		R0,#1FH		;源数据地址
		LCALL	RAM_WRITE
		;这里恐怕又是case才能实现_闪烁
AVOID:	;按键检测
		JNB		00,RECOVERY	;放弃设置时间
		JNB		01,AVOID	;按键标志为0继续等待
		LCALL	SET_RAMWR	;存储按键数据
		JZ		MAIN_WAIT	;直接回到主时间流动
		CLR		01
		SJMP	SETTING
RECOVERY:		;恢复到时间流动状态-SETTING的退出
		MOV     SONG,#01H   ;清除屏幕
        LCALL   SEND_ML
		LJMP	MAIN_WAIT	;回到主循环

;屏幕内容区域	ROM部分--这里测试
TAB_WEK:DB      "周天一二三四五六";测试
TAB_SE:	DB      "设置";字库
TAB_TE:	DB      "温度";如果有时间就做
TAB_AL:	DB      "闹钟";


;中断程序-每秒中断
INC_RCT:
		PUSH	PSW
		JB		00,SERE	;要是处于setting模式跳转
		MOV		R7,#07H		;读出数据个数
		MOV		R0,#12H		;目标数据块首地址
		MOV		R2,#02H		;从器件内部地址
		MOV		R3,#WSLA_8563
		MOV		R4,#RSLA_8563;准备读8563参数
		LCALL	RDNBYT		;读出数据放置到RAM的12H-18H中
		LCALL	ADJUST		;调时间调整子程序
		LCALL	CHAIFEN		;拆分-包含查表

		MOV		SONG,#80H	;上一行显示
		MOV		XUNHUAN,#16	;2024/11/11/11:11
		MOV		R0,#40H
		LCALL	RAM_WRITE
		MOV		SONG,#90H	;第二行
		MOV		XUNHUAN,#2	;汉字"周"
		MOV		DPTR,#TAB_WEK
		LCALL	ROM_WRITE
		MOV		SONG,#91H	;第二行
		MOV		XUNHUAN,#2	;汉字
		MOV		A,16H		;周提取
		MOV		DPTR,#TAB_WEK;
		INC		A
SEEK_W:	INC		DPTR
		INC		DPTR
		DEC		A
		JNZ		SEEK_W
		LCALL	ROM_WRITE	;写入周几

		;上面测试
		MOV		R7,#08H
		MOV		R2,#10H
		MOV		R3,#WSLA_7290
		JNB		03,YEARS	;使用P1.2控制显示内容  1-显示年月日
		MOV		R0,#38H		;显示小时分钟秒
		SJMP	DISP
YEARS:	MOV		R0,#28H		;显示年月日
DISP:	LCALL	WRNBYT		;调用ZLG7290B显示
		JNB		P3.2,$
		;POP		PSW
		;RETI
SERE:CPL		02			;21H最高为==秒脉冲
		POP		PSW
		RETI

;按键中断
INT_KEY:
		PUSH	ACC
		PUSH	PSW
		PUSH	00H
		PUSH	02H
		PUSH	03H
		PUSH	04H
		PUSH	07H

		MOV		R0,#KEYVAL	;源目地
		MOV		R7,#01H
		MOV		R2,#01H
		MOV		R3,#WSLA_7290
		MOV		R4,#RSLA_7290
		LCALL	RDNBYT
		;已经存放到KEYVAL中
		MOV		R0,#KEYVAL
		MOV		A,@R0
		SWAP	A
		ANL		A,#0FH
		JNZ		RETURN;更改位
		MOV		A,@R0
		CLR		C
		SUBB	A,#0BH
		JNC		FIN_K	;A大不产生借位直接退出
ISNUM:	SETB	01		;这里可判断为按键是1-9，告诉主程序可读取
		MOV		A,@R0
		CLR		C
		SUBB	A,#0AH	;0A不借位变0
		JNC		KEY0	;不借位跳
		SJMP	FIN_K	;高位是0到这里就可以退出按键中断了
KEY0:	MOV		27H,#00H
		SJMP	FIN_K
RETURN:;进一步判断情况,已知按键高位是一
		CPL		00		;反转主程序状态
FIN_K:	POP		07H
		POP		04H
		POP		03H
		POP		02H
		POP		00H
		POP		PSW
		POP		ACC
		RETI

;这里是SETTING模式下有数字按键按下,应当根据指针1EH和自己的RAM空间写入并刷入LCD
SET_RAMWR:
		MOV		A,1EH	;取指针值
		CLR		C
		SUBB	A,#13
		JC		REFRESH;14,15后不借位C=0刷新
		LJMP	SET_DONE
REFRESH:
		MOV		A,#50H	;设置区域首地址
		ADD		A,1EH	;新指针
		MOV		R0,A	;指向该存的空间
		MOV		@R0,27H	;存放键值0-9
		INC		1EH
		;下面是将50H-5CH刷入40H-4FH
		MOV		A,50H	;此块刷入到40h年
		INC		A
		JZ		TEMP0	;是0说明还没写入
		MOV		A,50H
		ADD		A,#30H
		MOV		40H,A
		SJMP	NEX0
TEMP0:	MOV		40H,#20H

NEX0:	MOV		A,51H	;此块刷入到41h年
		INC		A
		JZ		TEMP1	;是0说明还没写入
		MOV		A,51H
		ADD		A,#30H
		MOV		41H,A
		SJMP	NEX1
TEMP1:	MOV		41H,#20H

NEX1:	MOV		A,52H	;此块刷入到42h年
		INC		A
		JZ		TEMP2	;是0说明还没写入
		MOV		A,52H
		ADD		A,#30H
		MOV		42H,A
		SJMP	NEX2
TEMP2:	MOV		42H,#20H

NEX2:	MOV		A,53H	;此块刷入到43h年
		INC		A
		JZ		TEMP3	;是0说明还没写入
		MOV		A,53H
		ADD		A,#30H
		MOV		43H,A
		SJMP	NEX21
TEMP3:	MOV		43H,#20H

NEX21:	MOV		A,54H	;此块刷入到45h月
		INC		A
		JZ		TEMP4	;是0说明还没写入
		MOV		A,54H
		ADD		A,#30H
		MOV		45H,A
		SJMP	NEX3
TEMP4:	MOV		45H,#20H

NEX3:	MOV		A,55H	;此块刷入到46h月
		INC		A
		JZ		TEMP5	;是0说明还没写入
		MOV		A,55H
		ADD		A,#30H
		MOV		46H,A
		SJMP	NEX31
TEMP5:	MOV		46H,#20H

NEX31:	MOV		A,56H	;此块刷入到48h日
		INC		A
		JZ		TEMP6	;是0说明还没写入
		MOV		A,56H
		ADD		A,#30H
		MOV		48H,A
		SJMP	NEX4
TEMP6:	MOV		48H,#20H

NEX4:	MOV		A,57H	;此块刷入到49h日
		INC		A
		JZ		TEMP7	;是0说明还没写入
		MOV		A,57H
		ADD		A,#30H
		MOV		49H,A
		SJMP	NEX5
TEMP7:	MOV		49H,#20H

NEX5:	MOV		A,58H	;此块刷入到4Bh时
		INC		A
		JZ		TEMP8	;是0说明还没写入
		MOV		A,58H
		ADD		A,#30H
		MOV		4BH,A
		SJMP	NEX6
TEMP8:	MOV		4BH,#20H

NEX6:	MOV		A,59H	;此块刷入到4Ch时
		INC		A
		JZ		TEMP9	;是0说明还没写入
		MOV		A,59H
		ADD		A,#30H
		MOV		4CH,A
		SJMP	NEX7
TEMP9:	MOV		4CH,#20H

NEX7:	MOV		A,5AH	;此块刷入到4Eh分
		INC		A
		JZ		TEMP10	;是0说明还没写入
		MOV		A,5AH
		ADD		A,#30H
		MOV		4EH,A
		SJMP	NEX8
TEMP10:	MOV		4EH,#20H

NEX8:	MOV		A,5BH	;此块刷入到4Fh分
		INC		A
		JZ		TEMP11	;是0说明还没写入
		MOV		A,5BH
		ADD		A,#30H
		MOV		4FH,A
		SJMP	NEX9
TEMP11:	MOV		4FH,#20H

NEX9:	MOV		A,5CH	;此块刷入周
		INC		A
		JZ		NEX10	;是0说明还没写入
		MOV		A,5CH
		ADD		A,#30H
		MOV		1FH,A
		MOV		A,#01H	;传参-未完成
		RET
NEX10:	MOV		1FH,#5FH	;没写入就是下划线
		MOV		A,#01H	
		RET
SET_DONE:
		MOV		A,52H
		SWAP	A
		ADD		A,53H
		MOV		18H,A	;更新年
		MOV		A,54H
		SWAP	A
		ADD		A,55H
		MOV		17H,A	;更新月
		MOV		A,56H
		SWAP	A
		ADD		A,57H
		MOV		15H,A	;更新日
		MOV		A,58H
		SWAP	A
		ADD		A,59H
		MOV		14H,A	;更新时
		MOV		A,5AH
		SWAP	A
		ADD		A,5BH
		MOV		13H,A	;更新分
		MOV		12H,#00H;归零秒
		MOV		16H,5CH	;更新周
		MOV		R7,#07H
		MOV		R0,#12H
		MOV		R2,#02H
		MOV		R3,#WSLA_8563;准备向PCF8563写入数据串
		LCALL	WRNBYT		;写入时间
		CLR		00
		MOV     SONG,#01H   ;清除屏幕
        LCALL   SEND_ML
		MOV		A,#00H	;传参 完成
		RET


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

;写ROM内容到LCD
;入口参数
;SONG起始位置,XUNHUAN多少位,DPTR源始地址
ROM_WRITE:
		LCALL	SEND_ML
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
RAM_WRITE:					;魔改程序
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
		MOV		A,12H			;取秒
		LCALL	CF				;拆分,查表在R4(H),R3中
		MOV		38H,R3
		MOV		39H,R4
		MOV		A,R5
		ANL		A,#01H			;要末尾
		JZ		GIVESPACE
		MOV		4DH,#3AH		;给冒号ASII
		SJMP	GIVEMIN
GIVESPACE:
		MOV		4DH,#20H		;给空格ASCII
GIVEMIN:
		MOV		3AH,#02H		;送分隔符-

		MOV		A,13H			;取分钟 参数
		LCALL	CF
		MOV		3BH,R3
		MOV		3CH,R4
		MOV		4FH,R5
		MOV		4EH,R6			;ASCII
		MOV		3DH,#02H

		MOV		A,14H			;取小时 参数
		LCALL	CF
		MOV		3EH,R3
		MOV		3FH,R4
		MOV		4CH,R5
		MOV		4BH,R6			;ASCII

		MOV		A,15H			;取日参数
		LCALL	CF
		;MOV		A,R3		;拆分后被转码
		;ORL		A,#01H		;这里不对
		;MOV		R3,A
		MOV		28H,R3
		MOV		29H,R4
		MOV		49H,R5
		MOV		48H,R6			;ASCII

		MOV		A,17H			;取月参数
		LCALL	CF
		;MOV		A,R3
		;ORL		A,#01H
		;MOV		R3,A
		MOV		2AH,R3
		MOV		2BH,R4
		MOV		46H,R5
		MOV		45H,R6			;ASCII

		MOV		A,18H			;取年参数
		LCALL	CF
		;MOV		A,R3
		;ORL		A,#01H
		;MOV		R3,A
		MOV		2CH,R3
		MOV		2DH,R4
		MOV		43H,R5
		MOV		42H,R6			;ASCII
		;年高两位没有被查表映射,2024/4/2不可被动态修改
		;现在有了20240407
		MOV		A,40H
		CLR		C
		SUBB	A,#30H
		;MOV		2FH,A
		SWAP	A
		MOV		R3,A
		MOV		A,41H
		CLR		C
		SUBB	A,#30H
		;MOV		2EH,A
		ADD		A,R3
		LCALL	CF
		MOV		2EH,R3
		MOV		2FH,R4
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
		ADD		A,#30H
		MOV		R5,A
		CLR		C
		SUBB	A,#30H
		MOVC	A,@A+DPTR		;查表
		MOV		R3,A			;到R3
		MOV		A,R2
		SWAP	A
		ANL		A,#0FH
		ADD		A,#30H
		MOV		R6,A
		CLR		C
		SUBB	A,#30H
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
		MOV		A,12H			;处理秒单元
		ANL		A,#7FH
		MOV		12H,A
		MOV		A,13H			;处理分单元
		ANL		A,#7FH
		MOV		13H,A
		MOV		A,14H			;处理小时单元
		ANL		A,#3FH
		MOV		14H,A
		MOV		A,15H			;处理日单元
		ANL		A,#3FH
		MOV		15H,A
		MOV		A,16H			;处理星期单元
		ANL		A,#07H
		MOV		16H,A
		MOV		A,17H			;处理月单元
		ANL		A,#1FH
		MOV		17H,A
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
ACK:	LCALL	MACK
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
;串口--后期删除
CHAUNKOU:
    	PUSH	ACC
		PUSH	PSW
    	PUSH    00H
    	MOV 	R0,#12H		;这里填想看的RAM单元
    	;MOV 	R1,#7
		MOV		A,@R0
		MOV		SBUF,A
		JNB		TI,$
		CLR		TI
		;LCALL	DELAY
    	POP     00H
    	POP     PSW
    	POP     ACC
    	RET
		END