* date - show or set system date and time
*
* Itagaki Fumihiko 25-Jan-93  Create.
* 1.0
* Itagaki Fumihiko 05-Jan-95  指定形式を変更.
* 1.1
*
* Usage: date [ -u ] [ +format ]
*        date [ -u ] [[CC]YY]MMDDhhmm[.ss]

.include doscall.h
.include chrcode.h

.xref DecodeHUPAIR
.xref issjis
.xref utoa
.xref strchr
.xref strlen
.xref strforn
.xref memmovi
.xref printfi

STACKSIZE	equ	2048

FLAG_u		equ	0

.text
start:
		bra.s	start1
		dc.b	'#HUPAIR',0
start1:
		lea	stack_bottom(pc),a7		*  A7 := スタックの底
		lea	$10(a0),a0			*  A0 : PDBアドレス
		move.l	a7,d0
		sub.l	a0,d0
		move.l	d0,-(a7)
		move.l	a0,-(a7)
		DOS	_SETBLOCK
		addq.l	#8,a7
	*
	*  引数並び格納エリアを確保する
	*
		lea	1(a2),a0			*  A0 := コマンドラインの文字列の先頭アドレス
		bsr	strlen				*  D0.L := コマンドラインの文字列の長さ
		addq.l	#1,d0
		move.l	d0,-(a7)
		DOS	_MALLOC
		addq.l	#4,a7
		tst.l	d0
		bmi	insufficient_memory

		movea.l	d0,a1				*  A1 := 引数並び格納エリアの先頭アドレス
	*
	*  オプション引数を解釈する
	*
		bsr	DecodeHUPAIR			*  引数をデコードする
		move.l	d0,d7				*  D7.L : 引数カウンタ
		moveq	#0,d5				*  D5.L : フラグ
decode_opt_loop1:
		tst.l	d7
		beq	decode_opt_done

		cmpi.b	#'-',(a1)
		bne	decode_opt_done

		tst.b	1(a1)
		beq	decode_opt_done

		subq.l	#1,d7
		addq.l	#1,a1
		move.b	(a1)+,d0
		cmp.b	#'-',d0
		bne	decode_opt_loop2

		tst.b	(a1)+
		beq	decode_opt_done

		subq.l	#1,a1
decode_opt_loop2:
		moveq	#FLAG_u,d1
		cmp.b	#'u',d0
		beq	set_option

		lea	msg_illegal_option(pc),a0
		bsr	bad_option
		bra	usage

set_option:
		bset	d1,d5
		move.b	(a1)+,d0
		bne	decode_opt_loop2
		bra	decode_opt_loop1

decode_opt_done:
		bsr	get_present_time
		subq.l	#1,d7
		blo	show_date
		bne	too_many_args

		cmpi.b	#'+',(a1)+
		beq	show_date_in_specified_format

		subq.l	#1,a1
	*
	*  設定
	*
		movea.l	a1,a0
		moveq	#'.',d0
		bsr	strchr
		move.l	a0,d0
		sub.l	a1,d0
		subq.l	#8,d0
		blo	bad_date
		beq	year_ok

		subq.l	#2,d0
		blo	bad_date
		beq	year_2digit

		subq.l	#2,d0
		bne	bad_date
	*  CCYY
		bsr	get2digit
		mulu	#100,d0
		move.w	d0,d1
		bsr	get2digit
		add.w	d1,d0
		sub.w	#1900,d0
		blo	bad_year

		cmp.w	#80,d0
		blo	bad_year

		cmp.w	#180,d0
		blo	set_year
bad_year:
		lea	msg_bad_year(pc),a0
		bsr	werror_myname_and_msg
		bra	exit_1

year_2digit:
	*  YY
		bsr	get2digit
		cmp.b	#80,d0
		bhs	set_year

		add.b	#100,d0
set_year:
		move.b	d0,year
year_ok:
	*  MM
		bsr	get2digit
		beq	bad_date

		cmp.b	#12,d0
		bhi	bad_date

		move.b	d0,month
	*  DD
		bsr	get2digit
		beq	bad_date

		move.b	d0,day_of_month
	*  hh
		bsr	get2digit
		cmp.b	#23,d0
		bhi	bad_date

		move.b	d0,hour
	*  mm
		bsr	get2digit
		cmp.b	#59,d0
		bhi	bad_date

		move.b	d0,minute
	*  .ss
		clr.b	second
		move.b	(a1)+,d0
		beq	datimearg_ok

		cmp.b	#'.',d0
		bne	bad_date

		bsr	get2digit
		cmp.b	#59,d0
		bhi	bad_date

		move.b	d0,second
		tst.b	(a1)+
		bne	bad_date
datimearg_ok:
		bsr	set_days_table_p
		moveq	#0,d0
		move.b	month,d0
		move.b	(a0,d0.l),d0
		cmp.b	day_of_month,d0
		blo	bad_date

		btst	#FLAG_u,d5
		beq	set_datime

		add.b	#9,hour
		cmp.b	#24,hour
		blo	set_datime

		sub.b	#24,hour
		addq.b	#1,day_of_month
		cmp.b	day_of_month,d0
		bhs	set_datime

		move.b	#1,day_of_month
		addq.b	#1,month
		cmpi.b	#12,month
		bls	set_datime

		move.b	#1,month
		addq.b	#1,year
set_datime:
		move.b	year,d0
		sub.b	#80,d0
		blo	bad_year

		cmpi.b	#100,d0
		bhs	bad_year

		lsl.w	#4,d0
		or.b	month,d0
		lsl.w	#5,d0
		or.b	day_of_month,d0
		move.w	d0,-(a7)
		DOS	_SETDATE
		addq.l	#2,a7
		tst.l	d0
		bmi	bad_date

		moveq	#0,d0
		move.b	hour,d0
		swap	d0
		or.b	minute,d0
		lsl.w	#8,d0
		or.b	second,d0
		move.l	d0,-(a7)
		DOS	_SETTIM2
		addq.l	#4,a7

		bsr	get_present_time
	*
	*  表示
	*
show_date:
		bsr	format_c
		bra	print_done

show_date_in_specified_format:
*	記号	種別	意味
*	%	文字 '%'
*	n	改行
*	t	水平タブ
*	Y	年(1980..2079)
*	y	年の下2桁(00..99)
*	m	月(01..12)
*	B	月の英語名(January..December)
*	b	月の英語名の頭3文字(Jan..Dec)
*	h	"%b"
*	U	日曜日を週の始まりとした，年の中での週(00..53)
*	W	月曜日を週の始まりとした，年の中での週(00..53)
*	j	年の中での日(001..366)
*	d	月の中での日(01..31)
*	e	月の中での日( 1..31)
*	w	週の中での日(0..6)．0 は日曜日
*	A	曜日の英語名(Sunday..Saturday)
*	a	曜日の英語名の頭3文字(Sun..Sat)
*	p	'AM' か 'PM'
*	H	24時制での時(00..23)
*	K	24時制での時( 0..23)
*	I	12時制での時(01..12)
*	L	12時制での時( 1..12)
*	M	分(00..59)
*	S	秒(00..59)
*	D	"%m/%d/%y"
*	T	"%H:%M:%S"
*	R	"%H:%M"
*	r	"%I:%M:%S %p"
*	c	"%a %b %d %T JST %Y"
		movea.l	a1,a3
		sf	d7
print_start:
		movea.l	a3,a4
print_loop:
		move.b	(a4)+,d0
		beq	scan_done

		cmp.b	#'%',d0
		bne	print_normal_char		*  '%'はシフトJISには現れないから，シフトJISを考慮する必要はない

		tst.b	(a4)
		beq	print_normal_char

		move.b	(a4)+,d0
		lea	format_table(pc),a0
search_format:
		tst.b	(a0)+
		beq	undefined_format

		cmp.b	(a0)+,d0
		beq	format_found

		addq.l	#2,a0
		bra	search_format

format_found:
		tst.b	d7
		beq	print_loop

		move.w	(a0)+,d0
		lea	format_top(pc),a0
		jsr	(a0,d0.w)
		bra	print_loop

print_normal_char:
		tst.b	d7
		beq	print_loop

		bsr	putc
		bra	print_loop

undefined_format:
		movea.l	a4,a1
		lea	msg_bad_format(pc),a0
		bsr	bad_option
		lea	str_newline(pc),a0
		bsr	werror
		bra	exit_1

scan_done:
		not.b	d7
		bne	print_start
print_done:
		bsr	put_newline
exit_0:
		clr.w	-(a7)
		DOS	_EXIT2
****************
format_top:
****************
format_percent:
		moveq	#'%',d0
		bra	putc
****************
format_n:
put_newline:
		lea	str_newline(pc),a0
puts:
		move.l	a0,-(a7)
		DOS	_PRINT
		addq.l	#4,a7
		rts
****************
format_t:
		moveq	#HT,d0
		bra	putc
****************
format_A:
		moveq	#0,d1
		bra	print_week_word

format_a:
		moveq	#3,d1
print_week_word:
		move.b	day_of_week,d0
		lea	week_words(pc),a0
		bra	print_name_in_table
****************
format_w:
		moveq	#0,d0
		move.b	day_of_week,d0
		moveq	#1,d3
		moveq	#1,d4
		bra	print_digit
****************
format_B:
		moveq	#0,d1
		bra	print_month_word

format_b:
format_h:
		moveq	#3,d1
print_month_word:
		move.b	month,d0
		lea	month_words(pc),a0
print_name_in_table:
		and.l	#$ff,d0
		bsr	strforn
		move.l	d1,d0
		beq	puts

		movea.l	a0,a1
		lea	buffer(pc),a0
		bsr	memmovi
		clr.b	(a0)
		lea	buffer(pc),a0
		bra	puts
****************
format_c:
		bsr	format_a
		bsr	put_space
		bsr	format_b
		bsr	put_space
		bsr	format_d
		bsr	put_space
		bsr	format_T
		lea	str_JST(pc),a0
		btst	#FLAG_u,d5
		beq	format_c_1

		lea	str_GMT(pc),a0
format_c_1:
		bsr	puts
format_Y:
		moveq	#4,d3
		bra	print_year

format_D:
		bsr	format_m
		bsr	put_slash
		bsr	format_d
		bsr	put_slash
format_y:
		moveq	#0,d3
print_year:
		moveq	#1,d4
		moveq	#0,d0
		move.b	year,d0
		add.w	#1900,d0
		tst.l	d3
		bne	print_digit

		divu	#100,d0
		clr.w	d0
		swap	d0
print_digit:
		lea	utoa(pc),a0
		lea	putc(pc),a1
		suba.l	a2,a2
		moveq	#0,d1
		moveq	#' ',d2
		bra	printfi
****************
format_m:
		move.b	month,d0
print_digit_02:
		moveq	#2,d4
print_digit_2:
		moveq	#2,d3
		and.l	#$ff,d0
		bra	print_digit
****************
format_d:
		move.b	day_of_month,d0
		bra	print_digit_02
****************
format_e:
		move.b	day_of_month,d0
		moveq	#1,d4
		bra	print_digit_2
****************
format_r:
		bsr	format_I
		bsr	put_colon
		bsr	format_M
		bsr	put_colon
		bsr	format_S
		bsr	put_space
format_p:
		lea	str_PM(pc),a0
		cmpi.b	#12,hour
		bhs	format_p_1

		lea	str_AM(pc),a0
format_p_1:
		bra	puts
****************
format_H:
		move.b	hour,d0
		bra	print_digit_02
****************
format_k:
		move.b	hour,d0
		moveq	#1,d4
		bra	print_digit_2
****************
format_l:
		moveq	#1,d4
		bra	format_I_0

format_I:
		moveq	#2,d4
format_I_0:
		move.b	hour,d0
		bne	format_I_1

		moveq	#12,d0
format_I_1:
		cmp.b	#12,d0
		bls	format_I_2

		sub.b	#12,d0
format_I_2:
		bra	print_digit_2
****************
format_R:
		bsr	format_H
		bsr	put_colon
format_M:
		move.b	minute,d0
		bra	print_digit_02
****************
format_T:
		bsr	format_R
		bsr	put_colon
format_S:
		move.b	second,d0
		bra	print_digit_02
****************
format_j:
		bsr	get_day_of_year
		moveq	#3,d3
		moveq	#3,d4
		bra	print_digit

get_day_of_year:
		movem.l	d1-d2/a0,-(a7)
		moveq	#0,d2
		moveq	#0,d1
		move.b	month,d1
		subq.w	#1,d1
		movea.l	days_table_p,a0
		moveq	#0,d0
calc_day_of_year_loop:
		move.b	(a0)+,d0
		add.w	d0,d2
		dbra	d1,calc_day_of_year_loop

		moveq	#0,d0
		move.b	day_of_month,d0
		add.l	d2,d0
		movem.l	(a7)+,d1-d2/a0
		rts
****************
format_W:
		moveq	#1,d2
		bra	week_of_year

format_U:
		moveq	#0,d2
week_of_year:
		moveq	#0,d0
		move.b	year,d0
		sub.w	#76,d0
		divu	#28,d0
		swap	d0
		lea	week_year_table(pc),a0
		moveq	#0,d1
		move.b	(a0,d0.w),d1			*  D1.L : この年の最初の曜日（日曜日=0）
		cmp.w	d2,d1
		bhi	week_of_year_1

		addq.l	#7,d1
week_of_year_1:
		bsr	get_day_of_year
		add.l	d1,d0
		subq.l	#1,d0
		sub.l	d2,d0
		divu	#7,d0
		swap	d0
		clr.w	d0
		swap	d0
		bra	print_digit_02
****************
put_slash:
		moveq	#'/',d0
		bra	putc

put_colon:
		moveq	#':',d0
		bra	putc

put_space:
		moveq	#' ',d0
putc:
		move.l	d0,-(a7)
		move.w	d0,-(a7)
		DOS	_PUTCHAR
		addq.l	#2,a7
		move.l	(a7)+,d0
		rts
********************************
bad_option:
		moveq	#1,d1
		tst.b	(a1)
		beq	bad_option_1

		bsr	issjis
		bne	bad_option_1

		moveq	#2,d1
bad_option_1:
		move.l	d1,-(a7)
		pea	-1(a1)
		move.w	#2,-(a7)
		bsr	werror_myname_and_msg
		DOS	_WRITE
		lea	10(a7),a7
		rts

bad_date:
		lea	msg_bad_date(pc),a0
		bra	bad_arg_1

too_many_args:
		lea	msg_too_many_args(pc),a0
bad_arg_1:
		bsr	werror_myname_and_msg
usage:
		lea	msg_usage(pc),a0
		bsr	werror
exit_1:
		move.w	#1,-(a7)
		DOS	_EXIT2

insufficient_memory:
		lea	msg_no_memory(pc),a0
		bsr	werror_myname_and_msg
		move.w	#3,-(a7)
		DOS	_EXIT2
*****************************************************************
get2digit:
		move.w	d1,-(a7)
		moveq	#0,d0
		move.b	(a1)+,d0
		sub.b	#'0',d0
		blo	bad_date

		cmp.b	#9,d0
		bhi	bad_date

		mulu	#10,d0
		move.b	(a1)+,d1
		sub.b	#'0',d1
		blo	bad_date

		cmp.b	#9,d1
		bhi	bad_date

		add.b	d1,d0
		move.w	(a7)+,d1
		tst.l	d0
		rts
*****************************************************************
get_present_time:
		movem.l	d0-d2/a0,-(a7)
		DOS	_GETDATE
get_present_time_loop:
		move.l	d0,d2			*  D2.L : dow:3,year:7,month:4,dom:5
		DOS	_GETTIM2
		move.l	d0,d1			*  D1.L : hour:5,pad:2,minute:6,pad:2,second:6
		DOS	_GETDATE
		cmp.l	d2,d0
		bne	get_present_time_loop

		lea	datime_top(pc),a0
		and.b	#%11111,d0
		move.b	d0,(a0)+
		lsr.l	#5,d2
		move.b	d2,d0
		and.b	#%1111,d0
		move.b	d0,(a0)+
		lsr.w	#4,d2
		move.b	d2,d0
		and.b	#%1111111,d0
		add.b	#80,d0
		move.b	d0,(a0)+
		lsr.w	#7,d2
		and.b	#%111,d2
		move.b	d2,(a0)+

		move.b	d1,d0
		and.b	#%111111,d0
		move.b	d0,(a0)+
		lsr.l	#8,d1
		move.b	d1,d0
		and.b	#%111111,d0
		move.b	d0,(a0)+
		lsr.w	#8,d1
		and.b	#%11111,d1
		move.b	d1,(a0)

		bsr	set_days_table_p

		btst	#FLAG_u,d5
		beq	process_datime_done

		sub.b	#9,hour
		bcc	process_datime_done

		add.b	#24,hour
		subq.b	#1,day_of_week
		bpl	process_datime_day_of_week_ok

		addq.b	#7,day_of_week
process_datime_day_of_week_ok:
		subq.b	#1,day_of_month
		bne	process_datime_done

		subq.b	#1,month
		bne	process_datime_set_day_of_month

		move.b	#12,month
		subq.b	#1,year
		bsr	set_days_table_p
process_datime_set_day_of_month:
		moveq	#0,d0
		move.b	month,d0
		move.b	(a0,d0.l),day_of_month
process_datime_done:
		movem.l	(a7)+,d0-d2/a0
		rts
*****************************************************************
set_days_table_p:
		lea	days_table_in_civil(pc),a0
.if 0
		moveq	#0,d0
		move.b	year,d0
		add.w	#1900,d0
* 正しくはこうだが
.else
		move.b	year,d0
* これでも結果は同じ
.endif
		and.b	#3,d0
		bne	leap_ok				*  年が4の倍数でない -- 閏年ではない

		*  年が4の倍数であるから，閏年である．

		*  100の倍数であって400の倍数でない年は閏年ではないのだが，
		*  X68000のカレンダ・クロックから得られる年の範囲は1980..2079であり，
		*  この中には100の倍数であって400の倍数でない年は無い．
		lea	days_table_in_leap(pc),a0
leap_ok:
		move.l	a0,days_table_p
		rts
*****************************************************************
werror_myname_and_msg:
		move.l	a0,-(a7)
		lea	msg_myname(pc),a0
		bsr	werror
		movea.l	(a7)+,a0
werror:
		movem.l	d0/a1,-(a7)
		movea.l	a0,a1
werror_1:
		tst.b	(a1)+
		bne	werror_1

		subq.l	#1,a1
		suba.l	a0,a1
		move.l	a1,-(a7)
		move.l	a0,-(a7)
		move.w	#2,-(a7)
		DOS	_WRITE
		lea	10(a7),a7
		movem.l	(a7)+,d0/a1
		rts
*****************************************************************
.data

	dc.b	0
	dc.b	'## date 1.1 ##  Copyright(C)1993-95 by Itagaki Fumihiko',0

msg_myname:		dc.b	'date'
msg_colon:		dc.b	': ',0
msg_no_memory:		dc.b	'メモリが足りません',CR,LF,0
msg_illegal_option:	dc.b	'不正なオプション -- ',0
msg_bad_format:		dc.b	'不正な変換文字 -- %',0
msg_bad_date:		dc.b	'日付と時刻の指定が正しくありません',0
msg_bad_year:		dc.b	'年が範囲外です',CR,LF,0
msg_too_many_args:	dc.b	'引数が多過ぎます',0
msg_usage:		dc.b	CR,LF
			dc.b	'使用法:  表示:  date [-u] [+format]',CR,LF
			dc.b	'         設定:  date [-u] [[CC]YY]MMDDhhmm[.ss]'
str_newline:		dc.b	CR,LF,0

str_AM:		dc.b	'AM',0
str_PM:		dc.b	'PM',0

str_JST:	dc.b	' JST ',0
str_GMT:	dc.b	' GMT ',0

week_words:
		dc.b	'Sunday',0
		dc.b	'Monday',0
		dc.b	'Tuesday',0
		dc.b	'Wednesday',0
		dc.b	'Thursday',0
		dc.b	'Friday',0
		dc.b	'Saturday',0
month_words:
		dc.b	0
		dc.b	'January',0
		dc.b	'February',0
		dc.b	'March',0
		dc.b	'April',0
		dc.b	'May',0
		dc.b	'June',0
		dc.b	'July',0
		dc.b	'August',0
		dc.b	'September',0
		dc.b	'October',0
		dc.b	'November',0
		dc.b	'December',0
		dc.b	0
		dc.b	0
days_table_in_civil:
		dc.b	0,31,28,31,30,31,30,31,31,30,31,30,31,0,0,0

days_table_in_leap:
		dc.b	0,31,29,31,30,31,30,31,31,30,31,30,31,0,0,0

* ((年-1976)%28)の最初の曜日（日曜日=0）
* 年は1976から2079の範囲．この範囲では4の倍数の年は必ず閏年であるから，
* 単純に28年周期で計算できる．
week_year_table:
		dc.b	4,6,0,1
		dc.b	2,4,5,6
		dc.b	0,2,3,4
		dc.b	5,0,1,2
		dc.b	3,5,6,0
		dc.b	1,3,4,5
		dc.b	6,1,2,3

.even
format_table:
		dc.b	1,'%'
		dc.w	format_percent-format_top

		dc.b	1,'n'
		dc.w	format_n-format_top

		dc.b	1,'t'
		dc.w	format_t-format_top

		dc.b	1,'Y'
		dc.w	format_Y-format_top

		dc.b	1,'y'
		dc.w	format_y-format_top

		dc.b	1,'m'
		dc.w	format_m-format_top

		dc.b	1,'B'
		dc.w	format_B-format_top

		dc.b	1,'b'
		dc.w	format_b-format_top

		dc.b	1,'h'
		dc.w	format_h-format_top

		dc.b	1,'U'
		dc.w	format_U-format_top

		dc.b	1,'W'
		dc.w	format_W-format_top

		dc.b	1,'j'
		dc.w	format_j-format_top

		dc.b	1,'d'
		dc.w	format_d-format_top

		dc.b	1,'e'
		dc.w	format_e-format_top

		dc.b	1,'D'
		dc.w	format_D-format_top

		dc.b	1,'A'
		dc.w	format_A-format_top

		dc.b	1,'a'
		dc.w	format_a-format_top

		dc.b	1,'w'
		dc.w	format_w-format_top

		dc.b	1,'p'
		dc.w	format_p-format_top

		dc.b	1,'H'
		dc.w	format_H-format_top

		dc.b	1,'k'
		dc.w	format_k-format_top

		dc.b	1,'I'
		dc.w	format_I-format_top

		dc.b	1,'l'
		dc.w	format_l-format_top

		dc.b	1,'M'
		dc.w	format_M-format_top

		dc.b	1,'S'
		dc.w	format_S-format_top

		dc.b	1,'T'
		dc.w	format_T-format_top

		dc.b	1,'R'
		dc.w	format_R-format_top

		dc.b	1,'r'
		dc.w	format_r-format_top

		dc.b	1,'c'
		dc.w	format_c-format_top

		dc.b	0
*****************************************************************
.bss
.even
days_table_p:	ds.l	1

* 順序を変えないこと
datime_top:
day_of_month:	ds.b	1
month:		ds.b	1
year:		ds.b	1
day_of_week:	ds.b	1
second:		ds.b	1
minute:		ds.b	1
hour:		ds.b	1

buffer:		ds.b	4
.even
		ds.b	STACKSIZE
.even
stack_bottom:
*****************************************************************

.end start
