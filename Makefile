# Makefile for ITA TOOLBOX #? strip

AS	= \usr\pds\HAS.X -l -i $(INCLUDE) -d
LK	= \usr\pds\hlk.x #-x
CV      = -\bin\CV.X -r
INSTALL = cp -up
BACKUP  = cp -au
CP      = cp
RM      = -rm -f

INCLUDE = $(HOME)/fish/include

DESTDIR   = A:/usr/ita
BACKUPDIR = B:/strip/1.0

EXTLIB = ../lib/getlnenv.o $(HOME)/fish/lib/ita.l

###

PROGRAM = strip.x

###

.PHONY: all clean clobber install backup

.TERMINAL: *.h *.s

%.r : %.x	; $(CV) $<
%.x : %.o	; $(LK) $< $(EXTLIB)
%.o : %.s	; $(AS) $<

###

all:: $(PROGRAM)

clean::

clobber:: clean
	$(RM) *.bak *.$$* *.o *.x

###

$(PROGRAM) : $(INCLUDE)/doscall.h $(INCLUDE)/chrcode.h $(EXTLIB)

install::
	$(INSTALL) $(PROGRAM) $(DESTDIR)

backup::
	fish -fc '$(BACKUP) * $(BACKUPDIR)'

clean::
	$(RM) $(PROGRAM)

###
