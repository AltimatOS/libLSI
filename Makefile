PREFIX  = /System

BINDIR  = /bin
CFGDIR  = /cfg
LIBDIR  = /lib

MKDIR   = /bin/mkdir
CP      = /bin/cp
CHMOD   = /bin/chmod
CHOWN   = /bin/chown
CHGRP   = /bin/chgrp
LN      = /bin/ln
INSTALL = /usr/bin/install

.PHONY: install
install:
	$(MKDIR) -pv $(DESTDIR)$(PREFIX)
	$(MKDIR) -pv $(DESTDIR)$(PREFIX)$(CFGDIR)
	$(MKDIR) -pv $(DESTDIR)$(PREFIX)$(CFGDIR)/lpkg
	$(MKDIR) -pv $(DESTDIR)$(PREFIX)$(LIBDIR)
	$(MKDIR) -pv $(DESTDIR)$(PREFIX)$(LIBDIR)/lpkg
	$(CHMOD) -v 0755 $(DESTDIR)$(PREFIX)
	$(CHMOD) -v 0755 $(DESTDIR)$(PREFIX)$(CFGDIR)
	$(CHMOD) -v 0755 $(DESTDIR)$(PREFIX)$(CFGDIR)/lpkg
	$(CHMOD) -v 0755 $(DESTDIR)$(PREFIX)$(LIBDIR)
	$(CHMOD) -v 0755 $(DESTDIR)$(PREFIX)$(LIBDIR)/lpkg
	$(CHOWN) -Rv 0:0 $(DESTDIR)$(PREFIX)
	$(INSTALL) -o 0 -g 0 -m 0644 configuration.json \
		$(DESTDIR)$(PREFIX)$(CFGDIR)/lpkg/configuration.json
#	$(INSTALL) -o 0 -g 0 -m 0755 

test:
	PERL_DL_NONLAZY=1 DEBUG=0 "/usr/bin/env" "perl" "-MExtUtils::Command::MM" "-MTest::Harness" "-e" "undef *Test::Harness::Switches; test_harness(0, 'lib')" t/*.t
