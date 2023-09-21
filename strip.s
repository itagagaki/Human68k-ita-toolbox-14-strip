* strip - strip symbol information from .X type executable file of Human68k
*
* Itagaki Fumihiko 14-Aug-92  Create.
*
* Usage: strip [ -p ] [ - ] <ファイル> ...

.include doscall.h
.include error.h
.include limits.h
.include stat.h
.include chrcode.h

.xref DecodeHUPAIR
.xref strlen
.xref strfor1
.xref tfopen
.xref fclose

STACKSIZE	equ	256

FLAG_p		equ	0


.text
start:
		bra.s	start1
		dc.b	'#HUPAIR',0
start1:
		lea	stack_bottom(pc),a7		*  A7 := スタックの底
		DOS	_GETPDB
		movea.l	d0,a0				*  A0 : PDBアドレス
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
		bsr	malloc
		bmi	insufficient_memory

		movea.l	d0,a1				*  A1 := 引数並び格納エリアの先頭アドレス
	*
	*  引数をデコードし，解釈する
	*
		bsr	DecodeHUPAIR			*  引数をデコードする
		movea.l	a1,a0				*  A0 : 引数ポインタ
		move.l	d0,d7				*  D7.L : 引数カウンタ
		moveq	#0,d5				*  D5.L : bit0:-p
decode_opt_loop1:
		tst.l	d7
		beq	decode_opt_done

		cmpi.b	#'-',(a0)
		bne	decode_opt_done

		subq.l	#1,d7
		addq.l	#1,a0
		move.b	(a0)+,d0
		beq	decode_opt_done
decode_opt_loop2:
		moveq	#FLAG_p,d1
		cmp.b	#'p',d0
		beq	set_option

		lea	msg_illegal_option(pc),a0
		bsr	werror_myname_and_msg
		move.w	d0,-(a7)
		move.l	#1,-(a7)
		pea	5(a7)
		move.w	#2,-(a7)
		DOS	_WRITE
		lea	12(a7),a7
		bra	usage

set_option:
		bset	d1,d5
set_option_done:
		move.b	(a0)+,d0
		bne	decode_opt_loop2
		bra	decode_opt_loop1

decode_opt_done:
		tst.l	d7
		beq	too_few_args
	*
	*  処理開始
	*
		moveq	#0,d6				*  D6.W : エラー・コード
strip_arg_loop:
		bsr	strip
		bsr	strfor1
		subq.l	#1,d7
		bne	strip_arg_loop
****************
exit_program:
		move.w	d6,-(a7)
		DOS	_EXIT2

strip_error_exit:
		bsr	werror_myname_word_colon_msg
		bra	exit_program

too_few_args:
		lea	msg_too_few_args(pc),a0
		bsr	werror_myname_and_msg
usage:
		lea	msg_usage(pc),a0
		bsr	werror
		moveq	#1,d6
		bra	exit_program

insufficient_memory:
		lea	msg_no_memory(pc),a0
		bsr	werror_myname_and_msg
		moveq	#3,d6
		bra	exit_program
*****************************************************************
* strip - X形式の実行可能ファイルのシンボル情報を削除する
*
* CALL
*      A0     ファイル名
*
* RETURN
*      D1-D4/A1-A2   破壊
*****************************************************************
strip:
		moveq	#2,d0				*  読み書きモードで
		bsr	tfopen				*  ファイルをオープンする
		move.l	d0,d1				*  D1.L : ファイル・ハンドル
		bmi	strip_perror

		bsr	is_chrdev			*  キャラクタ・デバイスでないかどうか調べる
		bne	strip_chrdev

		clr.l	-(a7)
		move.w	d1,-(a7)
		DOS	_FILEDATE
		addq.l	#6,a7
		move.l	d0,d2				*  D2.L : ファイルのタイム・スタンプ
		cmp.l	#$ffff0000,d0
		bhs	strip_perror

		lea	buffer(pc),a1
		moveq	#64,d3				*  ヘッダ64バイトを読んでみる
		move.l	d3,-(a7)
		move.l	a1,-(a7)
		move.w	d1,-(a7)
		DOS	_READ
		lea	10(a7),a7
		tst.l	d0
		bmi	strip_perror

		cmp.l	d3,d0				*  64バイト読めなかったなら
		bne	strip_not_x			*  X形式ではない

		cmpi.b	#'H',0(a1)
		bne	strip_not_x			*  X形式でない

		cmpi.b	#'U',1(a1)
		bne	strip_not_x			*  X形式でない

		move.l	$001c(a1),d4			*  D4.L : シンボルのバイト数
		beq	strip_return			*  シンボルは無い

		*  シンボル無しのヘッダを書き込む
		clr.l	$001c(a1)
		clr.w	-(a7)
		clr.l	-(a7)
		move.w	d1,-(a7)
		DOS	_SEEK
		addq.l	#8,a7
		tst.l	d0
		bmi	strip_perror

		move.l	d3,-(a7)
		move.l	a1,-(a7)
		move.w	d1,-(a7)
		DOS	_WRITE
		lea	10(a7),a7
		tst.l	d0
		bmi	strip_perror

		*  シンボルを削除する
		neg.l	d4
		move.w	#2,-(a7)
		move.l	d4,-(a7)
		move.w	d1,-(a7)
		DOS	_SEEK
		addq.l	#8,a7
		tst.l	d0
		bmi	strip_perror

		clr.l	-(a7)
		move.l	a1,-(a7)
		move.w	d1,-(a7)
		DOS	_WRITE
		lea	10(a7),a7
		tst.l	d0
		bmi	strip_perror

		btst	#0,d5
		beq	strip_return

		move.l	d2,-(a7)
		move.w	d1,-(a7)
		DOS	_FILEDATE
		addq.l	#6,a7
		cmp.l	#$ffff0000,d0
		bhs	strip_perror
strip_return:
		move.l	d1,d0
		bpl	fclose				*  return
		rts

strip_chrdev:
		lea	msg_is_device(pc),a2
		bsr	werror_myname_word_colon_msg
		bra	strip_return

strip_not_x:
		lea	msg_not_x(pc),a2
		bsr	werror_myname_word_colon_msg
		bra	strip_return

strip_perror:
		bsr	perror
		bra	strip_return
*****************************************************************
malloc:
		move.l	d0,-(a7)
		DOS	_MALLOC
		addq.l	#4,a7
		tst.l	d0
		rts
*****************************************************************
is_chrdev:
		movem.l	d0,-(a7)
		move.w	d0,-(a7)
		clr.w	-(a7)
		DOS	_IOCTRL
		addq.l	#4,a7
		tst.l	d0
		bpl	is_chrdev_1

		moveq	#0,d0
is_chrdev_1:
		btst	#7,d0
		movem.l	(a7)+,d0
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
werror_myname_word_colon_msg:
		bsr	werror_myname_and_msg
		move.l	a0,-(a7)
		lea	msg_colon(pc),a0
werror_word_msg_and_set_error:
		bsr	werror
		movea.l	a2,a0
		bsr	werror
		lea	msg_newline(pc),a0
		bsr	werror
		movea.l	(a7)+,a0
		moveq	#2,d6
		rts
*****************************************************************
perror:
		movem.l	d0/a2,-(a7)
		not.l	d0		* -1 -> 0, -2 -> 1, ...
		cmp.l	#25,d0
		bls	perror_2

		cmp.l	#256,d0
		blo	perror_1

		sub.l	#256,d0
		cmp.l	#4,d0
		bhi	perror_1

		lea	perror_table_2(pc),a2
		bra	perror_3

perror_1:
		moveq	#25,d0
perror_2:
		lea	perror_table(pc),a2
perror_3:
		lsl.l	#1,d0
		move.w	(a2,d0.l),d0
		lea	sys_errmsgs(pc),a2
		lea	(a2,d0.w),a2
		bsr	werror_myname_word_colon_msg
		movem.l	(a7)+,d0/a2
		tst.l	d0
		rts
*****************************************************************
.data

	dc.b	0
	dc.b	'## strip 1.0 ##  Copyright(C)1992 by Itagaki Fumihiko',0

.even
perror_table:
	dc.w	msg_error-sys_errmsgs			*   0 ( -1)
	dc.w	msg_nofile-sys_errmsgs			*   1 ( -2)
	dc.w	msg_nodir-sys_errmsgs			*   2 ( -3)
	dc.w	msg_too_many_openfiles-sys_errmsgs	*   3 ( -4)
	dc.w	msg_dir_vol-sys_errmsgs			*   4 ( -5)
	dc.w	msg_error-sys_errmsgs			*   5 ( -6)
	dc.w	msg_error-sys_errmsgs			*   6 ( -7)
	dc.w	msg_error-sys_errmsgs			*   7 ( -8)
	dc.w	msg_error-sys_errmsgs			*   8 ( -9)
	dc.w	msg_error-sys_errmsgs			*   9 (-10)
	dc.w	msg_error-sys_errmsgs			*  10 (-11)
	dc.w	msg_error-sys_errmsgs			*  11 (-12)
	dc.w	msg_bad_name-sys_errmsgs		*  12 (-13)
	dc.w	msg_error-sys_errmsgs			*  13 (-14)
	dc.w	msg_bad_drive-sys_errmsgs		*  14 (-15)
	dc.w	msg_error-sys_errmsgs			*  15 (-16)
	dc.w	msg_error-sys_errmsgs			*  16 (-17)
	dc.w	msg_error-sys_errmsgs			*  17 (-18)
	dc.w	msg_write_disabled-sys_errmsgs		*  18 (-19)
	dc.w	msg_error-sys_errmsgs			*  19 (-20)
	dc.w	msg_error-sys_errmsgs			*  20 (-21)
	dc.w	msg_error-sys_errmsgs			*  21 (-22)
	dc.w	msg_disk_full-sys_errmsgs		*  22 (-23)
	dc.w	msg_directory_full-sys_errmsgs		*  23 (-24)
	dc.w	msg_cannot_seek-sys_errmsgs		*  24 (-25)
	dc.w	msg_error-sys_errmsgs			*  25 (-26)

.even
perror_table_2:
	dc.w	msg_bad_drivename-sys_errmsgs		* 256 (-257)
	dc.w	msg_no_drive-sys_errmsgs		* 257 (-258)
	dc.w	msg_no_media_in_drive-sys_errmsgs	* 258 (-259)
	dc.w	msg_media_set_miss-sys_errmsgs		* 259 (-260)
	dc.w	msg_drive_not_ready-sys_errmsgs		* 260 (-261)

sys_errmsgs:
msg_error:		dc.b	'エラー',0
msg_nofile:		dc.b	'このようなファイルはありません',0
msg_nodir:		dc.b	'このようなディレクトリはありません',0
msg_too_many_openfiles:	dc.b	'オープンしているファイルが多すぎます',0
msg_dir_vol:		dc.b	'ディレクトリかボリュームラベルです',0
msg_bad_name:		dc.b	'名前が無効です',0
msg_bad_drive:		dc.b	'ドライブの指定が無効です',0
msg_write_disabled:	dc.b	'書き込みが許可されていません',0
msg_disk_full:		dc.b	'ディスクが満杯です',0
msg_directory_full:	dc.b	'ディレクトリが満杯です',0
msg_cannot_seek:	dc.b	'シークできません',0
msg_bad_drivename:	dc.b	'ドライブ名が無効です',0
msg_no_drive:		dc.b	'ドライブがありません',0
msg_no_media_in_drive:	dc.b	'ドライブにメディアがセットされていません',0
msg_media_set_miss:	dc.b	'ドライブにメディアが正しくセットされていません',0
msg_drive_not_ready:	dc.b	'ドライブの準備ができていません',0

msg_myname:			dc.b	'strip'
msg_colon:			dc.b	': ',0
msg_no_memory:			dc.b	'メモリが足りません',CR,LF,0
msg_illegal_option:		dc.b	'不正なオプション -- ',0
msg_too_few_args:		dc.b	'引数が足りません',0
msg_is_device:			dc.b	'キャラクタ・デバイスです',0
msg_not_x:			dc.b	'.Xタイプ実行可能形式ファイルではありません',0
msg_usage:			dc.b	CR,LF,'使用法:  strip [-p] [-] <ファイル> ...'
msg_newline:			dc.b	CR,LF,0
*****************************************************************
.bss

buffer:			ds.b	64

.even
			ds.b	STACKSIZE
.even
stack_bottom:
*****************************************************************

.end start
